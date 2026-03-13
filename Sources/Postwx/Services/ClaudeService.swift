import Foundation

/// 线程安全的文本累积器
private final class StreamAccumulator: @unchecked Sendable {
    private let lock = NSLock()
    private var _text = ""

    func append(_ chunk: String) {
        lock.lock()
        _text += chunk
        lock.unlock()
    }

    func reset() {
        lock.lock()
        _text = ""
        lock.unlock()
    }

    var text: String {
        lock.lock()
        defer { lock.unlock() }
        return _text
    }
}

/// 通过本地 claude CLI 调用 AI，复用系统级 Claude Code 认证
struct AIService {

    /// claude CLI 的模型别名（sonnet 更快更便宜，适合这些轻量任务）
    private static let defaultModel = "sonnet"

    // MARK: - 查找 claude CLI

    private static func findCLI() -> String? {
        let candidates = [
            "/opt/homebrew/bin/claude",
            "/opt/homebrew/Caskroom/miniconda/base/bin/claude",
            "/usr/local/bin/claude",
            NSHomeDirectory() + "/.claude/local/claude",
        ]
        for path in candidates {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }
        // 尝试 which
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["which", "claude"]
        process.environment = ProcessInfo.processInfo.environment
        process.environment?["CLAUDECODE"] = nil
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        try? process.run()
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return path.isEmpty ? nil : path
    }

    /// 检查 claude CLI 是否可用
    static func isAvailable() -> Bool {
        findCLI() != nil
    }

    // MARK: - 调用 claude CLI

    /// 调用 claude CLI，支持可选的流式输出回调
    /// - Parameters:
    ///   - onStream: 当非 nil 时，使用 text 模式并实时回调每个文本片段
    private static func callClaude(
        system: String,
        userMessage: String,
        model: String? = nil,
        onStream: (@Sendable (String) -> Void)? = nil
    ) async throws -> String {
        guard let cliPath = findCLI() else {
            throw AIError.cliNotFound
        }

        let streaming = onStream != nil

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let process = Process()
                    process.executableURL = URL(fileURLWithPath: cliPath)

                    var args = ["-p", "--model", model ?? defaultModel,
                                "--system-prompt", system, "--no-session-persistence"]
                    if streaming {
                        // 真正的逐 token 流式：stream-json + partial messages
                        args += ["--output-format", "stream-json", "--verbose", "--include-partial-messages"]
                    } else {
                        args += ["--output-format", "json"]
                    }
                    args += ["--", userMessage]
                    process.arguments = args

                    var env = ProcessInfo.processInfo.environment
                    env["CLAUDECODE"] = nil
                    process.environment = env

                    let stdout = Pipe()
                    let stderr = Pipe()
                    process.standardOutput = stdout
                    process.standardError = stderr

                    if streaming {
                        // 流式模式：解析 JSONL，提取 content_block_delta 中的文本
                        let accumulator = StreamAccumulator()
                        let lineBuffer = StreamAccumulator() // 用于拼接不完整的行

                        stdout.fileHandleForReading.readabilityHandler = { handle in
                            let data = handle.availableData
                            guard !data.isEmpty,
                                  let raw = String(data: data, encoding: .utf8) else { return }

                            // 拼接到行缓冲区，按换行分割处理
                            lineBuffer.append(raw)
                            let buffered = lineBuffer.text
                            let lines = buffered.components(separatedBy: "\n")

                            // 最后一个元素可能是不完整的行，保留到下次
                            let complete = lines.dropLast()
                            let remainder = lines.last ?? ""
                            lineBuffer.reset()
                            if !remainder.isEmpty { lineBuffer.append(remainder) }

                            for line in complete {
                                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                                guard !trimmed.isEmpty,
                                      let jsonData = trimmed.data(using: .utf8),
                                      let obj = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
                                else { continue }

                                // 提取 content_block_delta 的文本增量
                                if let event = obj["event"] as? [String: Any],
                                   let eventType = event["type"] as? String,
                                   eventType == "content_block_delta",
                                   let delta = event["delta"] as? [String: Any],
                                   let text = delta["text"] as? String {
                                    accumulator.append(text)
                                    onStream?(text)
                                }

                                // 从 result 事件提取最终完整结果
                                if let type = obj["type"] as? String, type == "result",
                                   let result = obj["result"] as? String {
                                    accumulator.reset()
                                    accumulator.append(result)
                                }
                            }
                        }

                        try process.run()
                        process.waitUntilExit()

                        stdout.fileHandleForReading.readabilityHandler = nil

                        // 处理缓冲区剩余数据
                        let remaining = stdout.fileHandleForReading.readDataToEndOfFile()
                        if let text = String(data: remaining, encoding: .utf8), !text.isEmpty {
                            // 解析剩余行中的 result
                            for line in text.components(separatedBy: "\n") {
                                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                                guard !trimmed.isEmpty,
                                      let jsonData = trimmed.data(using: .utf8),
                                      let obj = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
                                else { continue }
                                if let type = obj["type"] as? String, type == "result",
                                   let result = obj["result"] as? String {
                                    accumulator.reset()
                                    accumulator.append(result)
                                }
                            }
                        }

                        if process.terminationStatus != 0 {
                            let errData = stderr.fileHandleForReading.readDataToEndOfFile()
                            let errText = String(data: errData, encoding: .utf8) ?? ""
                            continuation.resume(throwing: AIError.requestFailed(
                                errText.isEmpty ? accumulator.text.prefix(300).description : errText.prefix(300).description
                            ))
                            return
                        }

                        let result = accumulator.text.trimmingCharacters(in: .whitespacesAndNewlines)
                        if result.isEmpty {
                            continuation.resume(throwing: AIError.requestFailed("Claude CLI 返回空结果"))
                        } else {
                            continuation.resume(returning: result)
                        }
                    } else {
                        // 非流式模式：等待完成后解析 JSON
                        try process.run()
                        process.waitUntilExit()

                        let outData = stdout.fileHandleForReading.readDataToEndOfFile()

                        if process.terminationStatus != 0 {
                            let errText = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                            let outText = String(data: outData, encoding: .utf8) ?? ""
                            continuation.resume(throwing: AIError.requestFailed(
                                errText.isEmpty ? outText.prefix(300).description : errText.prefix(300).description
                            ))
                            return
                        }

                        // 解析 JSON 输出: { "result": "..." }
                        guard let json = try? JSONSerialization.jsonObject(with: outData) as? [String: Any],
                              let result = json["result"] as? String
                        else {
                            let text = String(data: outData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                            if text.isEmpty {
                                continuation.resume(throwing: AIError.requestFailed("Claude CLI 返回空结果"))
                            } else {
                                continuation.resume(returning: text)
                            }
                            return
                        }

                        continuation.resume(returning: result.trimmingCharacters(in: .whitespacesAndNewlines))
                    }
                } catch {
                    continuation.resume(throwing: AIError.requestFailed("启动 Claude CLI 失败：\(error.localizedDescription)"))
                }
            }
        }
    }

    // MARK: - 测试连接

    static func testConnection() async throws -> String {
        let result = try await callClaude(
            system: "回复[连接成功]四个字即可。",
            userMessage: "测试"
        )
        return "连接成功：\(result)"
    }

    // MARK: - Step 2: 角色适配

    static func adaptRole(
        content: String,
        persona: PersonaItem,
        onStream: (@Sendable (String) -> Void)? = nil
    ) async throws -> String {
        let system = """
        你是一位资深内容编辑，负责根据创作者人设对文章进行适配调整。

        ## 创作人设：\(persona.displayName)
        \(persona.prompt)

        ## 规则
        1. 保持原文核心信息和结构不变
        2. 根据人设调整专业深度、语气措辞和表达方式
        3. 保留所有 Markdown 格式标记（标题、列表、代码块、链接等）
        4. 保留所有图片标记（包括 __generate: 占位符）
        5. 去除 YAML frontmatter（即文章开头 --- ... --- 包裹的元数据块，如 tags、created、date 等），输出中不要包含 frontmatter
        6. 只输出适配后的全文，不要任何解释或前言
        """

        return try await callClaude(system: system, userMessage: content, onStream: onStream)
    }

    // MARK: - Step 3: 去 AI 味（增强版，24 种模式检测 + 五维评分）

    static func deAI(
        content: String,
        persona: PersonaItem,
        onStream: (@Sendable (String) -> Void)? = nil
    ) async throws -> DeAIResult {
        let system = """
        你是一位资深中文编辑。任务：将文章润色为自然、地道的人类写作风格，检测并修正 AI 写作痕迹。

        ## 24 种 AI 痕迹检测清单

        【内容模式 1-6】
        1. 过度强调意义/遗产 → 简化为客观陈述
        2. 过度强调知名度 → 去除不必要修饰
        3. 以-ing 肤浅分析（引领着、推动着）→ 用具体动词替代
        4. 宣传/广告式语言（革命性的、颠覆性的）→ 替换为中性描述
        5. 模糊归因（据专家表示、研究表明）→ 补充来源或删除
        6. 公式化总结（挑战与机遇并存）→ 用具体结论替代

        【语言模式 7-12】
        7. AI 高频词（至关重要、深入探讨、赋能、助力）→ 替换日常用语
        8. 系动词回避（作为…的存在）→ 恢复自然"是"字句
        9. 否定式排比（不仅…而且…更是…）→ 简化直接陈述
        10. 三段式过度使用 → 打破固定结构
        11. 刻意换词（同概念反复换词指代）→ 统一用词
        12. 虚假范围（从…到…，从…到…）→ 聚焦具体点

        【风格模式 13-16】
        13. 破折号过度 → 保留关键，简化其余
        14. 粗体过度 → 仅保留核心关键词
        15. 正文列表化 → 恢复段落叙述
        16. 表情符号装饰 → 去除

        【填充词 17-20】
        17. 填充短语（为了实现这一目标、在当今时代）→ 删除
        18. 过度限定（在某种程度上来说）→ 简化/删除
        19. 通用积极结论（总之，未来可期）→ 具体结论替代
        20. 绕圈回避 → 直接表述

        【交流痕迹 21-24】
        21. 协作痕迹（希望对您有帮助）→ 删除
        22. 截止免责（截至我所知…）→ 删除
        23. 谄媚语气（非常好的问题）→ 删除
        24. 交流特征（让我来为您解释）→ 删除

        ## 人设风格参考：\(persona.displayName)
        \(persona.prompt)

        ## 输出格式
        先输出润色后的全文，然后在最后一行输出评分，格式如下：
        <!--SCORE:直接性=X,节奏感=X,信任度=X,真实性=X,精炼度=X,总分=XX,评级=优秀/良好/需修订-->

        五维评分标准（每项满分 10 分）：
        - 直接性：10=直截了当，1=铺垫绕圈
        - 节奏感：10=长短交错，1=机械等长
        - 信任度：10=简洁尊重读者，1=过度解释
        - 真实性：10=像真人说话，1=机械生硬
        - 精炼度：10=无冗余，1=大量废话
        评级：45-50 优秀 | 35-44 良好 | <35 需修订

        ## 规则
        1. 保留所有 Markdown 格式标记
        2. 保留所有图片标记（包括 __generate: 占位符）
        3. 去除 YAML frontmatter（即文章开头 --- ... --- 包裹的元数据块），输出中不要包含 frontmatter
        4. 先输出完整润色后全文，最后一行输出 <!--SCORE:...--> 评分
        """

        let raw = try await callClaude(system: system, userMessage: content, onStream: onStream)

        // 解析评分
        var processedContent = raw
        var score: Int?
        var rating: String?

        if let scoreRange = raw.range(of: "<!--SCORE:", options: .backwards),
           let endRange = raw.range(of: "-->", range: scoreRange.upperBound..<raw.endIndex) {
            let scoreLine = String(raw[scoreRange.upperBound..<endRange.lowerBound])
            processedContent = String(raw[raw.startIndex..<scoreRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)

            // 提取总分
            if let totalMatch = scoreLine.range(of: "总分=") {
                let afterTotal = scoreLine[totalMatch.upperBound...]
                let digits = afterTotal.prefix(while: { $0.isNumber })
                score = Int(digits)
            }

            // 提取评级
            if let ratingMatch = scoreLine.range(of: "评级=") {
                let afterRating = scoreLine[ratingMatch.upperBound...]
                rating = String(afterRating.prefix(while: { $0 != "," && $0 != "-" }))
            }
        }

        return DeAIResult(
            content: processedContent,
            score: score,
            rating: rating
        )
    }

    // MARK: - Step 4: 智能选择主题配色

    static func selectTheme(content: String, persona: PersonaItem) async throws -> ThemeSelection {
        let system = """
        你是一位微信公众号排版专家。根据文章内容和创作者角色，选择最合适的主题和配色。

        ## 可选主题（4 种）
        - default: 通用默认，适合技术/编程/科普
        - grace: 优雅柔和，适合生活/情感/设计/创意
        - simple: 简洁清爽，适合教程/教育
        - modern: 现代商务，适合商业/分析

        ## 可选配色（13 种）
        blue, green, vermilion, yellow, purple, sky, rose, olive, black, gray, pink, red, orange

        ## 文章类型参考
        技术/编程 → default + blue
        生活/情感 → grace + purple 或 rose
        教程/教育 → simple + green
        商业/分析 → modern + orange 或 black
        设计/创意 → grace + vermilion 或 pink
        科普/知识 → default + sky 或 green

        ## 创作人设：\(persona.displayName)

        ## 输出格式（严格 JSON，不要其他内容）
        {"theme":"主题名","color":"配色名","reason":"一句话理由"}
        """

        let raw = try await callClaude(
            system: system,
            userMessage: "请分析以下文章并选择主题配色：\n\n\(String(content.prefix(2000)))"
        )

        // 提取 JSON
        guard let jsonData = extractJSON(from: raw),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: String],
              let theme = json["theme"],
              let color = json["color"]
        else {
            return ThemeSelection(theme: .default_, color: .blue, reason: "默认配色")
        }

        let selectedTheme = Theme.allCases.first { $0.rawValue == theme } ?? .default_
        let selectedColor = ThemeColor.allCases.first { $0.rawValue == color } ?? .blue

        return ThemeSelection(
            theme: selectedTheme,
            color: selectedColor,
            reason: json["reason"] ?? ""
        )
    }

    // MARK: - Step 5: AI 配图分析

    static func analyzeImages(content: String, title: String) async throws -> [ImageSuggestion] {
        let imageStyles = await PersonaLibrary.shared.data.imageStyles
        let styleList = imageStyles.enumerated().map { (i, s) in
            "\(i + 1). \(s.id): \(s.useCase) — \(s.colorPalette)"
        }.joined(separator: "\n")

        let system = """
        你是一位公众号配图专家。分析文章内容，决定是否需要插图，如果需要则生成图片提示词。

        ## \(imageStyles.count) 种图片风格
        \(styleList)

        ## 提示词模板
        [风格描述]. [主题内容]. [构图要求]. [色彩方案]. Clean composition with generous white space. Human figures: simplified stylized silhouettes, not photorealistic.

        ## 输出格式（严格 JSON 数组，不要其他内容）
        如果文章不需要插图，返回 []
        如果需要，返回：
        [{"position":"after_paragraph_N","alt":"图片描述","prompt":"英文提示词","style":"风格名"}]

        position 说明：after_paragraph_N 表示插入在第 N 段之后（从 1 开始计数）
        建议：短文（<800字）最多 1 张，中文（800-2000字）最多 2 张，长文可 3 张
        不要为每段都加图，只在关键转折或概念切换处加图。
        """

        let raw = try await callClaude(
            system: system,
            userMessage: "标题：\(title)\n\n文章内容：\n\(String(content.prefix(3000)))"
        )

        guard let jsonData = extractJSON(from: raw),
              let arr = try? JSONSerialization.jsonObject(with: jsonData) as? [[String: String]]
        else {
            return []
        }

        return arr.compactMap { dict in
            guard let position = dict["position"],
                  let alt = dict["alt"],
                  let prompt = dict["prompt"]
            else { return nil }
            return ImageSuggestion(
                position: position,
                alt: alt,
                prompt: prompt,
                style: dict["style"] ?? "vector"
            )
        }
    }

    // MARK: - 生成标题

    static func generateTitle(content: String) async throws -> String {
        let system = """
        你是一位公众号编辑。根据文章内容生成一个吸引人的标题。

        规则：
        1. 简洁有力，控制在 30 字以内
        2. 适合微信公众号的阅读场景
        3. 不要用标题党，但要有吸引力
        4. 只输出标题文本，不要引号或其他额外内容
        """

        let userMsg = "文章内容：\n\(String(content.prefix(3000)))"
        return try await callClaude(system: system, userMessage: userMsg)
    }

    // MARK: - 生成摘要

    static func generateSummary(content: String, title: String) async throws -> String {
        let system = """
        你是一位公众号编辑。根据文章内容生成一句简短的摘要，用于微信公众号文章的摘要字段。

        规则：
        1. 一句话概括文章核心内容，吸引读者点击
        2. 控制在 60 字以内
        3. 语言自然，不要用 AI 腔调
        4. 只输出摘要文本，不要任何额外内容
        """

        let userMsg = "标题：\(title)\n\n文章内容：\n\(String(content.prefix(3000)))"
        return try await callClaude(system: system, userMessage: userMsg)
    }

    // MARK: - Helpers

    private static func extractJSON(from text: String) -> Data? {
        // 尝试直接解析
        if let data = text.data(using: .utf8),
           (try? JSONSerialization.jsonObject(with: data)) != nil {
            return data
        }
        // 尝试提取 ```json ... ``` 代码块
        if let start = text.range(of: "```json"),
           let end = text.range(of: "```", range: start.upperBound..<text.endIndex) {
            let json = String(text[start.upperBound..<end.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            return json.data(using: .utf8)
        }
        // 尝试提取 { } 或 [ ]
        if let start = text.firstIndex(where: { $0 == "{" || $0 == "[" }) {
            let opener: Character = text[start]
            let closer: Character = opener == "{" ? "}" : "]"
            if let end = text.lastIndex(of: closer) {
                let json = String(text[start...end])
                if let data = json.data(using: .utf8),
                   (try? JSONSerialization.jsonObject(with: data)) != nil {
                    return data
                }
            }
        }
        return nil
    }
}

// MARK: - Result Types

struct DeAIResult {
    let content: String
    let score: Int?
    let rating: String?
}

struct ThemeSelection {
    let theme: Theme
    let color: ThemeColor
    let reason: String
}

struct ImageSuggestion {
    let position: String
    let alt: String
    let prompt: String
    let style: String
}

// MARK: - Errors

enum AIError: LocalizedError {
    case cliNotFound
    case requestFailed(String)

    var errorDescription: String? {
        switch self {
        case .cliNotFound: "未找到 Claude CLI"
        case .requestFailed(let msg): Self.friendlyMessage(msg)
        }
    }

    /// 将技术性错误信息转为用户友好的描述
    private static func friendlyMessage(_ raw: String) -> String {
        if raw.contains("unknown option") {
            return "CLI 参数不兼容，请更新 Claude Code"
        }
        if raw.contains("timeout") || raw.contains("timed out") {
            return "AI 响应超时，请稍后重试"
        }
        if raw.contains("rate limit") || raw.contains("429") {
            return "请求过于频繁，请稍后重试"
        }
        if raw.contains("auth") || raw.contains("401") || raw.contains("permission") {
            return "认证失败，请检查 Claude Code 登录状态"
        }
        if raw.contains("空结果") {
            return "AI 未返回内容，请重试"
        }
        // 截短过长的原始错误
        let trimmed = raw.prefix(80)
        return "AI 处理出错：\(trimmed)"
    }
}
