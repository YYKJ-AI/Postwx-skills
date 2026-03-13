import SwiftUI
import UniformTypeIdentifiers
import WebKit

// MARK: - Design System

private enum DS {
    // 微信品牌色
    static let wechatGreen = Color(hex: 0x07C160)
    static let brandGradient = LinearGradient(
        colors: [Color(hex: 0x07C160), Color(hex: 0x06AD56)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    static let brandGlow = Color(hex: 0x07C160)

    static let successGradient = LinearGradient(
        colors: [Color(hex: 0x10B981), Color(hex: 0x34D399)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    static let warningGradient = LinearGradient(
        colors: [Color(hex: 0xF59E0B), Color(hex: 0xFBBF24)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    static let dangerGradient = LinearGradient(
        colors: [Color(hex: 0xEF4444), Color(hex: 0xF87171)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    // 表面层级
    static let surfacePrimary = Color(nsColor: .windowBackgroundColor)
    static let surfaceElevated = Color(nsColor: .controlBackgroundColor)
    static let surfaceInput = Color(nsColor: .textBackgroundColor)

    // 边框
    static let borderDefault = Color.white.opacity(0.08)
    static let borderSubtle = Color.white.opacity(0.04)
    static let borderActive = Color(hex: 0x07C160).opacity(0.3)

    // 圆角
    static let r16: CGFloat = 16
    static let r12: CGFloat = 12
    static let r10: CGFloat = 10
    static let r8: CGFloat = 8
    static let r6: CGFloat = 6
}

// MARK: - Color Extension

extension Color {
    init(hex: UInt, opacity: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

// MARK: - Content View

struct ContentView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var state = AppState()
    @State private var droppedFileURL: URL?
    @State private var showSettings = false
    @State private var showGlobalAISettings = false
    @State private var showPersonaLibrary = false
    @State private var publishError: String?
    @State private var showOriginalContent = false
    @State private var isHoveringDrop = false
    @State private var showPreview = false
    private var profileManager = ProfileManager.shared

    var body: some View {
        HSplitView {
            editorPanel
                .frame(minWidth: 380)
            workflowPanel
                .frame(width: 320)
        }
        .background(DS.surfacePrimary)
        .navigationTitle("Postwx")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                if state.isReviewing {
                    LiveStatusBadge(label: "审核中", icon: "eye.fill", color: Color(hex: 0xF59E0B), isAnimated: false)
                } else if state.isProcessing {
                    LiveStatusBadge(label: "处理中", icon: "bolt.fill", color: DS.brandGlow, isAnimated: true)
                }
            }

            ToolbarItemGroup(placement: .automatic) {
                if !state.content.isEmpty {
                    Button {
                        showPreview.toggle()
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: showPreview ? "doc.plaintext" : "iphone")
                                .font(.system(size: 15))
                            Text(showPreview ? "编辑" : "预览")
                                .font(.system(size: 13, weight: .medium))
                        }
                    }
                    .controlSize(.large)
                }

                if state.isReviewing && !showPreview {
                    Button {
                        showOriginalContent.toggle()
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: showOriginalContent ? "doc.on.doc.fill" : "doc.on.doc")
                                .font(.system(size: 15))
                            Text(showOriginalContent ? "隐藏原文" : "对比原文")
                                .font(.system(size: 13, weight: .medium))
                        }
                    }
                    .controlSize(.large)
                }

                Button { openFile() } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "doc.badge.plus")
                            .font(.system(size: 15))
                        Text("打开")
                            .font(.system(size: 13, weight: .medium))
                    }
                }
                .controlSize(.large)
                .disabled(state.isBusy)

                Button { showPersonaLibrary = true } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "person.text.rectangle")
                            .font(.system(size: 15))
                        Text("人设")
                            .font(.system(size: 13, weight: .medium))
                    }
                }
                .controlSize(.large)

                Button { showSettings = true } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 15))
                        Text("设置")
                            .font(.system(size: 13, weight: .medium))
                    }
                }
                .controlSize(.large)
            }
        }
        .onAppear {
            loadCredentials()
        }
        .onChange(of: state.workflowState) { _, newValue in
            if newValue == .reviewing {
                showPreview = true
            }
        }
        .overlay {
            if showSettings {
                ZStack {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .onTapGesture { showSettings = false }

                    SettingsView(state: state, onDismiss: { showSettings = false })
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: .black.opacity(0.3), radius: 20, y: 8)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
                .animation(.easeOut(duration: 0.2), value: showSettings)
            }
        }
        .overlay {
            if showGlobalAISettings {
                ZStack {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .onTapGesture { showGlobalAISettings = false }

                    GlobalAISettingsView(onDismiss: { showGlobalAISettings = false })
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: .black.opacity(0.3), radius: 20, y: 8)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
                .animation(.easeOut(duration: 0.2), value: showGlobalAISettings)
            }
        }
        .overlay {
            if showPersonaLibrary {
                ZStack {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .onTapGesture { showPersonaLibrary = false }

                    PersonaLibraryEditorView(state: state, onDismiss: { showPersonaLibrary = false })
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: .black.opacity(0.3), radius: 20, y: 8)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
                .animation(.easeOut(duration: 0.2), value: showPersonaLibrary)
            }
        }
        .alert("发布失败", isPresented: Binding(
            get: { publishError != nil },
            set: { if !$0 { publishError = nil } }
        )) {
            Button("好的") { publishError = nil }
        } message: {
            Text(publishError ?? "")
        }
        .onDrop(of: [.fileURL], isTargeted: $isHoveringDrop) { providers in
            handleDrop(providers)
        }
    }

    // MARK: - Editor Panel

    private var editorPanel: some View {
        VStack(spacing: 0) {
            // 审核模式下多账号切换 Tab（始终显示在顶部）
            if state.isReviewing && state.profileContents.count > 1 {
                reviewProfileTabs
                Divider().opacity(0.3)
            }

            ZStack {
                if showPreview && !state.content.isEmpty {
                    // WeChat phone preview
                    WeChatPreviewView(
                        content: state.content,
                        title: state.title,
                        author: {
                            // 审核时优先显示当前账号的作者
                            if let activeId = state.activeReviewProfileId,
                               let profile = profileManager.profiles.first(where: { $0.id == activeId }) {
                                let a = profile.defaultAuthor.isEmpty ? profile.username : profile.defaultAuthor
                                if !a.isEmpty { return a }
                            }
                            if !state.author.isEmpty { return state.author }
                            if !state.defaultAuthor.isEmpty { return state.defaultAuthor }
                            if !state.username.isEmpty { return state.username }
                            return ""
                        }(),
                        theme: state.selectedTheme,
                        color: state.selectedColor,
                        inputFormat: state.inputFormat
                    )
                    .background(Color(nsColor: .windowBackgroundColor).opacity(0.3))
                } else if state.isReviewing && showOriginalContent {
                    originalContentView
                } else if state.content.isEmpty {
                    emptyState
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        if state.isReviewing {
                            reviewHeader
                        }
                        TextEditor(text: $state.content)
                            .font(.body.monospaced())
                            .scrollContentBackground(.hidden)
                            .padding(16)
                    }
                }

                if isHoveringDrop {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(DS.brandGlow.opacity(0.6), lineWidth: 2)
                        .background(DS.brandGlow.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
                        .padding(6)
                        .allowsHitTesting(false)
                }
            }
        }
        .background(showPreview && !state.content.isEmpty ? Color.clear : DS.surfaceInput)
        .animation(.easeOut(duration: 0.2), value: isHoveringDrop)
    }

    private var originalContentView: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "doc.text")
                        .font(.subheadline)
                    Text("原文内容")
                        .font(.headline)
                }
                .foregroundStyle(.secondary)
                Spacer()
                IconButton(icon: "xmark", size: .small) {
                    showOriginalContent = false
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

            ScrollView {
                Text(state.originalContent)
                    .font(.body.monospaced())
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
            }
            .background(Color.orange.opacity(0.02))
        }
    }

    private var reviewHeader: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Circle()
                    .fill(DS.brandGradient)
                    .frame(width: 7, height: 7)
                if let activeId = state.activeReviewProfileId,
                   let profile = profileManager.profiles.first(where: { $0.id == activeId }),
                   state.profileContents.count > 1 {
                    Text("\(profile.name) · AI 处理后（可编辑）")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                } else {
                    Text("AI 处理后（可编辑）")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if let score = state.deAIScore {
                ScoreBadge(score: score)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 6)
    }

    private var reviewProfileTabs: some View {
        let sortedIds = Array(state.profileContents.keys).sorted { $0.uuidString < $1.uuidString }
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(sortedIds, id: \.self) { profileId in
                    let isActive = profileId == state.activeReviewProfileId
                    if let profile = profileManager.profiles.first(where: { $0.id == profileId }) {
                        Button {
                            switchReviewProfile(to: profileId)
                        } label: {
                            HStack(spacing: 5) {
                                if let persona = PersonaLibrary.shared.persona(id: profile.personaId) {
                                    Text(persona.displayName)
                                        .font(.system(size: 10))
                                        .foregroundStyle(isActive ? .white.opacity(0.8) : .secondary)
                                }
                                Text(profile.name)
                                    .font(.system(size: 12, weight: isActive ? .semibold : .regular))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(isActive ? DS.wechatGreen : Color.clear)
                            .foregroundStyle(isActive ? .white : .primary)
                            .clipShape(RoundedRectangle(cornerRadius: DS.r6))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
        }
    }

    private func switchReviewProfile(to newId: UUID) {
        // 保存当前编辑内容到旧账号
        if let currentId = state.activeReviewProfileId {
            state.profileContents[currentId] = state.content
        }
        // 加载新账号的内容
        state.activeReviewProfileId = newId
        state.content = state.profileContents[newId] ?? state.originalContent
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 28) {
            ZStack {
                Circle()
                    .stroke(DS.brandGlow.opacity(0.08), lineWidth: 1)
                    .frame(width: 120, height: 120)

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [DS.brandGlow.opacity(0.10), DS.brandGlow.opacity(0.02)],
                            center: .center,
                            startRadius: 10,
                            endRadius: 55
                        )
                    )
                    .frame(width: 100, height: 100)

                Circle()
                    .fill(DS.brandGlow.opacity(0.08))
                    .frame(width: 64, height: 64)

                Image(systemName: "doc.text.fill")
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(DS.brandGradient)
            }

            VStack(spacing: 10) {
                Text("拖拽文件到此处")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary.opacity(0.8))

                HStack(spacing: 8) {
                    ForEach(["Markdown", "HTML", "纯文本"], id: \.self) { format in
                        Text(format)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.primary.opacity(0.04), in: Capsule())
                    }
                }
            }

            Button {
                openFile()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "folder.fill")
                        .font(.body)
                    Text("选择文件")
                        .font(.body.weight(.semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 9)
                .background(DS.brandGradient, in: Capsule())
                .shadow(color: DS.brandGlow.opacity(0.25), radius: 10, y: 4)
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
                VStack(alignment: .leading, spacing: 18) {
                    // 进度总览
                    if state.isProcessing || state.isReviewing || state.isPublishing {
                        progressOverview
                    }

                    if !state.isProcessing {
                        // 目标账号选择
                        accountSelector
                    }

                    workflowTimeline

                    if state.workflowState == .idle {
                        aiStatusCard
                    }

                    if case .done(let mediaId) = state.workflowState {
                        doneSection(mediaId: mediaId)
                    }
                }
                .padding(18)
            }

            Spacer(minLength: 0)

            // 底部操作
            VStack(spacing: 0) {
                Rectangle().fill(DS.borderDefault).frame(height: 0.5)
                actionButtons
                    .padding(18)
            }
        }
        .background(DS.surfaceElevated.opacity(0.5))
    }

    // MARK: - Progress Overview

    private var progressOverview: some View {
        let total = WorkflowStep.allCases.count
        let completed = WorkflowStep.allCases.filter {
            if case .completed = state.stepStatus($0) { return true }
            if case .skipped = state.stepStatus($0) { return true }
            return false
        }.count
        let progress = Double(completed) / Double(total)

        return HStack(spacing: 14) {
            ZStack {
                Circle()
                    .stroke(Color.primary.opacity(0.06), lineWidth: 4)
                    .frame(width: 48, height: 48)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(DS.brandGradient, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 48, height: 48)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(duration: 0.6), value: progress)

                Text("\(completed)/\(total)")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(state.isReviewing ? "等待审核" : state.isPublishing ? "发布中" : "处理中")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)

                Text("\(Int(progress * 100))% 完成")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: DS.r12)
                .fill(.ultraThinMaterial)
                .shadow(color: DS.brandGlow.opacity(0.06), radius: 12, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.r12)
                .stroke(DS.borderActive, lineWidth: 1)
        )
    }

    // MARK: - Account Selector (Multi-Select)

    private var accountSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "person.crop.rectangle.stack.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(DS.brandGradient)
                Text("发布到")
                    .font(.system(size: 14, weight: .semibold))
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
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .buttonStyle(.plain)
                    .disabled(state.isBusy)
                }
            }

            if profileManager.profiles.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 12))
                        .foregroundStyle(.orange)
                    Text("暂无账号，请在设置中添加")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: DS.r8)
                        .fill(DS.surfacePrimary)
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
                                    .font(.system(size: 15))
                                    .foregroundStyle(isSelected ? AnyShapeStyle(DS.wechatGreen) : AnyShapeStyle(.tertiary))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(profile.name)
                                        .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)
                                    if let persona = PersonaLibrary.shared.persona(id: profile.personaId) {
                                        Text(persona.displayName)
                                            .font(.system(size: 11))
                                            .foregroundStyle(.tertiary)
                                    }
                                }

                                Spacer()

                                if let status = publishStatus {
                                    publishStatusBadge(status)
                                } else if profile.wechatAppId.isEmpty {
                                    Text("未配置")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(.orange)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(.orange.opacity(0.1), in: Capsule())
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(
                                RoundedRectangle(cornerRadius: DS.r8)
                                    .fill(isSelected ? DS.wechatGreen.opacity(0.06) : DS.surfacePrimary)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: DS.r8)
                                    .stroke(isSelected ? DS.wechatGreen.opacity(0.25) : DS.borderDefault, lineWidth: 1)
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
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        case .publishing:
            ProgressView()
                .controlSize(.mini)
        case .success:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 13))
                .foregroundStyle(Color(hex: 0x10B981))
        case .failed(let msg):
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 13))
                .foregroundStyle(Color(hex: 0xEF4444))
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
        VStack(spacing: 12) {
            InputField(label: "标题", icon: "textformat", text: $state.title, prompt: "自动提取")
                .disabled(state.isBusy)
            InputField(label: "作者", icon: "person.fill", text: $state.author, prompt: {
                if !state.defaultAuthor.isEmpty { return state.defaultAuthor }
                if !state.username.isEmpty { return state.username }
                return "可选"
            }())
                .disabled(state.isBusy)
            InputField(label: "摘要", icon: "text.alignleft", text: $state.summary, prompt: "自动生成", axis: .vertical)
                .disabled(state.isBusy)
        }
    }

    // MARK: - Workflow Timeline

    private var workflowTimeline: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 7) {
                Image(systemName: "bolt.circle.fill")
                    .font(.body)
                    .foregroundStyle(DS.brandGradient)
                Text("工作流")
                    .font(.headline)
                    .foregroundStyle(.primary.opacity(0.7))

                Spacer()

                // 完成计数
                let completed = WorkflowStep.allCases.filter { state.stepStatus($0).isTerminal }.count
                let total = WorkflowStep.allCases.count
                if completed > 0 {
                    Text("\(completed)/\(total)")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.bottom, 8)

            // 步骤列表 — GitHub Actions 手风琴风格
            VStack(spacing: 0) {
                ForEach(Array(WorkflowStep.allCases.enumerated()), id: \.element.id) { index, step in
                    TimelineStepRow(
                        step: step,
                        status: state.stepStatus(step),
                        duration: state.stepDurations[step],
                        streamingText: state.aiCurrentStep == step.label ? state.aiStreamingText : nil,
                        isLast: index == WorkflowStep.allCases.count - 1
                    )
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: DS.r12)
                    .fill(DS.surfacePrimary)
                    .shadow(color: .black.opacity(colorScheme == .dark ? 0.3 : 0.06), radius: 8, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.r12)
                    .stroke(DS.borderDefault, lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: DS.r12))
        }
    }

    // MARK: - AI Status Card

    private var aiStatusCard: some View {
        let available = AIService.isAvailable()
        return HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(available ? Color(hex: 0x10B981).opacity(0.12) : Color.orange.opacity(0.12))
                    .frame(width: 32, height: 32)
                Circle()
                    .fill(available ? Color(hex: 0x10B981) : .orange)
                    .frame(width: 8, height: 8)
                    .shadow(color: available ? Color(hex: 0x10B981).opacity(0.5) : .orange.opacity(0.5), radius: 6)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(available ? "Claude AI" : "Claude CLI")
                    .font(.headline)
                    .foregroundStyle(.primary.opacity(0.8))
                Text(available ? "已就绪" : "未安装")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            Circle()
                .fill(available ? Color(hex: 0x10B981) : .orange)
                .frame(width: 6, height: 6)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: DS.r10)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.r10)
                .stroke(DS.borderSubtle, lineWidth: 0.5)
        )
    }

    // MARK: - Done Section

    private func doneSection(mediaId: String) -> some View {
        VStack(spacing: 14) {
            let successCount = state.profilePublishStatuses.values.filter {
                if case .success = $0 { return true }; return false
            }.count
            let failCount = state.profilePublishStatuses.values.filter {
                if case .failed = $0 { return true }; return false
            }.count
            let total = successCount + failCount

            ZStack {
                Circle()
                    .fill(failCount == 0 ? Color(hex: 0x10B981).opacity(0.08) : Color(hex: 0xF59E0B).opacity(0.08))
                    .frame(width: 64, height: 64)
                Circle()
                    .fill(failCount == 0 ? Color(hex: 0x10B981).opacity(0.12) : Color(hex: 0xF59E0B).opacity(0.12))
                    .frame(width: 48, height: 48)
                Image(systemName: failCount == 0 ? "checkmark" : "exclamationmark")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(failCount == 0 ? DS.successGradient : DS.warningGradient)
            }

            Text(failCount == 0 ? "全部发布成功！" : "发布完成 (\(successCount)/\(total) 成功)")
                .font(.title2.bold())
                .foregroundStyle(.primary)

            // 每个账号的结果
            VStack(spacing: 4) {
                ForEach(profileManager.profiles.filter({ state.profilePublishStatuses[$0.id] != nil })) { profile in
                    if let status = state.profilePublishStatuses[profile.id] {
                        HStack(spacing: 6) {
                            switch status {
                            case .success:
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color(hex: 0x10B981))
                            case .failed:
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color(hex: 0xEF4444))
                            default:
                                EmptyView()
                            }
                            Text(profile.name)
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                            Spacer()
                            if case .failed(let msg) = status {
                                Text(msg)
                                    .font(.system(size: 11))
                                    .foregroundStyle(Color(hex: 0xEF4444).opacity(0.8))
                                    .lineLimit(3)
                                    .textSelection(.enabled)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 8)

            // 发布日志（可折叠）
            if !state.publishLog.isEmpty {
                DisclosureGroup("发布日志") {
                    ScrollView {
                        Text(state.publishLog.joined(separator: "\n"))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                    .frame(maxHeight: 200)
                }
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: DS.r12)
                .fill(DS.surfacePrimary)
                .shadow(color: Color(hex: 0x10B981).opacity(0.08), radius: 12, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.r12)
                .stroke(Color(hex: 0x10B981).opacity(0.15), lineWidth: 1)
        )
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 10) {
            if state.isReviewing {
                ActionButton(
                    label: state.selectedProfileIds.count > 1
                        ? "发布到 \(state.selectedProfileIds.count) 个账号"
                        : "确认发布",
                    icon: "paperplane.fill",
                    style: .brand
                ) {
                    confirmPublish()
                }

                ActionButton(label: "返回编辑", icon: "arrow.uturn.left", style: .ghost) {
                    cancelReview()
                }
            } else if state.isPublishing {
                HStack(spacing: 10) {
                    ProgressView()
                        .controlSize(.small)
                    Text("正在发布到 \(state.selectedProfileIds.count) 个账号...")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            } else if case .done = state.workflowState {
                ActionButton(label: "新建文章", icon: "plus.circle.fill", style: .ghost) {
                    resetAll()
                }
            } else if case .failed = state.workflowState {
                ActionButton(label: "重试", icon: "arrow.clockwise", style: .warning) {
                    startWorkflow()
                }
                ActionButton(label: "重置", icon: "xmark", style: .ghost) {
                    state.resetWorkflow()
                }
            } else {
                ActionButton(
                    label: state.isProcessing ? "处理中..." : "开始处理",
                    icon: state.isProcessing ? nil : "wand.and.stars",
                    style: .brand,
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
        state.profileContents = [:]
        state.originalContent = state.content
        showOriginalContent = false

        Task {
            do {
                let originalContent = state.content
                var title = state.title
                var summary = state.summary

                state.updateStep(.inputDetection, status: .running)
                let format = PublishService.detectInputFormat(content: originalContent, fileURL: droppedFileURL)
                state.inputFormat = format
                state.updateStep(.inputDetection, status: .completed(format.rawValue))

                if format == .html {
                    state.updateStep(.roleAdaptation, status: .skipped("HTML 直接发布"))
                    state.updateStep(.deAI, status: .skipped("HTML 直接发布"))
                    state.updateStep(.themeSelection, status: .skipped("HTML 直接发布"))
                    state.updateStep(.imageGeneration, status: .skipped("HTML 直接发布"))
                    // HTML 模式所有账号共享同一份内容
                    for id in state.selectedProfileIds {
                        state.profileContents[id] = originalContent
                    }
                    state.processedContent = originalContent
                    state.activeReviewProfileId = state.primaryProfileId
                    state.workflowState = .reviewing
                    return
                }

                // 收集需要处理的账号及其人设
                let selectedIds = Array(state.selectedProfileIds).sorted { $0.uuidString < $1.uuidString }
                let profiles = profileManager.profiles

                if AIService.isAvailable() {
                    // --- 逐账号独立 AI 适配 ---
                    var personaNames: [String] = []

                    state.updateStep(.roleAdaptation, status: .running)
                    for (i, profileId) in selectedIds.enumerated() {
                        guard let profile = profiles.first(where: { $0.id == profileId }) else { continue }
                        guard let persona = PersonaLibrary.shared.persona(id: profile.personaId) else { continue }

                        let label = "\(profile.name)(\(persona.displayName))"
                        state.aiCurrentStep = "角色适配 [\(i+1)/\(selectedIds.count)] \(label)"
                        state.aiStreamingText = ""

                        var content = originalContent
                        do {
                            content = try await AIService.adaptRole(
                                content: content, persona: persona,
                                onStream: { [state] chunk in Task { @MainActor in state.aiStreamingText += chunk } }
                            )
                            personaNames.append(label)
                        } catch {
                            // 适配失败则保留原文
                        }

                        state.profileContents[profileId] = content
                    }
                    state.updateStep(.roleAdaptation, status: .completed(personaNames.joined(separator: " / ")))

                    // --- 逐账号去 AI 味 ---
                    state.updateStep(.deAI, status: .running)
                    var lastScore: Int?
                    var lastRating: String?
                    for (i, profileId) in selectedIds.enumerated() {
                        guard let profile = profiles.first(where: { $0.id == profileId }) else { continue }
                        guard let persona = PersonaLibrary.shared.persona(id: profile.personaId) else { continue }
                        guard var content = state.profileContents[profileId] else { continue }

                        state.aiCurrentStep = "去 AI 味 [\(i+1)/\(selectedIds.count)] \(profile.name)"
                        state.aiStreamingText = ""

                        do {
                            let deAIResult = try await AIService.deAI(
                                content: content, persona: persona,
                                onStream: { [state] chunk in Task { @MainActor in state.aiStreamingText += chunk } }
                            )
                            content = deAIResult.content
                            lastScore = deAIResult.score
                            lastRating = deAIResult.rating
                        } catch {
                            // 去AI味失败则保留当前内容
                        }

                        state.profileContents[profileId] = content
                    }
                    state.deAIScore = lastScore
                    state.deAIRating = lastRating
                    let scoreText = lastScore.map { "\($0)/50" } ?? ""
                    let ratingText = lastRating ?? ""
                    state.updateStep(.deAI, status: .completed(
                        [scoreText, ratingText].filter { !$0.isEmpty }.joined(separator: " ")
                    ))

                    // --- 标题和摘要（基于主账号内容生成一次） ---
                    let primaryContent = state.profileContents[selectedIds.first ?? UUID()] ?? originalContent
                    if title.isEmpty {
                        title = try await AIService.generateTitle(content: primaryContent)
                        state.title = title
                    }
                    if summary.isEmpty {
                        summary = try await AIService.generateSummary(content: primaryContent, title: title)
                        state.summary = summary
                    }

                    // --- 主题配色（基于主账号人设选一次） ---
                    state.updateStep(.themeSelection, status: .running)
                    if let firstProfile = profiles.first(where: { $0.id == selectedIds.first }),
                       let firstPersona = PersonaLibrary.shared.persona(id: firstProfile.personaId) {
                        do {
                            let themeResult = try await AIService.selectTheme(content: primaryContent, persona: firstPersona)
                            state.selectedTheme = themeResult.theme
                            state.selectedColor = themeResult.color
                            state.updateStep(.themeSelection, status: .completed(
                                "\(themeResult.theme.displayName) · \(themeResult.color.rawValue)"
                            ))
                        } catch {
                            state.updateStep(.themeSelection, status: .failed(error.localizedDescription))
                        }
                    } else {
                        state.updateStep(.themeSelection, status: .skipped("无可用人设"))
                    }

                    // --- 逐账号 AI 配图 ---
                    if !state.imageApiKey.isEmpty {
                        state.updateStep(.imageGeneration, status: .running)
                        var totalImages = 0
                        for (i, profileId) in selectedIds.enumerated() {
                            guard let profile = profiles.first(where: { $0.id == profileId }) else { continue }
                            guard var content = state.profileContents[profileId] else { continue }

                            state.aiCurrentStep = "AI 配图 [\(i+1)/\(selectedIds.count)] \(profile.name)"
                            do {
                                let images = try await AIService.analyzeImages(content: content, title: title)
                                if !images.isEmpty {
                                    content = PublishService.insertImagePlaceholders(content: content, images: images)
                                    state.profileContents[profileId] = content
                                    totalImages += images.count
                                }
                            } catch {
                                // 配图失败不阻塞
                            }
                        }
                        state.updateStep(.imageGeneration, status: .completed(
                            totalImages == 0 ? "无需插图" : "已插入 \(totalImages) 张配图提示"
                        ))
                    } else {
                        state.updateStep(.imageGeneration, status: .skipped("未配置 IMAGE_API_KEY"))
                    }
                } else {
                    state.updateStep(.roleAdaptation, status: .skipped("Claude CLI 未安装"))
                    state.updateStep(.deAI, status: .skipped("Claude CLI 未安装"))
                    state.updateStep(.themeSelection, status: .skipped("Claude CLI 未安装"))
                    state.updateStep(.imageGeneration, status: .skipped("Claude CLI 未安装"))
                    // 无 AI 时所有账号共享原始内容
                    for id in selectedIds {
                        state.profileContents[id] = originalContent
                    }
                }

                state.aiStreamingText = ""
                state.aiCurrentStep = ""
                // 将主账号内容加载到编辑器
                let firstId = selectedIds.first
                state.activeReviewProfileId = firstId
                state.content = state.profileContents[firstId ?? UUID()] ?? originalContent
                state.processedContent = state.content
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

        // 保存当前编辑器中的内容到对应账号
        if let activeId = state.activeReviewProfileId {
            state.profileContents[activeId] = state.content
        }

        // 初始化每个选中账号的发布状态
        for id in state.selectedProfileIds {
            state.profilePublishStatuses[id] = .pending
        }

        let title = state.title
        let summary = state.summary
        let format = state.inputFormat
        let theme = state.selectedTheme
        let color = state.selectedColor
        let profileIds = state.selectedProfileIds
        let profiles = profileManager.profiles
        let profileContents = state.profileContents
        let d = UserDefaults.standard
        let globalImageApiBase = d.string(forKey: "imageApiBase") ?? ""
        let globalImageApiKey = d.string(forKey: "imageApiKey") ?? ""
        let globalImageModel = d.string(forKey: "imageModel") ?? ""

        Task {

            // 逐账号发布（每个账号使用独立适配的内容）
            var successCount = 0
            var failCount = 0
            var lastMediaId = ""

            for profileId in profileIds {
                guard let profile = profiles.first(where: { $0.id == profileId }) else {
                    state.profilePublishStatuses[profileId] = .failed("账号不存在")
                    failCount += 1
                    continue
                }

                guard !profile.wechatAppId.isEmpty && !profile.wechatAppSecret.isEmpty else {
                    state.profilePublishStatuses[profileId] = .failed("未配置凭证")
                    failCount += 1
                    continue
                }

                // 获取该账号独立适配后的内容
                let accountContent = profileContents[profileId] ?? profileContents.values.first ?? ""
                guard !accountContent.isEmpty else {
                    state.profilePublishStatuses[profileId] = .failed("无内容")
                    failCount += 1
                    continue
                }

                // 为该账号准备独立的内容文件
                let filePath: String
                if format == .html {
                    let dir = "/tmp/postwx/\(formattedDate())"
                    try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
                    let slug = PublishService.generateSlug(from: title)
                    filePath = "\(dir)/\(slug)-\(profile.name).html"
                    try? accountContent.write(toFile: filePath, atomically: true, encoding: .utf8)
                } else {
                    let slug = PublishService.generateSlug(from: title.isEmpty ? String(accountContent.prefix(50)) : title)
                    let dir = "/tmp/postwx/\(formattedDate())"
                    try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
                    filePath = "\(dir)/\(slug)-\(profile.name).md"
                    var md = ""
                    if !title.isEmpty { md += "# \(title)\n\n" }
                    md += accountContent
                    try? md.write(toFile: filePath, atomically: true, encoding: .utf8)
                }

                state.profilePublishStatuses[profileId] = .publishing
                state.publishLog.append("[\(profile.name)] 开始发布...")
                state.publishLog.append("[\(profile.name)] 文件: \(filePath), 内容长度: \(accountContent.count)")
                state.publishLog.append("[\(profile.name)] IMAGE_API_KEY: \(globalImageApiKey.isEmpty ? "未配置" : "已配置(\(globalImageApiKey.prefix(8))...)")")

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
                        theme: theme,
                        color: color,
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
                    let errMsg = error.localizedDescription
                    state.profilePublishStatuses[profileId] = .failed(errMsg)
                    failCount += 1
                    state.publishLog.append("[\(profile.name)] 发布失败: \(errMsg)")
                    // 详细错误输出（用于调试）
                    state.publishLog.append("[\(profile.name)] 错误类型: \(type(of: error)), 详情: \(error)")
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
                // 收集每个账号的具体错误信息
                let errorDetails = state.profilePublishStatuses.compactMap { (id, status) -> String? in
                    if case .failed(let msg) = status {
                        let name = profiles.first(where: { $0.id == id })?.name ?? "未知"
                        return "[\(name)] \(msg)"
                    }
                    return nil
                }.joined(separator: "\n")
                publishError = errorDetails.isEmpty ? "所有账号发布均失败" : errorDetails
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

    private func loadCredentials() {
        if profileManager.profiles.isEmpty {
            profileManager.addProfile(AccountProfile())
        }
        // 默认选中所有账号
        state.selectedProfileIds = Set(profileManager.profiles.map(\.id))
        applyPrimaryProfile()
    }
}

// MARK: - Timeline Step Row

struct TimelineStepRow: View {
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
                stepIndicator
                    .frame(width: 18, height: 18)

                // 步骤图标 + 名称
                Image(systemName: step.icon)
                    .font(.system(size: 13))
                    .foregroundStyle(iconTint)

                Text(step.label)
                    .font(.system(size: 14, weight: status == .running ? .medium : .regular))
                    .foregroundStyle(textColor)

                Spacer()

                // 右侧：耗时 / 状态标签
                rightContent

                // 展开箭头（仅有可展开内容时显示）
                if hasExpandableContent {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
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
    private var stepIndicator: some View {
        switch status {
        case .pending:
            Circle()
                .stroke(Color.secondary.opacity(0.25), lineWidth: 1.5)

        case .running:
            Circle()
                .trim(from: 0, to: 0.7)
                .stroke(DS.wechatGreen, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .rotationEffect(.degrees(spinAngle))
                .onAppear {
                    withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                        spinAngle = 360
                    }
                }

        case .completed:
            ZStack {
                Circle()
                    .fill(Color(hex: 0x10B981))

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
                    .fill(Color(hex: 0xEF4444))
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
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(DS.wechatGreen)

        case .completed(let detail):
            HStack(spacing: 6) {
                if !detail.isEmpty {
                    Text(detail)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                if let duration {
                    Text(formatDuration(duration))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }
            }

        case .failed:
            Text("失败")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color(hex: 0xEF4444))

        case .skipped(let reason):
            Text(reason)
                .font(.system(size: 11))
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
                            .font(.system(size: 12, design: .monospaced))
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
                            .font(.system(size: 12))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }

            case .failed(let msg):
                Text(msg)
                    .font(.system(size: 12))
                    .foregroundStyle(.red.opacity(0.8))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)

            case .completed(let detail):
                if !detail.isEmpty {
                    Text(detail)
                        .font(.system(size: 12))
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
        case .running: DS.brandGlow
        case .completed: Color(hex: 0x10B981)
        case .failed: Color(hex: 0xEF4444)
        case .skipped: .secondary
        default: Color.secondary.opacity(0.4)
        }
    }

    private var textColor: Color {
        switch status {
        case .pending: .secondary.opacity(0.6)
        case .running, .completed, .failed: .primary
        case .skipped: .secondary
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

struct LiveStatusBadge: View {
    let label: String
    let icon: String
    let color: Color
    var isAnimated: Bool = false

    @State private var isPulsing = false

    var body: some View {
        HStack(spacing: 6) {
            ZStack {
                if isAnimated {
                    Circle()
                        .fill(color.opacity(0.3))
                        .frame(width: 14, height: 14)
                        .scaleEffect(isPulsing ? 1.4 : 1.0)
                        .opacity(isPulsing ? 0 : 1)
                        .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: false), value: isPulsing)
                }
                Circle()
                    .fill(color)
                    .frame(width: 6, height: 6)
                    .shadow(color: color.opacity(0.5), radius: 4)
            }
            .frame(width: 14, height: 14)

            Image(systemName: icon)
                .font(.subheadline.bold())
            Text(label)
                .font(.headline)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(color.opacity(0.08), in: Capsule())
        .overlay(Capsule().stroke(color.opacity(0.15), lineWidth: 0.5))
        .onAppear { isPulsing = true }
    }
}

struct IconButton: View {
    let icon: String
    var size: ButtonSize = .regular
    let action: () -> Void
    @State private var isHovered = false

    enum ButtonSize {
        case small, regular
        var dimension: CGFloat { self == .small ? 26 : 34 }
        var font: CGFloat { self == .small ? 11 : 13 }
        var radius: CGFloat { self == .small ? 5 : 7 }
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size.font, weight: .medium))
                .foregroundStyle(isHovered ? .primary : .secondary)
                .frame(width: size.dimension, height: size.dimension)
                .background(
                    RoundedRectangle(cornerRadius: size.radius)
                        .fill(isHovered ? Color.primary.opacity(0.08) : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

struct InputField: View {
    let label: String
    let icon: String
    @Binding var text: String
    var prompt: String = ""
    var axis: Axis = .horizontal

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                Text(label)
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
            TextField(prompt, text: $text, axis: axis)
                .textFieldStyle(.plain)
                .font(.body)
                .focused($isFocused)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: DS.r8)
                        .fill(DS.surfaceInput)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DS.r8)
                        .stroke(isFocused ? DS.borderActive : DS.borderDefault, lineWidth: isFocused ? 1.5 : 0.5)
                )
                .animation(.easeOut(duration: 0.15), value: isFocused)
        }
    }
}

struct ScoreBadge: View {
    let score: Int
    private var color: Color {
        score >= 45 ? Color(hex: 0x10B981) : score >= 35 ? .orange : Color(hex: 0xEF4444)
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "shield.checkered")
                .font(.subheadline)
            Text("\(score)/50")
                .font(.subheadline.bold().monospacedDigit())
        }
        .foregroundStyle(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(color.opacity(0.10), in: Capsule())
    }
}

struct ActionButton: View {
    let label: String
    var icon: String?
    var style: Style = .brand
    var isLoading: Bool = false
    var action: () -> Void
    @State private var isHovered = false

    enum Style {
        case brand, warning, ghost
    }

    private var gradient: LinearGradient {
        switch style {
        case .brand: DS.brandGradient
        case .warning: DS.warningGradient
        case .ghost: LinearGradient(colors: [.clear], startPoint: .leading, endPoint: .trailing)
        }
    }

    private var glowColor: Color {
        switch style {
        case .brand: DS.brandGlow
        case .warning: Color(hex: 0xF59E0B)
        case .ghost: .clear
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .tint(style == .ghost ? .primary : .white)
                } else if let icon {
                    Image(systemName: icon)
                        .font(.body.weight(.semibold))
                }
                Text(label)
                    .font(.headline)
            }
            .foregroundStyle(style == .ghost ? Color.primary.opacity(0.7) : Color.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: DS.r10)
                    .fill(style == .ghost ? AnyShapeStyle(Color.primary.opacity(isHovered ? 0.08 : 0.04)) : AnyShapeStyle(gradient))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.r10)
                    .stroke(style == .ghost ? Color.primary.opacity(0.08) : Color.clear, lineWidth: 0.5)
            )
            .shadow(color: glowColor.opacity(isHovered ? 0.3 : 0.15), radius: isHovered ? 12 : 6, y: isHovered ? 4 : 2)
            .scaleEffect(isHovered ? 1.01 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.15), value: isHovered)
    }
}
