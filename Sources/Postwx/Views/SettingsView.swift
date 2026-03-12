import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    var state: AppState?
    var pm = ProfileManager.shared

    @State private var editingProfile: AccountProfile = AccountProfile()
    @State private var wechatTestState: TestState = .idle
    @State private var showNewProfileSheet = false
    @State private var newProfileName = ""
    @State private var profileToDelete: AccountProfile?
    @State private var editingName = false

    private let accentGradient = LinearGradient(
        colors: [Color(hue: 0.72, saturation: 0.65, brightness: 0.95),
                 Color(hue: 0.58, saturation: 0.70, brightness: 0.90)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.5)

            HSplitView {
                // 左侧：账号列表
                accountList
                    .frame(width: 150)

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

    private var header: some View {
        HStack {
            Spacer()
            HStack(spacing: 6) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(accentGradient)
                Text("账号管理")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
            }
            Spacer()
        }
        .overlay(alignment: .trailing) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
                    .background(.quaternary.opacity(0.5), in: Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 10)
    }

    // MARK: - Account List (Left Sidebar)

    private var accountList: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 4) {
                    ForEach(pm.profiles) { profile in
                        let isSelected = profile.id == editingProfile.id
                        Button {
                            saveCurrentAndSwitch(to: profile)
                        } label: {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(profileColor(for: profile))
                                    .frame(width: 8, height: 8)

                                VStack(alignment: .leading, spacing: 1) {
                                    Text(profile.name)
                                        .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)
                                    if let role = CreatorRole(rawValue: profile.creatorRole) {
                                        Text(role.displayName)
                                            .font(.system(size: 10))
                                            .foregroundStyle(.tertiary)
                                    }
                                }

                                Spacer()
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(isSelected ? Color.accentColor.opacity(0.12) : Color.clear)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(8)
            }

            Divider().opacity(0.3)

            // 新建 / 删除
            HStack(spacing: 4) {
                Button {
                    newProfileName = ""
                    showNewProfileSheet = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .medium))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .help("新建账号")

                Button {
                    if pm.profiles.count > 1 {
                        profileToDelete = editingProfile
                    }
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 11, weight: .medium))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .disabled(pm.profiles.count <= 1)
                .help("删除当前账号")

                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
    }

    private func profileColor(for profile: AccountProfile) -> Color {
        profile.wechatAppId.isEmpty ? .orange : .green
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
                SettingsCard(title: "用户信息", icon: "person.circle.fill", color: .blue) {
                    VStack(spacing: 10) {
                        SettingsTextField("用户名", text: $editingProfile.username)
                        SettingsTextField("默认作者", text: $editingProfile.defaultAuthor)
                    }
                }

                // 创作人设
                SettingsCard(title: "创作人设", icon: "person.text.rectangle.fill", color: .orange) {
                    VStack(spacing: 10) {
                        SettingsPickerField("角色", selection: $editingProfile.creatorRole) {
                            ForEach(CreatorRole.allCases) { role in
                                Text(role.displayName).tag(role.rawValue)
                            }
                        }
                        SettingsPickerField("风格", selection: $editingProfile.writingStyle) {
                            ForEach(WritingStyle.allCases) { style in
                                Text(style.displayName).tag(style.rawValue)
                            }
                        }
                        SettingsPickerField("受众", selection: $editingProfile.targetAudience) {
                            ForEach(TargetAudience.allCases) { audience in
                                Text(audience.displayName).tag(audience.rawValue)
                            }
                        }
                    }

                    // 人设预览
                    if let role = CreatorRole(rawValue: editingProfile.creatorRole) {
                        Text(role.adaptationGuide)
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                            .padding(.top, 2)
                    }
                }

                // 微信公众号凭证
                SettingsCard(title: "微信公众号", icon: "message.fill", color: .green) {
                    VStack(spacing: 10) {
                        SettingsTextField("App ID", text: $editingProfile.wechatAppId)
                        SettingsSecureField("App Secret", text: $editingProfile.wechatAppSecret)
                    }

                    SettingsTestButton(
                        state: wechatTestState,
                        label: "测试连接",
                        disabled: editingProfile.wechatAppId.isEmpty || editingProfile.wechatAppSecret.isEmpty
                    ) {
                        testWechat()
                    }
                }

                // 发布设置
                SettingsCard(title: "发布设置", icon: "paperplane.fill", color: .teal) {
                    VStack(spacing: 8) {
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

                // 导入按钮
                HStack {
                    Spacer()
                    Button {
                        importFromEnv()
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "square.and.arrow.down")
                                .font(.system(size: 11))
                            Text("从 .env 文件导入凭证")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
            }
            .padding(20)
        }
    }

    // MARK: - New Profile Sheet

    private var newProfileSheet: some View {
        VStack(spacing: 16) {
            Text("新建账号")
                .font(.system(size: 15, weight: .bold, design: .rounded))

            SettingsTextField("账号名称", text: $newProfileName, placeholder: "如：技术号、生活号")

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
                .background(accentGradient, in: Capsule())
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
        // 保存当前编辑的
        pm.currentProfile = editingProfile
        pm.save()
        // 切换并加载
        pm.switchProfile(id: profile.id)
        loadEditingProfile()
        // 重置测试状态
        wechatTestState = .idle
    }

    // MARK: - Actions

    private func testWechat() {
        wechatTestState = .testing
        Task {
            do {
                let msg = try await PublishService.testWechatCredentials(appId: editingProfile.wechatAppId, appSecret: editingProfile.wechatAppSecret)
                wechatTestState = .success(msg)
            } catch {
                wechatTestState = .failure(friendlyNetworkError(error))
            }
        }
    }

    private func friendlyNetworkError(_ error: Error) -> String {
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            switch nsError.code {
            case NSURLErrorNotConnectedToInternet: return "无网络连接，请检查网络"
            case NSURLErrorTimedOut: return "连接超时，请稍后再试"
            case NSURLErrorCannotFindHost: return "无法找到服务器，请检查 URL"
            case NSURLErrorCannotConnectToHost: return "无法连接到服务器"
            case NSURLErrorSecureConnectionFailed: return "SSL 连接失败，请检查 URL"
            default: return "网络错误：\(nsError.localizedDescription)"
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
                if (value.hasPrefix("\"") && value.hasSuffix("\"")) ||
                    (value.hasPrefix("'") && value.hasSuffix("'")) {
                    value = String(value.dropFirst().dropLast())
                }

                switch key {
                case "WECHAT_APP_ID": editingProfile.wechatAppId = value
                case "WECHAT_APP_SECRET": editingProfile.wechatAppSecret = value
                case "IMAGE_API_KEY": UserDefaults.standard.set(value, forKey: "imageApiKey")
                case "IMAGE_API_BASE": UserDefaults.standard.set(value, forKey: "imageApiBase")
                case "IMAGE_MODEL": UserDefaults.standard.set(value, forKey: "imageModel")
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
    case idle
    case testing
    case success(String)
    case failure(String)
}

// MARK: - Settings Components

struct SettingsCard<Content: View>: View {
    let title: String
    let icon: String
    let color: Color
    var badge: String? = nil
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundStyle(color)
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary.opacity(0.8))

                if let badge {
                    Text(badge)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.quaternary.opacity(0.5), in: Capsule())
                }
            }

            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(nsColor: .controlBackgroundColor))
                .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
        )
    }
}

struct SettingsTextField: View {
    let label: String
    @Binding var text: String
    var placeholder: String?

    init(_ label: String, text: Binding<String>, placeholder: String? = nil) {
        self.label = label
        self._text = text
        self.placeholder = placeholder
    }

    var body: some View {
        TextField(placeholder ?? label, text: $text)
            .textFieldStyle(.plain)
            .font(.system(size: 13))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(Color(nsColor: .textBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            )
            .textContentType(.none)
            .autocorrectionDisabled()
    }
}

struct SettingsSecureField: View {
    let label: String
    @Binding var text: String

    init(_ label: String, text: Binding<String>) {
        self.label = label
        self._text = text
    }

    var body: some View {
        SecureField(label, text: $text)
            .textFieldStyle(.plain)
            .font(.system(size: 13))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(Color(nsColor: .textBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            )
            .textContentType(.none)
    }
}

struct SettingsPickerField<Content: View>: View {
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
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .frame(width: 40, alignment: .leading)
            Picker("", selection: $selection) {
                content
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity)
        }
    }
}

struct SettingsTestButton: View {
    let state: TestState
    let label: String
    let disabled: Bool
    let action: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(action: action) {
                HStack(spacing: 5) {
                    if state == .testing {
                        ProgressView()
                            .controlSize(.mini)
                    } else {
                        Image(systemName: "play.fill")
                            .font(.system(size: 8))
                    }
                    Text(state == .testing ? "测试中..." : label)
                        .font(.system(size: 11, weight: .medium))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(.ultraThinMaterial, in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(disabled || state == .testing)

            switch state {
            case .success(let msg):
                HStack(spacing: 3) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 10))
                    Text(msg)
                        .font(.system(size: 10))
                }
                .foregroundStyle(.green)
                .transition(.scale.combined(with: .opacity))
            case .failure(let msg):
                HStack(spacing: 3) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 10))
                    Text(msg)
                        .font(.system(size: 10))
                }
                .foregroundStyle(.red)
                .lineLimit(2)
                .transition(.scale.combined(with: .opacity))
            default:
                EmptyView()
            }
        }
        .animation(.snappy(duration: 0.3), value: state == .testing)
    }
}
