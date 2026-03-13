import Foundation
import SwiftUI

@Observable
@MainActor
final class ProfileManager {
    static let shared = ProfileManager()

    var profiles: [AccountProfile] = []
    var currentProfileId: UUID?

    var currentProfile: AccountProfile? {
        get { profiles.first { $0.id == currentProfileId } }
        set {
            guard let newValue, let idx = profiles.firstIndex(where: { $0.id == newValue.id }) else { return }
            profiles[idx] = newValue
        }
    }

    private let fileURL: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Postwx", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("profiles.json")
    }()

    private init() {
        load()
        migrateFromUserDefaultsIfNeeded()
    }

    // MARK: - CRUD

    func addProfile(_ profile: AccountProfile) {
        profiles.append(profile)
        if currentProfileId == nil {
            currentProfileId = profile.id
        }
        save()
    }

    func deleteProfile(id: UUID) {
        profiles.removeAll { $0.id == id }
        if currentProfileId == id {
            currentProfileId = profiles.first?.id
        }
        save()
    }

    func switchProfile(id: UUID) {
        guard profiles.contains(where: { $0.id == id }) else { return }
        currentProfileId = id
        UserDefaults.standard.set(id.uuidString, forKey: "currentProfileId")
    }

    func applyProfile(id: UUID, to state: AppState) {
        guard let p = profiles.first(where: { $0.id == id }) else { return }
        state.wechatAppId = p.wechatAppId
        state.wechatAppSecret = p.wechatAppSecret
        state.username = p.username
        state.defaultAuthor = p.defaultAuthor
        state.needOpenComment = p.needOpenComment
        state.onlyFansCanComment = p.onlyFansCanComment

        let d = UserDefaults.standard
        state.imageApiBase = d.string(forKey: "imageApiBase") ?? ""
        state.imageApiKey = d.string(forKey: "imageApiKey") ?? ""
        state.imageModel = d.string(forKey: "imageModel") ?? ""

        state.personaId = p.personaId

        let fallbackAuthor = p.defaultAuthor.isEmpty ? p.username : p.defaultAuthor
        if state.author.isEmpty || state.author != fallbackAuthor {
            state.author = fallbackAuthor
        }
    }

    func applyToState(_ state: AppState) {
        guard let p = currentProfile else { return }
        state.wechatAppId = p.wechatAppId
        state.wechatAppSecret = p.wechatAppSecret
        state.username = p.username
        state.defaultAuthor = p.defaultAuthor
        state.needOpenComment = p.needOpenComment
        state.onlyFansCanComment = p.onlyFansCanComment

        let d = UserDefaults.standard
        state.imageApiBase = d.string(forKey: "imageApiBase") ?? ""
        state.imageApiKey = d.string(forKey: "imageApiKey") ?? ""
        state.imageModel = d.string(forKey: "imageModel") ?? ""

        state.personaId = p.personaId

        let fallbackAuthor = p.defaultAuthor.isEmpty ? p.username : p.defaultAuthor
        if state.author.isEmpty || state.author != fallbackAuthor {
            state.author = fallbackAuthor
        }
    }

    func updateCurrentProfile(from state: AppState) {
        guard var p = currentProfile else { return }
        p.wechatAppId = state.wechatAppId
        p.wechatAppSecret = state.wechatAppSecret
        p.username = state.username
        p.defaultAuthor = state.defaultAuthor
        p.personaId = state.personaId
        p.needOpenComment = state.needOpenComment
        p.onlyFansCanComment = state.onlyFansCanComment
        currentProfile = p
        save()
    }

    // MARK: - Persistence

    func save() {
        do {
            let data = try JSONEncoder().encode(profiles)
            try data.write(to: fileURL, options: .atomic)
            if let id = currentProfileId {
                UserDefaults.standard.set(id.uuidString, forKey: "currentProfileId")
            }
        } catch {
            print("ProfileManager save error: \(error)")
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([AccountProfile].self, from: data) else { return }
        profiles = decoded
        if let idStr = UserDefaults.standard.string(forKey: "currentProfileId"),
           let id = UUID(uuidString: idStr),
           profiles.contains(where: { $0.id == id }) {
            currentProfileId = id
        } else {
            currentProfileId = profiles.first?.id
        }
    }

    // MARK: - Migration

    private func migrateFromUserDefaultsIfNeeded() {
        guard profiles.isEmpty else { return }
        let d = UserDefaults.standard

        let appId = d.string(forKey: "wechatAppId") ?? ""
        let appSecret = d.string(forKey: "wechatAppSecret") ?? ""

        guard !appId.isEmpty || !appSecret.isEmpty else { return }

        var profile = AccountProfile()
        profile.name = d.string(forKey: "username") ?? "默认账号"
        if profile.name.isEmpty { profile.name = "默认账号" }
        profile.wechatAppId = appId
        profile.wechatAppSecret = appSecret
        profile.username = d.string(forKey: "username") ?? ""
        profile.defaultAuthor = d.string(forKey: "defaultAuthor") ?? ""
        profile.personaId = d.string(forKey: "creatorRole") ?? "tech-blogger"
        profile.needOpenComment = d.object(forKey: "needOpenComment") as? Bool ?? true
        profile.onlyFansCanComment = d.object(forKey: "onlyFansCanComment") as? Bool ?? false

        addProfile(profile)
    }
}
