import SwiftUI
import UniformTypeIdentifiers

// MARK: - Design Tokens

private enum Design {
    static let accentGradient = LinearGradient(
        colors: [Color(hue: 0.72, saturation: 0.65, brightness: 0.95),
                 Color(hue: 0.58, saturation: 0.70, brightness: 0.90)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    static let successGradient = LinearGradient(
        colors: [Color(hue: 0.38, saturation: 0.55, brightness: 0.85),
                 Color(hue: 0.45, saturation: 0.60, brightness: 0.80)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    static let warningGradient = LinearGradient(
        colors: [Color.orange.opacity(0.85), Color(hue: 0.08, saturation: 0.70, brightness: 0.90)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    static let panelBg = Color(nsColor: .controlBackgroundColor)
    static let cardBg = Color(nsColor: .windowBackgroundColor)
    static let subtleBorder = Color.primary.opacity(0.06)
    static let radius: CGFloat = 10
    static let smallRadius: CGFloat = 7
}

struct ContentView: View {
    @State private var state = AppState()
    @State private var droppedFileURL: URL?
    @State private var showSettings = false
    @State private var showGlobalAISettings = false
    @State private var publishError: String?
    @State private var showOriginalContent = false
    private var profileManager = ProfileManager.shared

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
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(state: state)
                .interactiveDismissDisabled(false)
        }
        .sheet(isPresented: $showGlobalAISettings) {
            GlobalAISettingsView()
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

            ToolbarButton(icon: "photo.artframe", label: "AI 配图") {
                showGlobalAISettings = true
            }

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
                        // 目标账号选择
                        accountSelector

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

    // MARK: - Account Selector (Multi-Select)

    private var accountSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "person.crop.rectangle.stack.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(Design.accentGradient)
                Text("发布到")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                if !profileManager.profiles.isEmpty {
                    let allSelected = state.selectedProfileIds.count == profileManager.profiles.count
                    Button(allSelected ? "全不选" : "全选") {
                        if allSelected {
                            state.selectedProfileIds.removeAll()
                        } else {
                            state.selectedProfileIds = Set(profileManager.profiles.map(\.id))
                        }
                        applyPrimaryProfile()
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .buttonStyle(.plain)
                    .disabled(state.isBusy)
                }
            }

            if profileManager.profiles.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 11))
                        .foregroundStyle(.orange)
                    Text("暂无账号，请在设置中添加")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: Design.smallRadius)
                        .fill(Design.cardBg)
                )
            } else {
                VStack(spacing: 4) {
                    ForEach(profileManager.profiles) { profile in
                        let isSelected = state.selectedProfileIds.contains(profile.id)
                        let publishStatus = state.profilePublishStatuses[profile.id]
                        Button {
                            toggleProfile(profile)
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                                    .font(.system(size: 14))
                                    .foregroundStyle(isSelected ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.tertiary))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(profile.name)
                                        .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)
                                    HStack(spacing: 4) {
                                        if let role = CreatorRole(rawValue: profile.creatorRole) {
                                            Text(role.displayName)
                                                .font(.system(size: 10))
                                                .foregroundStyle(.tertiary)
                                        }
                                        if let style = WritingStyle(rawValue: profile.writingStyle) {
                                            Text("·")
                                                .font(.system(size: 10))
                                                .foregroundStyle(.quaternary)
                                            Text(style.displayName)
                                                .font(.system(size: 10))
                                                .foregroundStyle(.tertiary)
                                        }
                                    }
                                }

                                Spacer()

                                // 发布状态指示
                                if let status = publishStatus {
                                    publishStatusBadge(status)
                                } else if profile.wechatAppId.isEmpty {
                                    Text("未配置")
                                        .font(.system(size: 9, weight: .medium))
                                        .foregroundStyle(.orange)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(.orange.opacity(0.1), in: Capsule())
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(
                                RoundedRectangle(cornerRadius: Design.smallRadius)
                                    .fill(isSelected ? Color.accentColor.opacity(0.06) : Design.cardBg)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: Design.smallRadius)
                                    .stroke(isSelected ? Color.accentColor.opacity(0.25) : Design.subtleBorder, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(state.isBusy)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func publishStatusBadge(_ status: ProfilePublishStatus) -> some View {
        switch status {
        case .pending:
            Image(systemName: "clock")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        case .publishing:
            ProgressView()
                .controlSize(.mini)
        case .success:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 12))
                .foregroundStyle(.green)
        case .failed(let msg):
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 12))
                .foregroundStyle(.red)
                .help(msg)
        }
    }

    private func toggleProfile(_ profile: AccountProfile) {
        if state.selectedProfileIds.contains(profile.id) {
            state.selectedProfileIds.remove(profile.id)
        } else {
            state.selectedProfileIds.insert(profile.id)
        }
        applyPrimaryProfile()
    }

    private var anySelectedHasCredentials: Bool {
        state.selectedProfileIds.contains { id in
            guard let p = profileManager.profiles.first(where: { $0.id == id }) else { return false }
            return !p.wechatAppId.isEmpty && !p.wechatAppSecret.isEmpty
        }
    }

    private func applyPrimaryProfile() {
        if let primaryId = state.primaryProfileId {
            profileManager.switchProfile(id: primaryId)
            profileManager.applyToState(state)
        }
    }

    // MARK: - Metadata Fields

    private var metadataFields: some View {
        VStack(spacing: 10) {
            StyledField(label: "标题", icon: "textformat", text: $state.title, prompt: "自动提取")
                .disabled(state.isBusy)
            StyledField(label: "作者", icon: "person", text: $state.author, prompt: {
                if !state.defaultAuthor.isEmpty { return state.defaultAuthor }
                if !state.username.isEmpty { return state.username }
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
            HStack(spacing: 6) {
                Image(systemName: "list.bullet.circle.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(Design.accentGradient)
                Text("工作流")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 10)

            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(WorkflowStep.allCases.enumerated()), id: \.element.id) { index, step in
                    WorkflowStepRow(
                        step: step,
                        status: state.stepStatus(step),
                        isLast: index == WorkflowStep.allCases.count - 1
                    )
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: Design.radius)
                    .fill(Design.cardBg)
                    .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Design.radius)
                    .stroke(Design.subtleBorder, lineWidth: 1)
            )
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
            let successCount = state.profilePublishStatuses.values.filter {
                if case .success = $0 { return true }; return false
            }.count
            let failCount = state.profilePublishStatuses.values.filter {
                if case .failed = $0 { return true }; return false
            }.count
            let total = successCount + failCount

            ZStack {
                Circle()
                    .fill((failCount == 0 ? Design.successGradient : Design.warningGradient).opacity(0.12))
                    .frame(width: 48, height: 48)
                Image(systemName: failCount == 0 ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(failCount == 0 ? Design.successGradient : Design.warningGradient)
            }

            Text(failCount == 0 ? "全部发布成功！" : "发布完成 (\(successCount)/\(total) 成功)")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.primary.opacity(0.8))

            // 每个账号的结果
            VStack(spacing: 4) {
                ForEach(profileManager.profiles.filter({ state.profilePublishStatuses[$0.id] != nil })) { profile in
                    if let status = state.profilePublishStatuses[profile.id] {
                        HStack(spacing: 6) {
                            switch status {
                            case .success:
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.green)
                            case .failed:
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.red)
                            default:
                                EmptyView()
                            }
                            Text(profile.name)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                            Spacer()
                            if case .failed(let msg) = status {
                                Text(msg)
                                    .font(.system(size: 10))
                                    .foregroundStyle(.red.opacity(0.8))
                                    .lineLimit(1)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 8)
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
                    label: state.selectedProfileIds.count > 1
                        ? "发布到 \(state.selectedProfileIds.count) 个账号"
                        : "确认发布",
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
                    Text("正在发布到 \(state.selectedProfileIds.count) 个账号...")
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
                .disabled(state.content.isEmpty || state.isBusy || !state.hasSelectedProfiles || !anySelectedHasCredentials)
                .help(!state.hasSelectedProfiles ? "请选择至少一个目标账号" : !anySelectedHasCredentials ? "选中的账号未配置微信凭证" : "")
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

        // 初始化每个选中账号的发布状态
        for id in state.selectedProfileIds {
            state.profilePublishStatuses[id] = .pending
        }

        let content = state.content
        let title = state.title
        let summary = state.summary
        let format = state.inputFormat
        let d = UserDefaults.standard
        let globalImageApiBase = d.string(forKey: "imageApiBase") ?? ""
        let globalImageApiKey = d.string(forKey: "imageApiKey") ?? ""
        let globalImageModel = d.string(forKey: "imageModel") ?? ""

        Task {
            // 准备文件（所有账号共享同一份内容文件）
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

            // 逐账号发布
            var successCount = 0
            var failCount = 0
            var lastMediaId = ""

            for profileId in state.selectedProfileIds {
                guard let profile = profileManager.profiles.first(where: { $0.id == profileId }) else {
                    state.profilePublishStatuses[profileId] = .failed("账号不存在")
                    failCount += 1
                    continue
                }

                guard !profile.wechatAppId.isEmpty && !profile.wechatAppSecret.isEmpty else {
                    state.profilePublishStatuses[profileId] = .failed("未配置凭证")
                    failCount += 1
                    continue
                }

                state.profilePublishStatuses[profileId] = .publishing
                state.publishLog.append("[\(profile.name)] 开始发布...")

                do {
                    let credentials = PublishService.Credentials(
                        wechatAppId: profile.wechatAppId,
                        wechatAppSecret: profile.wechatAppSecret,
                        imageApiBase: globalImageApiBase,
                        imageApiKey: globalImageApiKey,
                        imageModel: globalImageModel
                    )

                    let author = profile.defaultAuthor.isEmpty ? profile.username : profile.defaultAuthor

                    let result = try await PublishService.publish(
                        filePath: filePath,
                        theme: state.selectedTheme,
                        color: state.selectedColor,
                        title: title.isEmpty ? nil : title,
                        summary: summary.isEmpty ? nil : summary,
                        author: author.isEmpty ? nil : author,
                        credentials: credentials,
                        onLog: { log in
                            Task { @MainActor in
                                state.publishLog.append("[\(profile.name)] \(log)")
                            }
                        }
                    )

                    var mediaId = ""
                    if let data = result.data(using: .utf8),
                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let mid = json["media_id"] as? String {
                        mediaId = mid
                    }

                    state.profilePublishStatuses[profileId] = .success(mediaId)
                    lastMediaId = mediaId
                    successCount += 1
                    state.publishLog.append("[\(profile.name)] 发布成功")
                } catch {
                    state.profilePublishStatuses[profileId] = .failed(error.localizedDescription)
                    failCount += 1
                    state.publishLog.append("[\(profile.name)] 发布失败: \(error.localizedDescription)")
                }
            }

            // 汇总结果
            let total = successCount + failCount
            if failCount == 0 {
                state.updateStep(.publishing, status: .completed("全部成功 (\(successCount)/\(total))"))
                state.workflowState = .done(lastMediaId)
            } else if successCount > 0 {
                state.updateStep(.publishing, status: .completed("部分成功 (\(successCount)/\(total))"))
                state.workflowState = .done(lastMediaId)
            } else {
                state.updateStep(.publishing, status: .failed("全部失败 (\(failCount)/\(total))"))
                state.workflowState = .failed("所有账号发布失败")
                publishError = "所有账号发布均失败，请检查凭证配置"
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
        if profileManager.profiles.isEmpty {
            profileManager.addProfile(AccountProfile())
        }
        // 默认选中所有账号
        state.selectedProfileIds = Set(profileManager.profiles.map(\.id))
        applyPrimaryProfile()
    }
}

// MARK: - Workflow Step Row

struct WorkflowStepRow: View {
    let step: WorkflowStep
    let status: StepStatus
    var isLast: Bool = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // 左侧：图标 + 连接线
            VStack(spacing: 0) {
                statusIcon
                    .frame(width: 24, height: 24)

                if !isLast {
                    Rectangle()
                        .fill(connectorColor)
                        .frame(width: 1.5, height: 20)
                }
            }

            // 右侧：内容
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Image(systemName: step.icon)
                        .font(.system(size: 10))
                        .foregroundStyle(iconTint)
                    Text(step.label)
                        .font(.system(size: 12, weight: status == .running ? .semibold : .regular))
                        .foregroundStyle(textColor)
                }

                switch status {
                case .completed(let detail):
                    if !detail.isEmpty {
                        Text(detail)
                            .font(.system(size: 10))
                            .foregroundStyle(.green.opacity(0.8))
                            .lineLimit(1)
                    }
                case .failed(let msg):
                    Text(msg)
                        .font(.system(size: 10))
                        .foregroundStyle(.orange)
                        .lineLimit(2)
                case .skipped(let reason):
                    Text(reason)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                case .running:
                    Text("处理中...")
                        .font(.system(size: 10))
                        .foregroundStyle(.blue.opacity(0.7))
                default:
                    EmptyView()
                }
            }
            .padding(.bottom, isLast ? 0 : 6)

            Spacer()
        }
        .animation(.snappy(duration: 0.3), value: status)
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch status {
        case .pending:
            Circle()
                .stroke(Color.secondary.opacity(0.3), lineWidth: 1.5)
                .frame(width: 18, height: 18)
        case .running:
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 20, height: 20)
                ProgressView()
                    .controlSize(.mini)
            }
        case .completed:
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.12))
                    .frame(width: 20, height: 20)
                Image(systemName: "checkmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.green)
            }
        case .skipped:
            ZStack {
                Circle()
                    .fill(Color.secondary.opacity(0.08))
                    .frame(width: 20, height: 20)
                Image(systemName: "minus")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.tertiary)
            }
        case .failed:
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.12))
                    .frame(width: 20, height: 20)
                Image(systemName: "exclamationmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.orange)
            }
        }
    }

    private var connectorColor: Color {
        switch status {
        case .completed: .green.opacity(0.25)
        case .running: .blue.opacity(0.2)
        case .failed: .orange.opacity(0.2)
        default: Color.secondary.opacity(0.15)
        }
    }

    private var iconTint: Color {
        switch status {
        case .running: .blue
        case .completed: .green
        case .failed: .orange
        case .skipped: .secondary
        default: Color.secondary.opacity(0.6)
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
