import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    var state: AppState?

    @AppStorage("username") private var username = ""
    @AppStorage("wechatAppId") private var appId = ""
    @AppStorage("wechatAppSecret") private var appSecret = ""
    @AppStorage("imageApiBase") private var imageApiBase = ""
    @AppStorage("imageApiKey") private var imageApiKey = ""
    @AppStorage("imageModel") private var imageModel = ""
    @AppStorage("creatorRole") private var creatorRole = "tech-blogger"
    @AppStorage("writingStyle") private var writingStyle = "professional"
    @AppStorage("targetAudience") private var targetAudience = "general"
    @AppStorage("defaultAuthor") private var defaultAuthor = ""
    @AppStorage("needOpenComment") private var needOpenComment = true
    @AppStorage("onlyFansCanComment") private var onlyFansCanComment = false

    @State private var selectedTab = 0
    @State private var wechatTestState: TestState = .idle
    @State private var imageTestState: TestState = .idle
    @State private var claudeTestState: TestState = .idle

    var body: some View {
        VStack(spacing: 0) {
            // 顶部标题栏 + 关闭按钮
            HStack {
                Spacer()
                Text("设置")
                    .font(.headline)
                Spacer()
            }
            .overlay(alignment: .trailing) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.title3)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

            // Tab 切换
            Picker("", selection: $selectedTab) {
                Text("凭证").tag(0)
                Text("偏好").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 24)
            .padding(.bottom, 8)

            Divider()

            // 内容区
            Group {
                if selectedTab == 0 {
                    credentialsTab
                } else {
                    preferencesTab
                }
            }
        }
        .frame(width: 420, height: 580)
        .onDisappear { syncToState() }
    }

    // MARK: - Credentials Tab

    private var credentialsTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 用户信息
                sectionHeader("用户信息")
                settingsTextField("用户名", text: $username)

                Divider()

                // 微信公众号
                sectionHeader("微信公众号")

                VStack(spacing: 10) {
                    settingsTextField("App ID", text: $appId)
                    settingsSecureField("App Secret", text: $appSecret)
                }

                testButton(
                    state: wechatTestState,
                    label: "测试连接",
                    disabled: appId.isEmpty || appSecret.isEmpty
                ) {
                    testWechat()
                }

                Divider()

                // AI 配图
                sectionHeader("AI 配图（可选）")

                VStack(spacing: 10) {
                    settingsTextField("API Base URL", text: $imageApiBase, placeholder: "https://api.tu-zi.com")
                    settingsSecureField("API Key", text: $imageApiKey)
                    settingsTextField("模型", text: $imageModel, placeholder: "gpt-image-1")
                }

                Text("兼容 OpenAI Images API 格式的服务均可使用")
                    .font(.caption)
                    .foregroundStyle(.tertiary)

                testButton(
                    state: imageTestState,
                    label: "测试生图",
                    disabled: imageApiKey.isEmpty
                ) {
                    testImage()
                }

                Divider()

                // Claude Code AI
                sectionHeader("AI 润色")

                HStack(spacing: 6) {
                    Circle()
                        .fill(AIService.isAvailable() ? .green : .orange)
                        .frame(width: 8, height: 8)
                    Text(AIService.isAvailable()
                         ? "Claude Code 已就绪（复用系统认证）"
                         : "未检测到 claude CLI，请先安装 Claude Code")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if AIService.isAvailable() {
                    Text("自动使用系统级 Claude Code 认证，无需额外配置 API Key")
                        .font(.caption)
                        .foregroundStyle(.tertiary)

                    testButton(
                        state: claudeTestState,
                        label: "测试 AI",
                        disabled: false
                    ) {
                        testClaude()
                    }
                } else {
                    Text("安装：npm install -g @anthropic-ai/claude-code")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .textSelection(.enabled)
                }

                Divider()

                // 导入按钮
                Button("从 .env 文件导入") {
                    importFromEnv()
                }
                .buttonStyle(.link)
                .font(.caption)
            }
            .padding(20)
        }
    }

    // MARK: - Preferences Tab

    private var preferencesTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                sectionHeader("创作角色")

                VStack(spacing: 10) {
                    settingsPicker("角色", selection: $creatorRole) {
                        ForEach(CreatorRole.allCases) { role in
                            Text(role.displayName).tag(role.rawValue)
                        }
                    }
                    settingsPicker("风格", selection: $writingStyle) {
                        ForEach(WritingStyle.allCases) { style in
                            Text(style.displayName).tag(style.rawValue)
                        }
                    }
                    settingsPicker("受众", selection: $targetAudience) {
                        ForEach(TargetAudience.allCases) { audience in
                            Text(audience.displayName).tag(audience.rawValue)
                        }
                    }
                }

                sectionHeader("发布设置")

                VStack(spacing: 10) {
                    settingsTextField("默认作者", text: $defaultAuthor)
                    settingsToggle("开启评论", isOn: $needOpenComment)
                    settingsToggle("仅粉丝可评论", isOn: $onlyFansCanComment)
                }
            }
            .padding(20)
        }
    }

    // MARK: - Components

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.secondary)
    }

    private func settingsTextField(_ label: String, text: Binding<String>, placeholder: String? = nil) -> some View {
        TextField(placeholder ?? label, text: text)
            .textFieldStyle(.roundedBorder)
            .textContentType(.none)
            .autocorrectionDisabled()
    }

    private func settingsSecureField(_ label: String, text: Binding<String>) -> some View {
        SecureField(label, text: text)
            .textFieldStyle(.roundedBorder)
            .textContentType(.none)
    }

    private func settingsPicker<Content: View>(
        _ label: String,
        selection: Binding<String>,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack {
            Text(label)
                .frame(width: 40, alignment: .leading)
            Picker("", selection: selection) {
                content()
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity)
        }
    }

    private func settingsToggle(_ label: String, isOn: Binding<Bool>) -> some View {
        Toggle(label, isOn: isOn)
            .toggleStyle(.switch)
    }

    private func testButton(state: TestState, label: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        HStack(spacing: 8) {
            Button(action: action) {
                HStack(spacing: 4) {
                    if state == .testing {
                        ProgressView()
                            .controlSize(.mini)
                    }
                    Text(state == .testing ? "测试中..." : label)
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(disabled || state == .testing)

            switch state {
            case .success(let msg):
                Label(msg, systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
            case .failure(let msg):
                Label(msg, systemImage: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(2)
            default:
                EmptyView()
            }
        }
    }

    // MARK: - Actions

    private func testWechat() {
        wechatTestState = .testing
        Task {
            do {
                let msg = try await PublishService.testWechatCredentials(appId: appId, appSecret: appSecret)
                wechatTestState = .success(msg)
            } catch {
                wechatTestState = .failure(friendlyNetworkError(error))
            }
        }
    }

    private func testImage() {
        imageTestState = .testing
        Task {
            do {
                let msg = try await PublishService.testImageGeneration(
                    apiBase: imageApiBase,
                    apiKey: imageApiKey,
                    model: imageModel
                )
                imageTestState = .success(msg)
            } catch {
                imageTestState = .failure(friendlyNetworkError(error))
            }
        }
    }

    private func testClaude() {
        claudeTestState = .testing
        Task {
            do {
                let msg = try await AIService.testConnection()
                claudeTestState = .success(msg)
            } catch {
                claudeTestState = .failure(error.localizedDescription)
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
                // 去掉引号
                if (value.hasPrefix("\"") && value.hasSuffix("\"")) ||
                    (value.hasPrefix("'") && value.hasSuffix("'")) {
                    value = String(value.dropFirst().dropLast())
                }

                switch key {
                case "WECHAT_APP_ID": appId = value
                case "WECHAT_APP_SECRET": appSecret = value
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
        guard let state else { return }
        state.username = username
        state.wechatAppId = appId
        state.wechatAppSecret = appSecret
        state.imageApiBase = imageApiBase
        state.imageApiKey = imageApiKey
        state.imageModel = imageModel
        state.defaultAuthor = defaultAuthor

        // 同步作者：如果作者为空或等于旧的默认值，则更新为新的默认作者/用户名
        let fallbackAuthor = defaultAuthor.isEmpty ? username : defaultAuthor
        if state.author.isEmpty || state.author == state.defaultAuthor || state.author == state.username {
            state.author = fallbackAuthor
        }

        if let r = CreatorRole(rawValue: creatorRole) { state.creatorRole = r }
        if let s = WritingStyle(rawValue: writingStyle) { state.writingStyle = s }
        if let a = TargetAudience(rawValue: targetAudience) { state.targetAudience = a }
        state.needOpenComment = needOpenComment
        state.onlyFansCanComment = onlyFansCanComment
    }
}

// MARK: - Test State

enum TestState: Equatable {
    case idle
    case testing
    case success(String)
    case failure(String)
}
