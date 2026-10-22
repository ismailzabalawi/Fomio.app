import Foundation

extension DiscourseService {
    private struct SessionEnvelope: Decodable {
        struct User: Decodable {
            let username: String
            let canIgnoreUsers: Bool?
            let ignoredUsers: [String]
        }
        let currentUser: User
    }
    func safetySession() async throws -> SafetySession {
        let user = try await api.get(SessionEnvelope.self, "session/current.json", member: true).currentUser
        return SafetySession(username: user.username, canIgnoreUsers: user.canIgnoreUsers == true, ignoredUsers: user.ignoredUsers)
    }
    func reportReasons(post: Post) async throws -> [ReportReason] {
        struct Site: Decodable {
            struct Reason: Decodable {
                let id: Int
                let name: String
                let nameKey: String
                let shortDescription: String?
                let isFlag: Bool?
                let enabled: Bool?
                let appliesTo: [String]?
                let requireMessage: Bool?
            }
            let postActionTypes: [Reason]
        }
        let site = try await api.get(Site.self, "site.json", member: true)
        let current = try await api.get(PostDTO.self, "posts/\(post.id.rawValue).json", member: true)
        guard current.id == post.id.rawValue else { throw RepositoryError.unavailable }
        let allowed = Set((current.actionsSummary ?? []).filter { $0.canAct == true && $0.acted != true }.map(\.id))
        return site.postActionTypes.filter {
            $0.isFlag == true && $0.enabled == true && $0.nameKey != "notify_user"
                && $0.appliesTo?.contains("Post") == true && allowed.contains($0.id)
        }.map { ReportReason(id: $0.id, title: HTMLContent.plainText($0.name), description: HTMLContent.plainText($0.shortDescription ?? ""), requiresMessage: $0.requireMessage == true) }
    }
    func report(post: Post, reason: Int, message: String) async throws {
        // Dynamic flag IDs and fresh post permissions are authoritative, including custom flags.
        guard let option = try await reportReasons(post: post).first(where: { $0.id == reason }) else { throw RepositoryError.denied }
        if option.requiresMessage && message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw RepositoryError.invalid("Describe why you are reporting this post.")
        }
        let data = try await api.json("post_actions.json", payload: ["id": post.id.rawValue, "post_action_type_id": reason, "flag_topic": false, "message": message])
        guard let result = try? api.decode(PostDTO.self, from: data), result.id == post.id.rawValue,
              result.actionsSummary?.contains(where: { $0.id == reason && $0.acted == true }) == true else { throw RepositoryError.unconfirmed }
    }
    func setIgnored(username: String, ignored: Bool) async throws -> SafetySession {
        let before = try await safetySession()
        guard before.username.caseInsensitiveCompare(username) != .orderedSame else { throw RepositoryError.denied }
        guard !ignored || before.canIgnoreUsers else { throw RepositoryError.denied }
        var payload: [String: Any] = ["notification_level": ignored ? "ignore" : "normal"]
        // Match Discourse's own Forever shortcut (time-shortcut.js): one thousand years.
        if ignored {
            guard let expiry = Calendar(identifier: .gregorian).date(byAdding: .year, value: 1000, to: Date()) else { throw RepositoryError.unavailable }
            payload["expiring_at"] = ISO8601DateFormatter().string(from: expiry)
        }
        let data = try await api.json("u/\(username)/notification_level.json", method: "PUT", payload: payload)
        struct Result: Decodable { let success: String }
        guard (try? api.decode(Result.self, from: data).success) == "OK" else { throw RepositoryError.unconfirmed }
        let after: SafetySession
        do { after = try await safetySession() } catch { throw RepositoryError.unconfirmed }
        guard before.username == after.username,
              after.ignoredUsers.contains(where: { $0.caseInsensitiveCompare(username) == .orderedSame }) == ignored else { throw RepositoryError.unconfirmed }
        return after
    }
}
