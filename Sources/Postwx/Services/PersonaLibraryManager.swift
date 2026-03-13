import Foundation

@Observable
@MainActor
final class PersonaLibrary {
    static let shared = PersonaLibrary()

    var data = PersonaLibraryData()

    private let fileURL: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Postwx", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("persona-library.json")
    }()

    private init() {
        load()
        if data.personas.isEmpty { seedDefaults() }
    }

    // MARK: - Lookup

    func persona(id: String) -> PersonaItem? { data.personas.first { $0.id == id } }
    func imageStyle(id: String) -> ImageStyleItem? { data.imageStyles.first { $0.id == id } }

    // MARK: - CRUD Personas

    func addPersona(_ item: PersonaItem) { data.personas.append(item); save() }
    func updatePersona(_ item: PersonaItem) {
        guard let idx = data.personas.firstIndex(where: { $0.id == item.id }) else { return }
        data.personas[idx] = item; save()
    }
    func deletePersona(id: String) {
        guard data.personas.first(where: { $0.id == id })?.isBuiltIn != true else { return }
        data.personas.removeAll { $0.id == id }; save()
    }

    // MARK: - CRUD Image Styles

    func addImageStyle(_ item: ImageStyleItem) { data.imageStyles.append(item); save() }
    func updateImageStyle(_ item: ImageStyleItem) {
        guard let idx = data.imageStyles.firstIndex(where: { $0.id == item.id }) else { return }
        data.imageStyles[idx] = item; save()
    }
    func deleteImageStyle(id: String) {
        guard data.imageStyles.first(where: { $0.id == id })?.isBuiltIn != true else { return }
        data.imageStyles.removeAll { $0.id == id }; save()
    }

    // MARK: - Persistence

    func save() {
        do {
            let data = try JSONEncoder().encode(self.data)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("PersonaLibrary save error: \(error)")
        }
    }

    private func load() {
        guard let raw = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode(PersonaLibraryData.self, from: raw)
        else { return }
        data = decoded
    }

    // MARK: - Seed Defaults

    private func seedDefaults() {
        data.personas = [
            PersonaItem(id: "tech-blogger", displayName: "技术博主",
                        prompt: "技术术语保留，加入实用性观点，结构清晰，代码示例规范。严谨用词，逻辑清晰，通俗易懂，多用类比。", isBuiltIn: true),
        ]
        data.imageStyles = [
            ImageStyleItem(id: "vector", displayName: "矢量插画",
                           useCase: "技术文章、教程、知识科普",
                           colorPalette: "Cream底#F5F0E6, Coral#E07A5F, Mint#81B29A, Mustard#F2CC8F", isBuiltIn: true),
            ImageStyleItem(id: "watercolor", displayName: "水彩风",
                           useCase: "生活方式、旅行、情感散文",
                           colorPalette: "Earth色系, 柔和边缘", isBuiltIn: true),
            ImageStyleItem(id: "minimal", displayName: "极简线条",
                           useCase: "观点文章、深度思考",
                           colorPalette: "黑白#000/#374151, 白底, 60%+留白", isBuiltIn: true),
            ImageStyleItem(id: "warm", displayName: "暖色调",
                           useCase: "个人故事、成长感悟",
                           colorPalette: "Cream底#FFFAF0, Orange#ED8936, Golden#F6AD55", isBuiltIn: true),
            ImageStyleItem(id: "blueprint", displayName: "蓝图风",
                           useCase: "API文档、系统设计",
                           colorPalette: "Off-White底#FAF8F5, Blue#2563EB, Navy", isBuiltIn: true),
            ImageStyleItem(id: "notion", displayName: "Notion风",
                           useCase: "产品指南、工具教程",
                           colorPalette: "白底, 黑#1A1A1A, 淡蓝/淡黄/淡粉点缀", isBuiltIn: true),
        ]
        save()
    }
}
