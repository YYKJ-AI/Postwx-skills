import SwiftUI

struct PersonaLibraryEditorView: View {
    @Environment(\.dismiss) private var dismiss
    var library = PersonaLibrary.shared
    var state: AppState?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Spacer()
                HStack(spacing: 8) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 7)
                            .fill(LinearGradient(
                                colors: [Color(hex: 0xF59E0B), Color(hex: 0xD97706)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ))
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
                Button { dismiss() } label: {
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

            Divider().opacity(0.3)

            HStack {
                Button {
                    library.addPersona(PersonaItem(
                        id: UUID().uuidString.lowercased(),
                        displayName: "新人设",
                        prompt: ""
                    ))
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .bold))
                        Text("添加人设")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundStyle(Color(hex: 0xF59E0B))
                }
                .buttonStyle(.plain)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .frame(width: 420, height: 460)
        .background(Color(nsColor: .windowBackgroundColor))
    }

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
    }

    private func personaRow(_ item: PersonaItem) -> some View {
        let isActive = item.id == currentPersonaId

        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                // 选中指示器
                Button { selectPersona(item.id) } label: {
                    Image(systemName: isActive ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 18))
                        .foregroundStyle(isActive ? AnyShapeStyle(Color(hex: 0xF59E0B)) : AnyShapeStyle(.tertiary))
                }
                .buttonStyle(.plain)

                TextField("名称", text: Binding(
                    get: { item.displayName },
                    set: { var u = item; u.displayName = $0; library.updatePersona(u) }
                ))
                .textFieldStyle(.plain)
                .font(.system(size: 15, weight: .semibold))

                if item.isBuiltIn {
                    Text("内置")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.primary.opacity(0.06), in: Capsule())
                } else {
                    Button { library.deletePersona(id: item.id) } label: {
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
                .fill(isActive ? Color(hex: 0xF59E0B).opacity(0.06) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isActive ? Color(hex: 0xF59E0B).opacity(0.2) : Color.primary.opacity(0.04), lineWidth: 1)
        )
    }
}
