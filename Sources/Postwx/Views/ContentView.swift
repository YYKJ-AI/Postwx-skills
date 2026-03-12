import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var state = AppState()
    @State private var droppedFileURL: URL?
    @State private var showSettings = false
    @State private var publishError: String?
    @State private var showOriginalContent = false

    var body: some View {
        VStack(spacing: 0) {
            toolbar
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

            Divider()

            HSplitView {
                // 左侧：编辑区
                editorPanel
                    .frame(minWidth: 300)

                // 右侧：工作流面板
                workflowPanel
                    .frame(width: 260)
            }
        }
        .onAppear { loadCredentials() }
        .sheet(isPresented: $showSettings) {
            SettingsView(state: state)
                .interactiveDismissDisabled(false)
        }
        .alert("发布失败", isPresented: Binding(
            get: { publishError != nil },
            set: { if !$0 { publishError = nil } }
        )) {
            Button("好的") { publishError = nil }
        } message: {
            Text(publishError ?? "")
        }
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            handleDrop(providers)
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack {
            Text("Postwx")
                .font(.headline)
                .foregroundStyle(.secondary)

            // 工作流状态标签
            if state.isReviewing {
                Label("审核中", systemImage: "eye")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(.orange.opacity(0.1), in: Capsule())
            } else if state.isProcessing {
                Label("处理中", systemImage: "gearshape.2")
                    .font(.caption)
                    .foregroundStyle(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(.blue.opacity(0.1), in: Capsule())
            }

            Spacer()

            if state.isReviewing {
                Button("查看原文") {
                    showOriginalContent.toggle()
                }
                .buttonStyle(.borderless)
                .font(.caption)
            }

            Button {
                openFile()
            } label: {
                Label("打开文件", systemImage: "doc")
            }
            .buttonStyle(.borderless)
            .disabled(state.isBusy)

            Button {
                showSettings = true
            } label: {
                Label("设置", systemImage: "gearshape")
            }
            .buttonStyle(.borderless)
        }
    }

    // MARK: - Editor Panel

    private var editorPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            if state.isReviewing && showOriginalContent {
                // 审核模式：显示原文对比
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("原文内容（只读）")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("关闭原文") { showOriginalContent = false }
                            .buttonStyle(.borderless)
                            .font(.caption)
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 8)

                    ScrollView {
                        Text(state.originalContent)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                    }
                    .background(Color.yellow.opacity(0.05))
                }
            } else if state.content.isEmpty {
                emptyState
            } else {
                // 审核模式下编辑器标题
                if state.isReviewing {
                    HStack {
                        Text("AI 处理后内容（可编辑）")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        if let score = state.deAIScore {
                            Text("去AI味评分: \(score)/50")
                                .font(.caption)
                                .foregroundStyle(score >= 45 ? .green : score >= 35 ? .orange : .red)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                }

                TextEditor(text: $state.content)
                    .font(.system(.body, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .padding(12)
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text")
                .font(.system(size: 36))
                .foregroundStyle(.quaternary)
            Text("拖拽 Markdown 文件到此处")
                .foregroundStyle(.secondary)
            Text("或粘贴文本内容")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            state.content = " "
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                state.content = ""
            }
        }
    }

    // MARK: - Workflow Panel

    private var workflowPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    // 元数据字段
                    if !state.isProcessing {
                        metadataFields
                        Divider()
                    }

                    // 工作流步骤指示器
                    workflowSteps
                        .padding(.vertical, 4)

                    // AI 实时输出
                    if state.isProcessing && !state.aiStreamingText.isEmpty {
                        aiStreamingOutput
                    }

                    // 主题配色（仅在审核模式可编辑）
                    if state.isReviewing || state.workflowState == .idle {
                        Divider()
                        themeSection
                    }

                    // AI 状态
                    if state.workflowState == .idle {
                        Divider()
                        aiStatusIndicator
                    }

                    // 完成状态
                    if case .done(let mediaId) = state.workflowState {
                        Divider()
                        doneSection(mediaId: mediaId)
                    }
                }
                .padding(16)
            }

            Spacer(minLength: 0)

            // 底部操作按钮
            actionButtons
                .padding(16)
        }
    }

    // MARK: - Metadata Fields

    private var metadataFields: some View {
        Group {
            LabeledField("标题", text: $state.title, prompt: "自动提取")
                .disabled(state.isBusy)
            LabeledField("作者", text: $state.author, prompt: state.defaultAuthor.isEmpty ? "可选" : state.defaultAuthor)
                .disabled(state.isBusy)
            LabeledField("摘要", text: $state.summary, prompt: "自动生成", axis: .vertical)
                .disabled(state.isBusy)
        }
    }

    // MARK: - Workflow Steps

    private var workflowSteps: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("工作流")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.bottom, 6)

            ForEach(WorkflowStep.allCases) { step in
                WorkflowStepRow(step: step, status: state.stepStatus(step))
            }
        }
    }

    // MARK: - Theme Section

    private var themeSection: some View {
        Group {
            Text("主题配色")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            Picker("主题", selection: $state.selectedTheme) {
                ForEach(Theme.allCases) { t in
                    Text(t.displayName).tag(t)
                }
            }
            .pickerStyle(.menu)
            .controlSize(.regular)

            Picker("配色", selection: $state.selectedColor) {
                ForEach(ThemeColor.allCases) { c in
                    Text(c.rawValue).tag(c)
                }
            }
            .pickerStyle(.menu)
            .controlSize(.regular)
        }
    }

    // MARK: - AI Streaming Output

    private var aiStreamingOutput: some View {
        VStack(alignment: .leading, spacing: 6) {
            Divider()

            HStack(spacing: 6) {
                Image(systemName: "sparkle")
                    .font(.caption)
                    .foregroundStyle(.blue)
                Text(state.aiCurrentStep.isEmpty ? "AI 输出" : state.aiCurrentStep)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
                ProgressView()
                    .controlSize(.mini)
            }

            ScrollViewReader { proxy in
                ScrollView {
                    Text(state.aiStreamingText.suffix(1500))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .id("bottom")
                }
                .frame(maxHeight: 160)
                .background(Color(nsColor: .textBackgroundColor).opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.blue.opacity(0.15), lineWidth: 1)
                )
                .onChange(of: state.aiStreamingText) {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
        }
    }

    // MARK: - AI Status

    private var aiStatusIndicator: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(AIService.isAvailable() ? .green : .orange)
                .frame(width: 7, height: 7)
            Text(AIService.isAvailable() ? "Claude AI 已就绪" : "Claude CLI 未安装")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Done Section

    private func doneSection(mediaId: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("发布成功", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.subheadline.weight(.medium))
            Text("media_id: \(mediaId)")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .textSelection(.enabled)
                .lineLimit(2)
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 8) {
            if state.isReviewing {
                // 审核模式：确认发布 + 返回编辑
                Button {
                    confirmPublish()
                } label: {
                    HStack {
                        Image(systemName: "paperplane.fill")
                        Text("确认发布")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button("返回编辑") {
                    cancelReview()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .frame(maxWidth: .infinity)
            } else if state.isPublishing {
                // 发布中
                HStack {
                    ProgressView()
                        .controlSize(.small)
                    Text("正在发布到草稿箱...")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
            } else if case .done = state.workflowState {
                // 完成
                Button("新建文章") {
                    resetAll()
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
            } else if case .failed = state.workflowState {
                // 失败
                VStack(spacing: 6) {
                    Button {
                        startWorkflow()
                    } label: {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("重试")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    Button("重置") {
                        state.resetWorkflow()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .frame(maxWidth: .infinity)
                }
            } else {
                // 默认：开始处理
                Button {
                    startWorkflow()
                } label: {
                    HStack {
                        if state.isProcessing {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "wand.and.stars")
                        }
                        Text(state.isProcessing ? "处理中..." : "开始处理")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(state.content.isEmpty || state.isBusy || !state.hasCredentials)
                .help(state.hasCredentials ? "" : "请先在设置中配置微信凭证")
            }
        }
    }

    // MARK: - File Actions

    private func openFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [
            UTType(filenameExtension: "md")!,
            UTType(filenameExtension: "html")!,
            .plainText,
        ]
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let url = panel.url else { return }
        loadFile(url)
    }

    private func loadFile(_ url: URL) {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return }
        state.content = content
        droppedFileURL = url

        if state.title.isEmpty {
            let filename = url.deletingPathExtension().lastPathComponent
            if filename != "index" && filename != "README" {
                state.title = filename
            }
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { data, _ in
            guard let data = data as? Data,
                  let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
            DispatchQueue.main.async { loadFile(url) }
        }
        return true
    }

    // MARK: - Workflow Execution

    private func startWorkflow() {
        guard !state.content.isEmpty else { return }

        state.workflowState = .processing
        state.stepStatuses = [:]
        state.publishLog = []
        state.originalContent = state.content
        showOriginalContent = false

        Task {
            do {
                var content = state.content
                var title = state.title
                var summary = state.summary

                // ── Step 1: 输入检测 ──
                state.updateStep(.inputDetection, status: .running)
                let format = PublishService.detectInputFormat(
                    content: content,
                    fileURL: droppedFileURL
                )
                state.inputFormat = format
                state.updateStep(.inputDetection, status: .completed(format.rawValue))

                // HTML 直接跳到审核
                if format == .html {
                    state.updateStep(.roleAdaptation, status: .skipped("HTML 直接发布"))
                    state.updateStep(.deAI, status: .skipped("HTML 直接发布"))
                    state.updateStep(.themeSelection, status: .skipped("HTML 直接发布"))
                    state.updateStep(.imageGeneration, status: .skipped("HTML 直接发布"))
                    state.processedContent = content
                    state.workflowState = .reviewing
                    return
                }

                // AI 处理（需要 Claude CLI）
                if AIService.isAvailable() {
                    // ── Step 2: 角色适配 ──
                    state.updateStep(.roleAdaptation, status: .running)
                    state.aiCurrentStep = "角色适配"
                    state.aiStreamingText = ""
                    do {
                        content = try await AIService.adaptRole(
                            content: content,
                            role: state.creatorRole,
                            style: state.writingStyle,
                            audience: state.targetAudience,
                            onStream: { [state] chunk in
                                Task { @MainActor in state.aiStreamingText += chunk }
                            }
                        )
                        state.content = content
                        state.updateStep(.roleAdaptation, status: .completed(
                            "\(state.creatorRole.displayName) · \(state.writingStyle.displayName)"
                        ))
                    } catch {
                        state.updateStep(.roleAdaptation, status: .failed(error.localizedDescription))
                        // 角色适配失败不阻断流程
                    }

                    // ── Step 3: 去 AI 味 ──
                    state.updateStep(.deAI, status: .running)
                    state.aiCurrentStep = "去 AI 味"
                    state.aiStreamingText = ""
                    do {
                        let deAIResult = try await AIService.deAI(
                            content: content,
                            writingStyle: state.writingStyle,
                            onStream: { [state] chunk in
                                Task { @MainActor in state.aiStreamingText += chunk }
                            }
                        )
                        content = deAIResult.content
                        state.content = content
                        state.deAIScore = deAIResult.score
                        state.deAIRating = deAIResult.rating

                        let scoreText = deAIResult.score.map { "\($0)/50" } ?? ""
                        let ratingText = deAIResult.rating ?? ""
                        state.updateStep(.deAI, status: .completed(
                            [scoreText, ratingText].filter { !$0.isEmpty }.joined(separator: " ")
                        ))
                    } catch {
                        state.updateStep(.deAI, status: .failed(error.localizedDescription))
                    }

                    // 自动提取标题
                    if title.isEmpty {
                        title = try await AIService.generateTitle(content: content)
                        state.title = title
                    }

                    // 自动生成摘要
                    if summary.isEmpty {
                        summary = try await AIService.generateSummary(content: content, title: title)
                        state.summary = summary
                    }

                    // ── Step 4: 主题配色 ──
                    state.updateStep(.themeSelection, status: .running)
                    do {
                        let themeResult = try await AIService.selectTheme(
                            content: content,
                            role: state.creatorRole
                        )
                        state.selectedTheme = themeResult.theme
                        state.selectedColor = themeResult.color
                        state.updateStep(.themeSelection, status: .completed(
                            "\(themeResult.theme.displayName) · \(themeResult.color.rawValue)"
                        ))
                    } catch {
                        state.updateStep(.themeSelection, status: .failed(error.localizedDescription))
                    }

                    // ── Step 5: AI 配图 ──
                    if !state.imageApiKey.isEmpty {
                        state.updateStep(.imageGeneration, status: .running)
                        do {
                            let images = try await AIService.analyzeImages(
                                content: content,
                                title: title
                            )
                            if images.isEmpty {
                                state.updateStep(.imageGeneration, status: .completed("无需插图"))
                            } else {
                                content = PublishService.insertImagePlaceholders(
                                    content: content,
                                    images: images
                                )
                                state.content = content
                                state.updateStep(.imageGeneration, status: .completed(
                                    "已插入 \(images.count) 张配图提示"
                                ))
                            }
                        } catch {
                            state.updateStep(.imageGeneration, status: .failed(error.localizedDescription))
                        }
                    } else {
                        state.updateStep(.imageGeneration, status: .skipped("未配置 IMAGE_API_KEY"))
                    }
                } else {
                    // Claude CLI 不可用，跳过 AI 步骤
                    state.updateStep(.roleAdaptation, status: .skipped("Claude CLI 未安装"))
                    state.updateStep(.deAI, status: .skipped("Claude CLI 未安装"))
                    state.updateStep(.themeSelection, status: .skipped("Claude CLI 未安装"))
                    state.updateStep(.imageGeneration, status: .skipped("Claude CLI 未安装"))
                }

                // 进入审核模式
                state.aiStreamingText = ""
                state.aiCurrentStep = ""
                state.processedContent = content
                state.updateStep(.publishing, status: .pending)
                state.workflowState = .reviewing

            } catch {
                state.workflowState = .failed(error.localizedDescription)
                publishError = error.localizedDescription
            }
        }
    }

    private func confirmPublish() {
        state.workflowState = .publishing
        state.updateStep(.publishing, status: .running)

        Task {
            do {
                let content = state.content
                let title = state.title
                let summary = state.summary
                let format = state.inputFormat

                // 保存临时文件（HTML 格式直接使用）
                let filePath: String
                if format == .html {
                    let dir = "/tmp/postwx/\(formattedDate())"
                    try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
                    filePath = "\(dir)/\(PublishService.generateSlug(from: title)).html"
                    try? content.write(toFile: filePath, atomically: true, encoding: .utf8)
                } else {
                    filePath = PublishService.saveTempMarkdown(
                        content: content,
                        title: title
                    )
                }

                let credentials = PublishService.Credentials(
                    wechatAppId: state.wechatAppId,
                    wechatAppSecret: state.wechatAppSecret,
                    imageApiBase: state.imageApiBase,
                    imageApiKey: state.imageApiKey,
                    imageModel: state.imageModel
                )

                let result = try await PublishService.publish(
                    filePath: filePath,
                    theme: state.selectedTheme,
                    color: state.selectedColor,
                    title: title.isEmpty ? nil : title,
                    summary: summary.isEmpty ? nil : summary,
                    author: state.author.isEmpty ? nil : state.author,
                    credentials: credentials,
                    onLog: { log in
                        Task { @MainActor in
                            state.publishLog.append(log)
                        }
                    }
                )

                // 提取 media_id
                var mediaId = ""
                if let data = result.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let mid = json["media_id"] as? String {
                    mediaId = mid
                }

                state.updateStep(.publishing, status: .completed("已发布"))
                state.workflowState = .done(mediaId)

            } catch {
                state.updateStep(.publishing, status: .failed(error.localizedDescription))
                state.workflowState = .failed(error.localizedDescription)
                publishError = error.localizedDescription
            }
        }
    }

    private func cancelReview() {
        // 恢复原始内容
        state.content = state.originalContent
        state.resetWorkflow()
    }

    private func resetAll() {
        state.content = ""
        state.title = ""
        state.summary = ""
        state.author = ""
        droppedFileURL = nil
        showOriginalContent = false
        state.resetWorkflow()
    }

    private func formattedDate() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    // MARK: - Load Credentials

    private func loadCredentials() {
        let defaults = UserDefaults.standard
        state.username = defaults.string(forKey: "username") ?? ""
        state.wechatAppId = defaults.string(forKey: "wechatAppId") ?? ""
        state.wechatAppSecret = defaults.string(forKey: "wechatAppSecret") ?? ""
        state.imageApiBase = defaults.string(forKey: "imageApiBase") ?? ""
        state.imageApiKey = defaults.string(forKey: "imageApiKey") ?? ""
        state.imageModel = defaults.string(forKey: "imageModel") ?? ""
        state.defaultAuthor = defaults.string(forKey: "defaultAuthor") ?? ""

        if let role = defaults.string(forKey: "creatorRole"),
           let r = CreatorRole(rawValue: role) {
            state.creatorRole = r
        }
        if let style = defaults.string(forKey: "writingStyle"),
           let s = WritingStyle(rawValue: style) {
            state.writingStyle = s
        }
        if let audience = defaults.string(forKey: "targetAudience"),
           let a = TargetAudience(rawValue: audience) {
            state.targetAudience = a
        }
    }
}

// MARK: - Workflow Step Row

struct WorkflowStepRow: View {
    let step: WorkflowStep
    let status: StepStatus

    var body: some View {
        HStack(spacing: 10) {
            // 步骤序号 / 状态图标
            statusIcon
                .frame(width: 22, height: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(step.label)
                    .font(.subheadline.weight(status == .running ? .semibold : .regular))
                    .foregroundStyle(textColor)

                // 状态详情
                switch status {
                case .completed(let detail):
                    if !detail.isEmpty {
                        Text(detail)
                            .font(.caption)
                            .foregroundStyle(.green.opacity(0.8))
                            .lineLimit(1)
                    }
                case .failed(let msg):
                    Text(msg)
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .lineLimit(2)
                case .skipped(let reason):
                    Text(reason)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                case .running:
                    Text("处理中...")
                        .font(.caption)
                        .foregroundStyle(.blue.opacity(0.7))
                default:
                    EmptyView()
                }
            }

            Spacer()
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(backgroundColor, in: RoundedRectangle(cornerRadius: 6))
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch status {
        case .pending:
            Image(systemName: "circle")
                .font(.subheadline)
                .foregroundStyle(.quaternary)
        case .running:
            ProgressView()
                .controlSize(.small)
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .font(.subheadline)
                .foregroundStyle(.green)
        case .skipped:
            Image(systemName: "minus.circle")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        case .failed:
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.subheadline)
                .foregroundStyle(.orange)
        }
    }

    private var textColor: Color {
        switch status {
        case .pending: .secondary
        case .running: .primary
        case .completed: .primary
        case .skipped: .secondary
        case .failed: .primary
        }
    }

    private var backgroundColor: Color {
        switch status {
        case .running: .blue.opacity(0.06)
        case .failed: .orange.opacity(0.06)
        default: .clear
        }
    }
}

// MARK: - Components

struct LabeledField: View {
    let label: String
    @Binding var text: String
    var prompt: String = ""
    var axis: Axis = .horizontal

    init(_ label: String, text: Binding<String>, prompt: String = "", axis: Axis = .horizontal) {
        self.label = label
        self._text = text
        self.prompt = prompt
        self.axis = axis
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            TextField(prompt, text: $text, axis: axis)
                .textFieldStyle(.roundedBorder)
                .controlSize(.regular)
        }
    }
}
