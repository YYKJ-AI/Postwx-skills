import SwiftUI
import UniformTypeIdentifiers

// MARK: - Design Tokens

private enum Design {
    // 主色调 — 仅 Apple 系统蓝，极度克制
    static let accent = Color.accentColor
    // 兼容旧代码的渐变引用 → 统一为纯色
    static let accentGradient = LinearGradient(colors: [accent], startPoint: .leading, endPoint: .trailing)
    static let successGradient = LinearGradient(colors: [Color.green], startPoint: .leading, endPoint: .trailing)
    static let warningGradient = LinearGradient(colors: [Color.orange], startPoint: .leading, endPoint: .trailing)

    static let panelBg = Color(nsColor: .controlBackgroundColor)
    static let cardBg = Color(nsColor: .windowBackgroundColor)
    static let subtleBorder = Color.primary.opacity(0.06)
    static let separator = Color(nsColor: .separatorColor)
    static let radius: CGFloat = 8
    static let smallRadius: CGFloat = 6
}

struct ContentView: View {
    @State private var state = AppState()
    @State private var droppedFileURL: URL?
    @State private var showSettings = false
    @State private var publishError: String?
    @State private var showOriginalContent = false
    @AppStorage("username") private var storedUsername = ""
    @AppStorage("defaultAuthor") private var storedDefaultAuthor = ""

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider().opacity(0.5)

            HSplitView {
                editorPanel
                    .frame(minWidth: 300)

                workflowPanel
                    .frame(width: 280)
            }
        }
        .background(Design.panelBg.opacity(0.5))
        .onAppear {
            loadCredentials()
            if state.author.isEmpty {
                let fallback = storedDefaultAuthor.isEmpty ? storedUsername : storedDefaultAuthor
                if !fallback.isEmpty { state.author = fallback }
            }
        }
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
        HStack(spacing: 12) {
            // Logo / App name
            HStack(spacing: 6) {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Design.accentGradient)
                Text("Postwx")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.8))
            }

            // 工作流状态标签
            if state.isReviewing {
                StatusPill(label: "审核中", icon: "eye.fill", color: .orange)
                    .transition(.scale.combined(with: .opacity))
            } else if state.isProcessing {
                StatusPill(label: "处理中", icon: "sparkles", color: .blue)
                    .transition(.scale.combined(with: .opacity))
            }

            Spacer()

            if state.isReviewing {
                Button {
                    showOriginalContent.toggle()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: showOriginalContent ? "doc.on.doc.fill" : "doc.on.doc")
                            .font(.caption)
                        Text(showOriginalContent ? "隐藏原文" : "对比原文")
                    }
                    .font(.system(size: 11, weight: .medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.ultraThinMaterial, in: Capsule())
                }
                .buttonStyle(.plain)
            }

            ToolbarButton(icon: "doc.badge.plus", label: "打开") {
                openFile()
            }
            .disabled(state.isBusy)

            ToolbarButton(icon: "gearshape", label: "设置") {
                showSettings = true
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .animation(.snappy(duration: 0.3), value: state.isReviewing)
        .animation(.snappy(duration: 0.3), value: state.isProcessing)
    }

    // MARK: - Editor Panel

    private var editorPanel: some View {
        ZStack {
            if state.isReviewing && showOriginalContent {
                originalContentView
            } else if state.content.isEmpty {
                emptyState
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    if state.isReviewing {
                        reviewHeader
                    }
                    TextEditor(text: $state.content)
                        .font(.system(.body, design: .monospaced))
                        .scrollContentBackground(.hidden)
                        .padding(14)
                }
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
    }

    private var originalContentView: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Label("原文内容", systemImage: "doc.text")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    showOriginalContent = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 20, height: 20)
                        .background(.quaternary.opacity(0.5), in: Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 6)

            ScrollView {
                Text(state.originalContent)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
            }
            .background(Color.orange.opacity(0.03))
        }
    }

    private var reviewHeader: some View {
        HStack(spacing: 8) {
            Image(systemName: "pencil.and.outline")
                .font(.caption)
                .foregroundStyle(.blue)
            Text("AI 处理后（可编辑）")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            Spacer()
            if let score = state.deAIScore {
                ScoreBadge(score: score)
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 4)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Design.accentGradient.opacity(0.08))
                    .frame(width: 80, height: 80)
                Circle()
                    .fill(Design.accentGradient.opacity(0.05))
                    .frame(width: 60, height: 60)
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(Design.accentGradient)
            }

            VStack(spacing: 6) {
                Text("拖拽文件到此处")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary.opacity(0.7))
                Text("支持 Markdown、HTML、纯文本")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
            }

            Button {
                openFile()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "folder")
                        .font(.system(size: 11))
                    Text("选择文件")
                        .font(.system(size: 12, weight: .medium))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 7)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().stroke(Design.subtleBorder, lineWidth: 1))
            }
            .buttonStyle(.plain)
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
                VStack(alignment: .leading, spacing: 16) {
                    if !state.isProcessing {
                        metadataFields
                    }

                    // 工作流步骤
                    workflowSteps

                    // AI 实时输出
                    if state.isProcessing && !state.aiStreamingText.isEmpty {
                        aiStreamingOutput
                    }

                    // AI 状态
                    if state.workflowState == .idle {
                        aiStatusIndicator
                    }

                    // 完成状态
                    if case .done(let mediaId) = state.workflowState {
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
        .background(Design.panelBg.opacity(0.3))
    }

    // MARK: - Metadata Fields

    private var metadataFields: some View {
        VStack(spacing: 10) {
            StyledField(label: "标题", icon: "textformat", text: $state.title, prompt: "自动提取")
                .disabled(state.isBusy)
            StyledField(label: "作者", icon: "person", text: $state.author, prompt: {
                if !storedDefaultAuthor.isEmpty { return storedDefaultAuthor }
                if !storedUsername.isEmpty { return storedUsername }
                return "可选"
            }())
                .disabled(state.isBusy)
            StyledField(label: "摘要", icon: "text.alignleft", text: $state.summary, prompt: "自动生成", axis: .vertical)
                .disabled(state.isBusy)
        }
    }

    // MARK: - Workflow Steps

    private var workflowSteps: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 标题行
            HStack(spacing: 6) {
                Text("工作流")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                // 完成计数
                let completed = WorkflowStep.allCases.filter { state.stepStatus($0).isTerminal }.count
                let total = WorkflowStep.allCases.count
                if completed > 0 {
                    Text("\(completed)/\(total)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.bottom, 8)

            // 步骤列表 — GitHub Actions 手风琴风格
            VStack(spacing: 0) {
                ForEach(Array(WorkflowStep.allCases.enumerated()), id: \.element.id) { index, step in
                    WorkflowStepRow(
                        step: step,
                        status: state.stepStatus(step),
                        duration: state.stepDurations[step],
                        streamingText: state.aiCurrentStep == step.label ? state.aiStreamingText : nil,
                        isLast: index == WorkflowStep.allCases.count - 1
                    )
                }
            }
            .background(
                RoundedRectangle(cornerRadius: Design.radius)
                    .fill(Design.cardBg)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Design.radius)
                    .stroke(Design.separator.opacity(0.5), lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: Design.radius))
        }
    }

    // MARK: - AI Streaming Output

    private var aiStreamingOutput: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "sparkle")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Design.accentGradient)
                    .symbolEffect(.pulse, options: .repeating)
                Text(state.aiCurrentStep.isEmpty ? "AI 输出" : state.aiCurrentStep)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                ProgressView()
                    .controlSize(.mini)
            }

            ScrollViewReader { proxy in
                ScrollView {
                    Text(state.aiStreamingText.suffix(1500))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary.opacity(0.85))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .id("bottom")
                }
                .frame(maxHeight: 150)
                .background(
                    RoundedRectangle(cornerRadius: Design.smallRadius)
                        .fill(Color(nsColor: .textBackgroundColor).opacity(0.6))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Design.smallRadius)
                        .stroke(Color.blue.opacity(0.12), lineWidth: 1)
                )
                .onChange(of: state.aiStreamingText) {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: Design.radius)
                .fill(Design.cardBg)
                .shadow(color: .black.opacity(0.03), radius: 3, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Design.radius)
                .stroke(Design.subtleBorder, lineWidth: 1)
        )
    }

    // MARK: - AI Status

    private var aiStatusIndicator: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(AIService.isAvailable() ? .green : .orange)
                .frame(width: 6, height: 6)
                .shadow(color: AIService.isAvailable() ? .green.opacity(0.4) : .orange.opacity(0.4), radius: 3)
            Text(AIService.isAvailable() ? "Claude AI 已就绪" : "Claude CLI 未安装")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: Capsule())
    }

    // MARK: - Done Section

    private func doneSection(mediaId: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 28))
                .foregroundStyle(.green)

            Text("发布成功！")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.primary.opacity(0.8))

            if !mediaId.isEmpty {
                Text("media_id: \(mediaId)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .textSelection(.enabled)
                    .lineLimit(2)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 5))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: Design.radius)
                .fill(Design.cardBg)
                .shadow(color: .black.opacity(0.03), radius: 3, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Design.radius)
                .stroke(Color.green.opacity(0.15), lineWidth: 1)
        )
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 8) {
            if state.isReviewing {
                GradientButton(
                    label: "确认发布",
                    icon: "paperplane.fill",
                    gradient: Design.accentGradient
                ) {
                    confirmPublish()
                }

                Button("返回编辑") {
                    cancelReview()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .frame(maxWidth: .infinity)
            } else if state.isPublishing {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("正在发布到草稿箱...")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            } else if case .done = state.workflowState {
                Button {
                    resetAll()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "plus.circle")
                        Text("新建文章")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            } else if case .failed = state.workflowState {
                VStack(spacing: 6) {
                    GradientButton(
                        label: "重试",
                        icon: "arrow.clockwise",
                        gradient: Design.warningGradient
                    ) {
                        startWorkflow()
                    }

                    Button("重置") {
                        state.resetWorkflow()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .frame(maxWidth: .infinity)
                }
            } else {
                GradientButton(
                    label: state.isProcessing ? "处理中..." : "开始处理",
                    icon: state.isProcessing ? nil : "wand.and.stars",
                    gradient: Design.accentGradient,
                    isLoading: state.isProcessing
                ) {
                    startWorkflow()
                }
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
        state.content = state.originalContent
        state.resetWorkflow()
    }

    private func resetAll() {
        state.content = ""
        state.title = ""
        state.summary = ""
        let fallback = state.defaultAuthor.isEmpty ? state.username : state.defaultAuthor
        state.author = fallback
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

        if state.author.isEmpty {
            let fallbackAuthor = state.defaultAuthor.isEmpty ? state.username : state.defaultAuthor
            if !fallbackAuthor.isEmpty {
                state.author = fallbackAuthor
            }
        }

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

// MARK: - Workflow Step Row (GitHub Actions / Vercel 手风琴风格)

struct WorkflowStepRow: View {
    let step: WorkflowStep
    let status: StepStatus
    var duration: TimeInterval?
    var streamingText: String?
    var isLast: Bool = false

    @State private var isExpanded = false
    @State private var checkmarkTrimEnd: CGFloat = 0
    @State private var spinAngle: Double = 0

    private var hasExpandableContent: Bool {
        if case .running = status { return true }
        if case .failed = status { return true }
        if case .completed(let d) = status, !d.isEmpty { return true }
        return false
    }

    var body: some View {
        VStack(spacing: 0) {
            // 步骤行（始终可见）— 36pt 行高
            HStack(spacing: 10) {
                // 状态图标
                statusIcon
                    .frame(width: 18, height: 18)

                // 步骤图标 + 名称
                Image(systemName: step.icon)
                    .font(.system(size: 11))
                    .foregroundStyle(iconTint)

                Text(step.label)
                    .font(.system(size: 13, weight: status == .running ? .medium : .regular))
                    .foregroundStyle(textColor)

                Spacer()

                // 右侧：耗时 / 状态标签
                rightContent

                // 展开箭头（仅有可展开内容时显示）
                if hasExpandableContent {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.quaternary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
            }
            .frame(height: 36)
            .padding(.horizontal, 12)
            .contentShape(Rectangle())
            .onTapGesture {
                guard hasExpandableContent else { return }
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            }
            .background(
                status == .running
                    ? Color.accentColor.opacity(0.04)
                    : Color.clear
            )

            // 展开的详情区域
            if isExpanded {
                expandedContent
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // 分隔线
            if !isLast {
                Divider()
                    .padding(.leading, 40)
            }
        }
        .onChange(of: status) { _, newValue in
            if case .completed = newValue {
                withAnimation(.spring(duration: 0.35)) {
                    checkmarkTrimEnd = 1
                }
                // 完成时自动折叠
                withAnimation(.easeInOut(duration: 0.2).delay(0.3)) {
                    isExpanded = false
                }
            }
            if case .running = newValue {
                // 运行时自动展开
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded = true
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: status)
    }

    // MARK: - Status Icon

    @ViewBuilder
    private var statusIcon: some View {
        switch status {
        case .pending:
            Circle()
                .stroke(Color.secondary.opacity(0.25), lineWidth: 1.5)

        case .running:
            // 简洁旋转圆环（GitHub Actions 风格）
            Circle()
                .trim(from: 0, to: 0.7)
                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .rotationEffect(.degrees(spinAngle))
                .onAppear {
                    withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                        spinAngle = 360
                    }
                }

        case .completed:
            ZStack {
                Circle()
                    .fill(Color.green)

                CheckmarkShape()
                    .trim(from: 0, to: checkmarkTrimEnd)
                    .stroke(Color.white, style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
                    .frame(width: 8, height: 8)
            }
            .onAppear {
                if checkmarkTrimEnd == 0 {
                    withAnimation(.spring(duration: 0.35).delay(0.05)) {
                        checkmarkTrimEnd = 1
                    }
                }
            }

        case .skipped:
            ZStack {
                Circle()
                    .fill(Color.secondary.opacity(0.12))
                Image(systemName: "minus")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.secondary)
            }

        case .failed:
            ZStack {
                Circle()
                    .fill(Color.red)
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
    }

    // MARK: - Right Content

    @ViewBuilder
    private var rightContent: some View {
        switch status {
        case .running:
            Text("运行中")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color.accentColor)

        case .completed(let detail):
            HStack(spacing: 6) {
                if !detail.isEmpty {
                    Text(detail)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                if let duration {
                    Text(formatDuration(duration))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }
            }

        case .failed:
            Text("失败")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.red)

        case .skipped(let reason):
            Text(reason)
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .lineLimit(1)

        default:
            EmptyView()
        }
    }

    // MARK: - Expanded Content

    @ViewBuilder
    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            switch status {
            case .running:
                if let text = streamingText, !text.isEmpty {
                    // AI 实时日志输出 — 等宽字体，深色背景
                    ScrollView {
                        Text(text.suffix(1200))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                    }
                    .frame(maxHeight: 120)
                    .background(Color(nsColor: .textBackgroundColor).opacity(0.5))
                } else {
                    HStack(spacing: 6) {
                        ProgressView()
                            .controlSize(.mini)
                        Text("AI 正在处理...")
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }

            case .failed(let msg):
                Text(msg)
                    .font(.system(size: 11))
                    .foregroundStyle(.red.opacity(0.8))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)

            case .completed(let detail):
                if !detail.isEmpty {
                    Text(detail)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                }

            default:
                EmptyView()
            }
        }
        .padding(.leading, 28) // 对齐到步骤名
    }

    // MARK: - Helpers

    private func formatDuration(_ t: TimeInterval) -> String {
        if t < 1 { return String(format: "%.0fms", t * 1000) }
        if t < 60 { return String(format: "%.1fs", t) }
        return String(format: "%.0fm%.0fs", t / 60, t.truncatingRemainder(dividingBy: 60))
    }

    private var iconTint: Color {
        switch status {
        case .running: .accentColor
        case .completed: .green
        case .failed: .red
        case .skipped: .secondary
        default: Color.secondary.opacity(0.5)
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
}

// MARK: - Checkmark Shape

struct CheckmarkShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.width * 0.35, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        return path
    }
}

// MARK: - Reusable Components

struct StatusPill: View {
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .bold))
            Text(label)
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(color.opacity(0.1), in: Capsule())
    }
}

struct ToolbarButton: View {
    let icon: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                Text(label)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }
}

struct StyledField: View {
    let label: String
    let icon: String
    @Binding var text: String
    var prompt: String = ""
    var axis: Axis = .horizontal

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            TextField(prompt, text: $text, axis: axis)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: Design.smallRadius)
                        .fill(Color(nsColor: .textBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Design.smallRadius)
                        .stroke(Design.subtleBorder, lineWidth: 1)
                )
        }
    }
}

struct ScoreBadge: View {
    let score: Int

    private var color: Color {
        score >= 45 ? .green : score >= 35 ? .orange : .red
    }

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "shield.checkered")
                .font(.system(size: 9))
            Text("\(score)/50")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(color.opacity(0.1), in: Capsule())
    }
}

struct GradientButton: View {
    let label: String
    var icon: String?
    let gradient: LinearGradient
    var isLoading: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.white)
                } else if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .semibold))
                }
                Text(label)
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(gradient, in: RoundedRectangle(cornerRadius: 8))
            .shadow(color: .black.opacity(0.1), radius: 3, y: 2)
        }
        .buttonStyle(.plain)
    }
}
