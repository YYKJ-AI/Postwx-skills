import Foundation

struct AccountProfile: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var name: String = "默认账号"

    // MARK: - 凭证

    var wechatAppId: String = ""
    var wechatAppSecret: String = ""

    // MARK: - 偏好

    var username: String = ""
    var defaultAuthor: String = ""
    var personaId: String = "tech-blogger"
    var needOpenComment: Bool = true
    var onlyFansCanComment: Bool = false
}
