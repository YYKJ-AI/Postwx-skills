import SwiftUI

struct PersonaLibraryEditorView: View {
    @Environment(\.dismiss) private var dismiss
    var library = PersonaLibrary.shared
    var state: AppState?
    var onDismiss: (() -> Void)?

    // 品牌色 — 与主界面一致
    private let brandGreen = Color(hex: 0x07C160)
    private let brandGradient = LinearGradient(
        colors: [Color(hex: 0x07C160), Color(hex: 0x06AD56)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    // 防止自动聚焦 TextField
    @FocusState private var focusedField: String?

    // Toast 反馈
    @State private var toastMessage = ""
    @State private var toastStyle: ToastStyle = .success
    @State private var showToast = false

    private enum ToastStyle {
        case success, error
        var color: Color {
            switch self {
            case .success: Color(hex: 0x10B981)
            case .error: Color(hex: 0xEF4444)
            }
        }
        var icon: String {
            switch self {
            case .success: "checkmark.circle.fill"
            case .error: "xmark.circle.fill"
            }
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Spacer()
                    HStack(spacing: 8) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 7)
                                .fill(brandGradient)
                                .frame(width: 26, height: 26)
                            Image(systemName: "person.text.rectangle.fill")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        Text("人设库")
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

                Rectangle().fill(Color.primary.opacity(0.06)).frame(height: 0.5)

                // 人设列表
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(library.data.personas) { item in
                            personaRow(item)
                        }
                    }
                    .padding(16)
                }

                Rectangle().fill(Color.primary.opacity(0.06)).frame(height: 0.5)

                // 添加按钮 — 更大更醒目
                Button {
                    addPersona()
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 16, weight: .semibold))
                        Text("添加人设")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(brandGradient, in: RoundedRectangle(cornerRadius: 10))
                    .shadow(color: brandGreen.opacity(0.2), radius: 8, y: 3)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }

            // Toast 反馈
            if showToast {
                toastView
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(100)
            }
        }
        .frame(width: 420, height: 460)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Toast View

    private var toastView: some View {
        HStack(spacing: 8) {
            Image(systemName: toastStyle.icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(toastStyle.color)
            Text(toastMessage)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.1), radius: 12, y: 4)
        )
        .overlay(Capsule().stroke(toastStyle.color.opacity(0.2), lineWidth: 1))
        .padding(.top, 60)
    }

    private func showFeedback(_ message: String, style: ToastStyle) {
        toastMessage = message
        toastStyle = style
        withAnimation(.spring(duration: 0.35)) { showToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            withAnimation(.easeOut(duration: 0.25)) { showToast = false }
        }
    }

    // MARK: - Actions

    private func addPersona() {
        let newItem = PersonaItem(
            id: UUID().uuidString.lowercased(),
            displayName: "新人设",
            prompt: ""
        )
        library.addPersona(newItem)
        showFeedback("人设已添加", style: .success)
    }

    private func deletePersona(_ item: PersonaItem) {
        if item.isBuiltIn {
            showFeedback("内置人设无法删除", style: .error)
            return
        }
        library.deletePersona(id: item.id)
        showFeedback("「\(item.displayName)」已删除", style: .success)
    }

    // MARK: - Helpers

    private var currentPersonaId: String {
        state?.personaId ?? ProfileManager.shared.currentProfile?.personaId ?? "tech-blogger"
    }

    private func selectPersona(_ id: String) {
        state?.personaId = id
        if var p = ProfileManager.shared.currentProfile {
            p.personaId = id
            ProfileManager.shared.currentProfile = p
            ProfileManager.shared.save()
        }
        showFeedback("已切换人设", style: .success)
    }

    // MARK: - Persona Row

    private func personaRow(_ item: PersonaItem) -> some View {
        let isActive = item.id == currentPersonaId

        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                // 选中指示器
                Button { selectPersona(item.id) } label: {
                    Image(systemName: isActive ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 18))
                        .foregroundStyle(isActive ? AnyShapeStyle(brandGreen) : AnyShapeStyle(.tertiary))
                }
                .buttonStyle(.plain)

                TextField("名称", text: Binding(
                    get: { item.displayName },
                    set: { var u = item; u.displayName = $0; library.updatePersona(u) }
                ))
                .textFieldStyle(.plain)
                .font(.system(size: 15, weight: .semibold))
                .focused($focusedField, equals: "name-\(item.id)")

                if item.isBuiltIn {
                    Text("内置")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.primary.opacity(0.06), in: Capsule())
                } else {
                    Button { deletePersona(item) } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 13))
                            .foregroundStyle(.red.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                }
            }

            TextField("提示词，如：技术术语保留，结构清晰，代码示例规范…", text: Binding(
                get: { item.prompt },
                set: { var u = item; u.prompt = $0; library.updatePersona(u) }
            ), axis: .vertical)
            .textFieldStyle(.plain)
            .font(.system(size: 13))
            .foregroundStyle(.secondary)
            .lineLimit(2...5)
            .focused($focusedField, equals: "prompt-\(item.id)")
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(nsColor: .textBackgroundColor))
            )
            .padding(.leading, 24)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isActive ? brandGreen.opacity(0.06) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isActive ? brandGreen.opacity(0.25) : Color.primary.opacity(0.04), lineWidth: 1)
        )
    }
}
