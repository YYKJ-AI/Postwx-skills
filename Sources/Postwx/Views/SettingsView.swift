import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    var state: AppState?
    var pm = ProfileManager.shared
    var onDismiss: (() -> Void)?

    @State private var editingProfile: AccountProfile = AccountProfile()
    @State private var wechatTestState: TestState = .idle
    @State private var imageTestState: TestState = .idle
    @State private var claudeTestState: TestState = .idle
    @State private var showNewProfileSheet = false
    @State private var newProfileName = ""
    @State private var profileToDelete: AccountProfile?
    @State private var editingName = false

    // 全局 AI 配图设置（非每账号）
    @AppStorage("imageApiBase") private var imageApiBase = ""
    @AppStorage("imageApiKey") private var imageApiKey = ""
    @AppStorage("imageModel") private var imageModel = ""

    var body: some View {
        VStack(spacing: 0) {
            settingsHeader
            Rectangle().fill(Color.white.opacity(0.06)).frame(height: 0.5)

            HSplitView {
                // 左侧：账号列表
                accountList
                    .frame(width: 170)

                // 右侧：选中账号的完整配置
                profileDetail
                    .frame(minWidth: 340)
            }
        }
        .frame(width: 560, height: 640)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear { loadEditingProfile() }
        .onDisappear { syncToState() }
        .sheet(isPresented: $showNewProfileSheet) {
            newProfileSheet
        }
        .alert("删除账号", isPresented: Binding(
            get: { profileToDelete != nil },
            set: { if !$0 { profileToDelete = nil } }
        )) {
            Button("取消", role: .cancel) { profileToDelete = nil }
            Button("删除", role: .destructive) {
                if let p = profileToDelete {
                    pm.deleteProfile(id: p.id)
                    loadEditingProfile()
                    syncToState()
                }
            }
        } message: {
            Text("确定删除「\(profileToDelete?.name ?? "")」？此操作不可恢复。")
        }
    }

    // MARK: - Header

    private var settingsHeader: some View {
        HStack {
            Spacer()
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(LinearGradient(
                            colors: [Color(hex: 0x07C160), Color(hex: 0x06AD56)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ))
                        .frame(width: 26, height: 26)
                        .shadow(color: Color(hex: 0x07C160).opacity(0.25), radius: 6, y: 2)
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                }
                Text("账号管理")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
            }
            Spacer()
        }
        .overlay(alignment: .trailing) {
            Button { onDismiss?() ?? dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 26, height: 26)
                    .background(.quaternary.opacity(0.5), in: Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 22)
        .padding(.top, 20)
        .padding(.bottom, 14)
    }

    // MARK: - Account List (Left Sidebar)

    private var accountList: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 6) {
                    ForEach(pm.profiles) { profile in
                        let isSelected = profile.id == editingProfile.id
                        Button {
                            saveCurrentAndSwitch(to: profile)
                        } label: {
                            HStack(spacing: 10) {
                                Circle()
                                    .fill(profileColor(for: profile))
                                    .frame(width: 9, height: 9)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(profile.name)
                                        .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)
                                    if let persona = PersonaLibrary.shared.persona(id: profile.personaId) {
                                        Text(persona.displayName)
                                            .font(.system(size: 12))
                                            .foregroundStyle(.tertiary)
                                    }
                                }

                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(isSelected ? Color(hex: 0x07C160).opacity(0.10) : Color.primary.opacity(0.02))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(isSelected ? Color(hex: 0x07C160).opacity(0.3) : Color.primary.opacity(0.06), lineWidth: 1)
                            )
                            .contentShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(10)
            }

            Rectangle().fill(Color.primary.opacity(0.06)).frame(height: 0.5)

            // 新建 / 删除
            HStack(spacing: 4) {
                SidebarToolbarButton(icon: "plus", help: "新建账号") {
                    newProfileName = ""
                    showNewProfileSheet = true
                }

                SidebarToolbarButton(icon: "minus", help: "删除当前账号", disabled: pm.profiles.count <= 1) {
                    if pm.profiles.count > 1 {
                        profileToDelete = editingProfile
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
        }
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
    }

    private func profileColor(for profile: AccountProfile) -> Color {
        profile.wechatAppId.isEmpty ? .orange : Color(hex: 0x10B981)
    }

    // MARK: - Profile Detail (Right)

    private var profileDetail: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 账号名称（可编辑）
                HStack(spacing: 8) {
                    if editingName {
                        TextField("账号名称", text: $editingProfile.name)
                            .textFieldStyle(.plain)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color(nsColor: .textBackgroundColor))
                            )
                            .onSubmit { editingName = false }
                    } else {
                        Text(editingProfile.name)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                    }

                    Button {
                        editingName.toggle()
                    } label: {
                        Image(systemName: editingName ? "checkmark.circle.fill" : "pencil.circle")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)

                    Spacer()
                }

                // 用户信息
                SCard(title: "用户信息", icon: "person.circle.fill", color: Color(hex: 0x07C160)) {
                    VStack(spacing: 10) {
                        STextField("用户名", text: $editingProfile.username)
                        STextField("默认作者", text: $editingProfile.defaultAuthor)
                    }
                }

                // 创作人设
                SCard(title: "创作人设", icon: "person.text.rectangle.fill", color: Color(hex: 0xF59E0B)) {
                    SPickerField("人设", selection: $editingProfile.personaId) {
                        ForEach(PersonaLibrary.shared.data.personas) { persona in
                            Text(persona.displayName).tag(persona.id)
                        }
                    }

                    if let persona = PersonaLibrary.shared.persona(id: editingProfile.personaId) {
                        Text(persona.prompt)
                            .font(.system(size: 12))
                            .foregroundStyle(.tertiary)
                            .padding(.top, 2)
                    }
                }

                // 微信公众号凭证
                SCard(title: "微信公众号", icon: "message.fill", color: Color(hex: 0x10B981)) {
                    VStack(spacing: 10) {
                        STextField("App ID", text: $editingProfile.wechatAppId)
                        SSecureField("App Secret", text: $editingProfile.wechatAppSecret)
                    }
                    STestButton(state: wechatTestState, label: "测试连接",
                                disabled: editingProfile.wechatAppId.isEmpty || editingProfile.wechatAppSecret.isEmpty) { testWechat() }
                }

                // 发布设置
                SCard(title: "发布设置", icon: "paperplane.fill", color: Color(hex: 0x06B6D4)) {
                    VStack(spacing: 10) {
                        Toggle(isOn: $editingProfile.needOpenComment) {
                            HStack(spacing: 6) {
                                Image(systemName: "bubble.left.and.bubble.right")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                                Text("开启评论")
                                    .font(.system(size: 13))
                            }
                        }
                        .toggleStyle(.switch)

                        Toggle(isOn: $editingProfile.onlyFansCanComment) {
                            HStack(spacing: 6) {
                                Image(systemName: "heart.circle")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                                Text("仅粉丝可评论")
                                    .font(.system(size: 13))
                            }
                        }
                        .toggleStyle(.switch)
                    }
                }

                // AI 配图（全局设置）
                SCard(title: "AI 配图", icon: "photo.artframe", color: Color(hex: 0x06AD56), badge: "可选") {
                    VStack(spacing: 10) {
                        STextField("API Base URL", text: $imageApiBase, placeholder: "https://api.tu-zi.com")
                        SSecureField("API Key", text: $imageApiKey)
                        STextField("模型", text: $imageModel, placeholder: "gpt-image-1")
                    }
                    Text("兼容 OpenAI Images API 格式的服务均可使用")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                    STestButton(state: imageTestState, label: "测试生图",
                                disabled: imageApiKey.isEmpty) { testImage() }
                }

                // AI 润色
                SCard(title: "AI 润色", icon: "sparkles", color: Color(hex: 0x06AD56)) {
                    HStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(AIService.isAvailable() ? Color(hex: 0x10B981).opacity(0.12) : Color.orange.opacity(0.12))
                                .frame(width: 28, height: 28)
                            Circle()
                                .fill(AIService.isAvailable() ? Color(hex: 0x10B981) : .orange)
                                .frame(width: 7, height: 7)
                                .shadow(color: AIService.isAvailable() ? Color(hex: 0x10B981).opacity(0.5) : .orange.opacity(0.5), radius: 4)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(AIService.isAvailable() ? "Claude Code 已就绪" : "未检测到 claude CLI")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.primary.opacity(0.8))
                            Text(AIService.isAvailable() ? "自动使用系统级认证" : "需要安装 claude CLI")
                                .font(.system(size: 12))
                                .foregroundStyle(.tertiary)
                        }
                    }

                    if AIService.isAvailable() {
                        STestButton(state: claudeTestState, label: "测试 AI", disabled: false) { testClaude() }
                    } else {
                        HStack(spacing: 5) {
                            Image(systemName: "terminal")
                                .font(.system(size: 12))
                                .foregroundStyle(.tertiary)
                            Text("npm install -g @anthropic-ai/claude-code")
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(.tertiary)
                                .textSelection(.enabled)
                        }
                    }
                }

                HStack {
                    Spacer()
                    Button { importFromEnv() } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "square.and.arrow.down")
                                .font(.system(size: 11))
                            Text("从 .env 文件导入凭证")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
            }
            .padding(22)
        }
    }

    // MARK: - New Profile Sheet

    private var newProfileSheet: some View {
        VStack(spacing: 16) {
            Text("新建账号")
                .font(.system(size: 15, weight: .bold, design: .rounded))

            STextField("账号名称", text: $newProfileName, placeholder: "如：技术号、生活号")

            HStack(spacing: 12) {
                Button("取消") {
                    showNewProfileSheet = false
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial, in: Capsule())

                Button("创建") {
                    var profile = AccountProfile()
                    profile.name = newProfileName.isEmpty ? "新账号" : newProfileName
                    pm.addProfile(profile)
                    pm.switchProfile(id: profile.id)
                    loadEditingProfile()
                    showNewProfileSheet = false
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .foregroundStyle(.white)
                .background(
                    LinearGradient(
                        colors: [Color(hex: 0x07C160), Color(hex: 0x06AD56)],
                        startPoint: .leading, endPoint: .trailing
                    ),
                    in: Capsule()
                )
            }
        }
        .padding(24)
        .frame(width: 320)
    }

    // MARK: - Helpers

    private func loadEditingProfile() {
        if let p = pm.currentProfile {
            editingProfile = p
        }
    }

    private func saveCurrentAndSwitch(to profile: AccountProfile) {
        pm.currentProfile = editingProfile
        pm.save()
        pm.switchProfile(id: profile.id)
        loadEditingProfile()
        wechatTestState = .idle
        imageTestState = .idle
        claudeTestState = .idle
    }

    // MARK: - Actions

    private func testWechat() {
        wechatTestState = .testing
        Task {
            do {
                let msg = try await PublishService.testWechatCredentials(appId: editingProfile.wechatAppId, appSecret: editingProfile.wechatAppSecret)
                wechatTestState = .success(msg)
            } catch { wechatTestState = .failure(friendlyNetworkError(error)) }
        }
    }

    private func testImage() {
        imageTestState = .testing
        Task {
            do {
                let msg = try await PublishService.testImageGeneration(apiBase: imageApiBase, apiKey: imageApiKey, model: imageModel)
                imageTestState = .success(msg)
            } catch { imageTestState = .failure(friendlyNetworkError(error)) }
        }
    }

    private func testClaude() {
        claudeTestState = .testing
        Task {
            do {
                let msg = try await AIService.testConnection()
                claudeTestState = .success(msg)
            } catch { claudeTestState = .failure(error.localizedDescription) }
        }
    }

    private func friendlyNetworkError(_ error: Error) -> String {
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            switch nsError.code {
            case NSURLErrorNotConnectedToInternet: return "无网络连接"
            case NSURLErrorTimedOut: return "连接超时"
            case NSURLErrorCannotFindHost: return "无法找到服务器"
            case NSURLErrorCannotConnectToHost: return "无法连接到服务器"
            case NSURLErrorSecureConnectionFailed: return "SSL 连接失败"
            default: return "网络错误"
            }
        }
        return error.localizedDescription
    }

    private func importFromEnv() {
        let candidates = [
            FileManager.default.currentDirectoryPath + "/.baoyu-skills/.env",
            NSHomeDirectory() + "/.baoyu-skills/.env",
        ]
        for path in candidates {
            guard let content = try? String(contentsOfFile: path, encoding: .utf8) else { continue }
            for line in content.components(separatedBy: .newlines) {
                let parts = line.split(separator: "=", maxSplits: 1)
                guard parts.count == 2 else { continue }
                let key = String(parts[0]).trimmingCharacters(in: .whitespaces)
                var value = String(parts[1]).trimmingCharacters(in: .whitespaces)
                if (value.hasPrefix("\"") && value.hasSuffix("\"")) || (value.hasPrefix("'") && value.hasSuffix("'")) {
                    value = String(value.dropFirst().dropLast())
                }
                switch key {
                case "WECHAT_APP_ID": editingProfile.wechatAppId = value
                case "WECHAT_APP_SECRET": editingProfile.wechatAppSecret = value
                case "IMAGE_API_KEY": imageApiKey = value
                case "IMAGE_API_BASE": imageApiBase = value
                case "IMAGE_MODEL": imageModel = value
                default: break
                }
            }
            break
        }
    }

    private func syncToState() {
        pm.currentProfile = editingProfile
        pm.save()
        guard let state else { return }
        pm.applyToState(state)
    }
}

// MARK: - Test State

enum TestState: Equatable {
    case idle, testing
    case success(String)
    case failure(String)
}

// MARK: - Settings Components

struct SCard<Content: View>: View {
    let title: String
    let icon: String
    let color: Color
    var badge: String? = nil
    @ViewBuilder let content: Content
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(color.opacity(0.12))
                        .frame(width: 26, height: 26)
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(color)
                }
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.primary.opacity(0.85))

                if let badge {
                    Text(badge)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Color.primary.opacity(0.05), in: Capsule())
                }
            }
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(nsColor: .controlBackgroundColor))
                .shadow(color: colorScheme == .dark ? .black.opacity(0.25) : .black.opacity(0.05), radius: 8, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(colorScheme == .dark ? 0.06 : 0.0), lineWidth: 0.5)
        )
    }
}

struct STextField: View {
    let label: String
    @Binding var text: String
    var placeholder: String?
    @FocusState private var isFocused: Bool

    init(_ label: String, text: Binding<String>, placeholder: String? = nil) {
        self.label = label
        self._text = text
        self.placeholder = placeholder
    }

    var body: some View {
        TextField(placeholder ?? label, text: $text)
            .textFieldStyle(.plain)
            .font(.system(size: 14))
            .focused($isFocused)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(nsColor: .textBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isFocused ? Color(hex: 0x07C160).opacity(0.4) : Color.white.opacity(0.06), lineWidth: isFocused ? 1.5 : 0.5)
            )
            .textContentType(.none)
            .autocorrectionDisabled()
            .animation(.easeOut(duration: 0.15), value: isFocused)
    }
}

struct SSecureField: View {
    let label: String
    @Binding var text: String
    @FocusState private var isFocused: Bool

    init(_ label: String, text: Binding<String>) {
        self.label = label
        self._text = text
    }

    var body: some View {
        SecureField(label, text: $text)
            .textFieldStyle(.plain)
            .font(.system(size: 14))
            .focused($isFocused)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(nsColor: .textBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isFocused ? Color(hex: 0x07C160).opacity(0.4) : Color.white.opacity(0.06), lineWidth: isFocused ? 1.5 : 0.5)
            )
            .textContentType(.none)
            .animation(.easeOut(duration: 0.15), value: isFocused)
    }
}

struct SPickerField<Content: View>: View {
    let label: String
    @Binding var selection: String
    @ViewBuilder let content: Content

    init(_ label: String, selection: Binding<String>, @ViewBuilder content: () -> Content) {
        self.label = label
        self._selection = selection
        self.content = content()
    }

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 40, alignment: .leading)
            Picker("", selection: $selection) { content }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity)
        }
    }
}

struct SidebarToolbarButton: View {
    let icon: String
    let help: String
    var disabled: Bool = false
    let action: () -> Void
    @State private var isHovered = false
    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(disabled ? Color.secondary.opacity(0.3) : isPressed ? Color.primary : isHovered ? Color.primary.opacity(0.85) : Color.secondary)
                .frame(width: 38, height: 34)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(isPressed ? Color.primary.opacity(0.12) : isHovered ? Color.primary.opacity(0.06) : Color.clear)
                )
                .scaleEffect(isPressed ? 0.92 : 1.0)
                .animation(.easeOut(duration: 0.12), value: isPressed)
                .animation(.easeOut(duration: 0.15), value: isHovered)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .onHover { isHovered = disabled ? false : $0 }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in if !disabled { isPressed = true } }
                .onEnded { _ in isPressed = false }
        )
        .help(help)
    }
}

struct STestButton: View {
    let state: TestState
    let label: String
    let disabled: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            Button(action: action) {
                HStack(spacing: 5) {
                    if state == .testing {
                        ProgressView().controlSize(.mini)
                    } else {
                        Image(systemName: "play.fill")
                            .font(.system(size: 8))
                    }
                    Text(state == .testing ? "测试中..." : label)
                        .font(.system(size: 13, weight: .semibold))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(
                    Capsule().fill(isHovered ? Color.primary.opacity(0.08) : Color.primary.opacity(0.04))
                )
            }
            .buttonStyle(.plain)
            .disabled(disabled || state == .testing)
            .onHover { isHovered = $0 }

            switch state {
            case .success(let msg):
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 12))
                    Text(msg).font(.system(size: 12))
                }
                .foregroundStyle(Color(hex: 0x10B981))
                .transition(.scale.combined(with: .opacity))
            case .failure(let msg):
                HStack(spacing: 4) {
                    Image(systemName: "xmark.circle.fill").font(.system(size: 12))
                    Text(msg).font(.system(size: 12))
                }
                .foregroundStyle(Color(hex: 0xEF4444))
                .lineLimit(2)
                .transition(.scale.combined(with: .opacity))
            default:
                EmptyView()
            }
        }
        .animation(.spring(duration: 0.3), value: state == .testing)
    }
}
