import Foundation

struct PersonaItem: Codable, Identifiable, Equatable {
    var id: String
    var displayName: String
    var prompt: String
    var isBuiltIn: Bool = false
}

struct ImageStyleItem: Codable, Identifiable, Equatable {
    var id: String
    var displayName: String
    var useCase: String
    var colorPalette: String
    var isBuiltIn: Bool = false
}

struct PersonaLibraryData: Codable {
    var personas: [PersonaItem] = []
    var imageStyles: [ImageStyleItem] = []
}
