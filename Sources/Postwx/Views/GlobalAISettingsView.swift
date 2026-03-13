import SwiftUI

struct GlobalAISettingsView: View {
    @Environment(\.dismiss) private var dismiss
    var onDismiss: (() -> Void)?

    @AppStorage("imageApiBase") private var imageApiBase = ""
    @AppStorage("imageApiKey") private var imageApiKey = ""
    @AppStorage("imageModel") private var imageModel = ""

    @State private var imageTestState: TestState = .idle
    @State private var claudeTestState: TestState = .idle

    private let accentGradient = LinearGradient(
        colors: [Color(hue: 0.72, saturation: 0.65, brightness: 0.95),
                 Color(hue: 0.58, saturation: 0.70, brightness: 0.90)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Spacer()
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 13))
                        .foregroundStyle(accentGradient)
                    Text("AI 设置")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                }
                Spacer()
            }
            .overlay(alignment: .trailing) {
                Button {
                    onDismiss?() ?? dismiss()
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
            .padding(.bottom, 12)

            Divider().opacity(0.5)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("以下配置全局生效，所有账号共享")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)

                    // AI 配图
                    SCard(title: "AI 配图", icon: "photo.artframe", color: .purple) {
                        VStack(spacing: 10) {
                            STextField("API Base URL", text: $imageApiBase, placeholder: "https://api.tu-zi.com")
                            SSecureField("API Key", text: $imageApiKey)
                            STextField("模型", text: $imageModel, placeholder: "gpt-image-1")
                        }

                        Text("兼容 OpenAI Images API 格式的服务均可使用")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)

                        STestButton(
                            state: imageTestState,
                            label: "测试生图",
                            disabled: imageApiKey.isEmpty
                        ) {
                            testImage()
                        }
                    }

                    // AI 润色
                    SCard(title: "AI 润色", icon: "wand.and.stars", color: .indigo) {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(AIService.isAvailable() ? .green : .orange)
                                .frame(width: 7, height: 7)
                                .shadow(color: AIService.isAvailable() ? .green.opacity(0.4) : .orange.opacity(0.4), radius: 3)
                            Text(AIService.isAvailable()
                                 ? "Claude Code 已就绪"
                                 : "未检测到 claude CLI")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }

                        if AIService.isAvailable() {
                            Text("自动使用系统级认证，无需额外配置")
                                .font(.system(size: 10))
                                .foregroundStyle(.tertiary)

                            STestButton(
                                state: claudeTestState,
                                label: "测试 AI",
                                disabled: false
                            ) {
                                testClaude()
                            }
                        } else {
                            HStack(spacing: 4) {
                                Image(systemName: "terminal")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.tertiary)
                                Text("npm install -g @anthropic-ai/claude-code")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(.tertiary)
                                    .textSelection(.enabled)
                            }
                        }
                    }
                }
                .padding(20)
            }
        }
        .frame(width: 400, height: 420)
        .background(Color(nsColor: .windowBackgroundColor))
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
                imageTestState = .failure(friendlyError(error))
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

    private func friendlyError(_ error: Error) -> String {
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            switch nsError.code {
            case NSURLErrorNotConnectedToInternet: return "无网络连接"
            case NSURLErrorTimedOut: return "连接超时"
            case NSURLErrorCannotFindHost: return "无法找到服务器"
            default: return "网络错误：\(nsError.localizedDescription)"
            }
        }
        return error.localizedDescription
    }
}
