import Foundation

struct PublishService {
    /// scripts 目录路径
    private static var scriptsDir: String {
        let executableURL = Bundle.main.executableURL ?? URL(fileURLWithPath: ProcessInfo.processInfo.arguments[0])
        let projectDir = findProjectDir(from: executableURL)
        return projectDir + "/scripts"
    }

    /// 向上查找项目根目录（包含 scripts/ 的目录）
    private static func findProjectDir(from url: URL) -> String {
        var dir = url.deletingLastPathComponent()
        for _ in 0..<10 {
            let candidate = dir.appendingPathComponent("scripts/wechat-api.ts")
            if FileManager.default.fileExists(atPath: candidate.path) {
                return dir.path
            }
            dir = dir.deletingLastPathComponent()
        }
        return "/Users/ziheng/Projects/Postwx"
    }

    // MARK: - 输入格式检测

    static func detectInputFormat(content: String, fileURL: URL?) -> InputFormat {
        // 优先根据文件扩展名判断
        if let url = fileURL {
            let ext = url.pathExtension.lowercased()
            switch ext {
            case "md", "markdown": return .markdown
            case "html", "htm": return .html
            case "txt": return .plainText
            default: break
            }
        }

        // 根据内容特征判断
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)

        // HTML 检测：包含常见 HTML 标签
        if trimmed.hasPrefix("<!DOCTYPE") || trimmed.hasPrefix("<html") ||
           trimmed.contains("<body") || trimmed.contains("<div") {
            return .html
        }

        // Markdown 检测：包含 Markdown 特征
        let mdPatterns = [
            "^#{1,6}\\s",     // 标题
            "^\\*\\*",        // 粗体
            "^-\\s",          // 列表
            "^\\d+\\.\\s",    // 有序列表
            "```",            // 代码块
            "\\[.+\\]\\(.+\\)", // 链接
            "!\\[",           // 图片
            "^>\\s",          // 引用
            "^---$",          // 分隔线/frontmatter
        ]

        for pattern in mdPatterns {
            if trimmed.range(of: pattern, options: .regularExpression, range: trimmed.startIndex..<trimmed.endIndex) != nil {
                return .markdown
            }
        }

        return .plainText
    }

    // MARK: - 保存内容到临时 Markdown 文件

    static func saveTempMarkdown(content: String, title: String) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateStr = dateFormatter.string(from: Date())

        let slug = generateSlug(from: title.isEmpty ? String(content.prefix(50)) : title)
        let dir = "/tmp/postwx/\(dateStr)"

        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)

        let filePath = "\(dir)/\(slug).md"

        var md = ""
        if !title.isEmpty {
            md += "# \(title)\n\n"
        }
        md += content

        try? md.write(toFile: filePath, atomically: true, encoding: .utf8)
        return filePath
    }

    // MARK: - 插入 AI 配图占位符到 Markdown

    static func insertImagePlaceholders(content: String, images: [ImageSuggestion]) -> String {
        guard !images.isEmpty else { return content }

        let paragraphs = content.components(separatedBy: "\n\n")
        var result: [String] = []

        for (index, paragraph) in paragraphs.enumerated() {
            result.append(paragraph)

            // 检查是否有图片需要插入在当前段落之后
            let paragraphNumber = index + 1
            for img in images {
                if img.position == "after_paragraph_\(paragraphNumber)" {
                    result.append("")
                    result.append("![\(img.alt)](__generate:\(img.prompt)__)")
                    result.append("")
                }
            }
        }

        return result.joined(separator: "\n\n")
    }

    // MARK: - 调用 TS 脚本发布

    struct Credentials {
        var wechatAppId: String
        var wechatAppSecret: String
        var imageApiBase: String
        var imageApiKey: String
        var imageModel: String
    }

    static func publish(
        filePath: String,
        theme: Theme,
        color: ThemeColor,
        title: String?,
        summary: String?,
        author: String?,
        credentials: Credentials,
        onLog: @escaping @Sendable (String) -> Void
    ) async throws -> String {
        var args = [
            "npx", "-y", "bun",
            "\(scriptsDir)/wechat-api.ts",
            filePath,
            "--theme", theme.rawValue,
            "--color", color.rawValue,
        ]

        if let title, !title.isEmpty { args += ["--title", title] }
        if let summary, !summary.isEmpty { args += ["--summary", summary] }
        if let author, !author.isEmpty { args += ["--author", author] }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = args
        process.currentDirectoryURL = URL(fileURLWithPath: scriptsDir)

        var env = ProcessInfo.processInfo.environment
        env["WECHAT_APP_ID"] = credentials.wechatAppId
        env["WECHAT_APP_SECRET"] = credentials.wechatAppSecret
        if !credentials.imageApiKey.isEmpty {
            env["IMAGE_API_KEY"] = credentials.imageApiKey
        }
        if !credentials.imageApiBase.isEmpty {
            env["IMAGE_API_BASE"] = normalizeApiBase(credentials.imageApiBase)
        }
        if !credentials.imageModel.isEmpty {
            env["IMAGE_MODEL"] = credentials.imageModel
        }
        process.environment = env

        let pipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = pipe
        process.standardError = errPipe

        try process.run()

        let outputData = pipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errPipe.fileHandleForReading.readDataToEndOfFile()

        process.waitUntilExit()

        let output = String(data: outputData, encoding: .utf8) ?? ""
        let errorOutput = String(data: errorData, encoding: .utf8) ?? ""

        if !output.isEmpty { onLog(output) }
        if !errorOutput.isEmpty { onLog(errorOutput) }

        if process.terminationStatus != 0 {
            throw PublishError.scriptFailed(errorOutput.isEmpty ? output : errorOutput)
        }

        return output
    }

    // MARK: - 测试微信凭证

    static func testWechatCredentials(appId: String, appSecret: String) async throws -> String {
        let urlStr = "https://api.weixin.qq.com/cgi-bin/token?grant_type=client_credential&appid=\(appId)&secret=\(appSecret)"
        guard let url = URL(string: urlStr) else {
            throw TestError.invalidConfig("无效的 App ID 格式")
        }

        let (data, _) = try await URLSession.shared.data(from: url)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw TestError.invalidResponse("无法解析响应")
        }

        if let errcode = json["errcode"] as? Int, errcode != 0 {
            throw TestError.apiFailed(friendlyWechatError(errcode))
        }

        if json["access_token"] is String {
            return "连接成功"
        }

        throw TestError.invalidResponse("响应中无 access_token")
    }

    // MARK: - 测试 AI 配图

    static func testImageGeneration(apiBase: String, apiKey: String, model: String) async throws -> String {
        let base = normalizeApiBase(apiBase.isEmpty ? "https://api.tu-zi.com" : apiBase)
        let urlStr = "\(base)/models"

        guard let url = URL(string: urlStr) else {
            throw TestError.invalidConfig("无效的 API Base URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TestError.invalidResponse("无效的 HTTP 响应")
        }

        if httpResponse.statusCode != 200 {
            throw TestError.apiFailed(friendlyImageError(httpResponse.statusCode))
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw TestError.invalidResponse("无法解析服务端响应")
        }

        if let error = json["error"] as? [String: Any], let message = error["message"] as? String {
            throw TestError.apiFailed(friendlyImageErrorMessage(message))
        }

        let modelName = model.isEmpty ? "gpt-image-1" : model
        if let models = json["data"] as? [[String: Any]] {
            let ids = models.compactMap { $0["id"] as? String }
            if ids.contains(modelName) {
                return "连接成功，模型 \(modelName) 可用"
            }
            if !ids.isEmpty {
                return "连接成功（未找到模型 \(modelName)，可用: \(ids.prefix(3).joined(separator: ", "))...）"
            }
        }

        return "连接成功"
    }

    // MARK: - 微信错误码映射

    private static func friendlyWechatError(_ code: Int) -> String {
        switch code {
        case -1: "微信系统繁忙，请稍后再试"
        case 40001: "App Secret 不正确，请检查后重新输入"
        case 40002: "请求的接口类型不正确"
        case 40013: "App ID 不正确，请检查后重新输入"
        case 40014: "Access Token 无效"
        case 40125: "App Secret 格式不正确，请检查是否有多余空格"
        case 41002: "缺少 App ID，请填写后重试"
        case 41004: "缺少 App Secret，请填写后重试"
        case 50001: "该公众号未开通接口权限，请在公众号后台开启"
        case 50002: "用户受限，请检查公众号状态是否正常"
        case 40164: "当前 IP 不在白名单，请在公众号后台添加"
        case 61024: "当前 IP 不在白名单，请在公众号后台添加"
        default: "微信错误 \(code)"
        }
    }

    private static func friendlyImageError(_ statusCode: Int) -> String {
        switch statusCode {
        case 401: "API Key 无效或已过期，请检查后重新输入"
        case 403: "API Key 权限不足，请确认是否有生图权限"
        case 404: "API 地址不正确，请检查 Base URL"
        case 429: "请求过于频繁，请稍后再试"
        case 500...599: "生图服务暂时不可用，请稍后再试"
        default: "生图服务异常（HTTP \(statusCode)），请检查配置"
        }
    }

    private static func friendlyImageErrorMessage(_ message: String) -> String {
        if message.lowercased().contains("invalid api key") || message.lowercased().contains("incorrect api key") {
            return "API Key 无效，请检查后重新输入"
        }
        if message.lowercased().contains("quota") || message.lowercased().contains("billing") {
            return "账户额度不足，请充值后重试"
        }
        if message.lowercased().contains("model") {
            return "模型不可用，请检查模型名称是否正确"
        }
        return message
    }

    // MARK: - Helpers

    private static func normalizeApiBase(_ base: String) -> String {
        var url = base.hasSuffix("/") ? String(base.dropLast()) : base
        if !url.hasSuffix("/v1") {
            url += "/v1"
        }
        return url
    }

    static func generateSlug(from text: String) -> String {
        let words = text
            .lowercased()
            .components(separatedBy: .alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .prefix(4)

        let slug = words.joined(separator: "-")
        return slug.isEmpty ? "untitled" : slug
    }
}

enum TestError: LocalizedError {
    case invalidConfig(String)
    case invalidResponse(String)
    case apiFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidConfig(let msg): msg
        case .invalidResponse(let msg): msg
        case .apiFailed(let msg): msg
        }
    }
}

enum PublishError: LocalizedError {
    case scriptFailed(String)
    case noContent

    var errorDescription: String? {
        switch self {
        case .scriptFailed(let msg): "脚本执行失败: \(msg)"
        case .noContent: "没有内容可发布"
        }
    }
}
