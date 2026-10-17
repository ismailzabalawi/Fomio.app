import Foundation

/// `site.json` flag catalogs and policy paths. Contract recorded in docs/discourse-api-reference.md (2026-10-17).
struct SafetyCatalogDTO: Decodable, Sendable {
    struct ActionType: Decodable, Sendable {
        var id: Int; var nameKey: String?; var name: String?; var description: String?; var shortDescription: String?
        var isFlag: Bool?; var enabled: Bool?; var requireMessage: Bool?; var appliesTo: [String]?
    }
    var postActionTypes: [ActionType]?
    var topicFlagTypes: [ActionType]?
    var tosUrl: String?
    var privacyPolicyUrl: String?
    /// Moderator-report reasons only. `notify_user` messages the author and is never offered as a report.
    static func reasons(_ types: [ActionType], appliesTo kind: String) -> [ActionType] {
        types.filter { $0.isFlag == true && $0.enabled != false && $0.nameKey != "notify_user" && ($0.appliesTo?.contains(kind) ?? true) }
    }
    static func reason(_ type: ActionType) -> ReportReason {
        let description = HTMLContent.plainText(type.description ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let short = HTMLContent.plainText(type.shortDescription ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return ReportReason(id: type.id, name: HTMLContent.plainText(type.name ?? ""), description: description.isEmpty ? short : description, requiresMessage: type.requireMessage == true)
    }
}

extension DiscourseService {
    private func catalog() async throws -> SafetyCatalogDTO {
        if let safetyCatalog { return safetyCatalog }
        let value = try await api.get(SafetyCatalogDTO.self, "site.json")
        safetyCatalog = value; return value
    }
    private func freshPost(_ id: PostID) async throws -> PostDTO {
        try await api.get(PostDTO.self, "posts/\(id.rawValue).json", member: true)
    }
    private func flagIDs(_ catalog: SafetyCatalogDTO) -> Set<Int> {
        Set(((catalog.postActionTypes ?? []) + (catalog.topicFlagTypes ?? [])).filter { $0.isFlag == true && $0.nameKey != "notify_user" }.map(\.id))
    }
    func reportContext(_ target: ReportTarget) async throws -> ReportContext {
        let catalog = try await catalog()
        // Always recheck the exact target: tree payloads blank ignored replies' actions, and permissions change after sign-in.
        let dto = try await freshPost(target.actionPostID)
        let post = dto.domain(canReply: false)
        let types: [SafetyCatalogDTO.ActionType]
        if case .discussion = target { types = SafetyCatalogDTO.reasons(catalog.topicFlagTypes ?? [], appliesTo: "Topic") }
        else { types = SafetyCatalogDTO.reasons(catalog.postActionTypes ?? [], appliesTo: "Post") }
        let allowed = Set(post.flags.filter(\.canAct).map(\.id))
        let flags = flagIDs(catalog)
        let excerpt = String(post.body.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression).trimmingCharacters(in: .whitespaces).prefix(170))
        return ReportContext(target: target, excerpt: excerpt, reasons: types.filter { allowed.contains($0.id) }.map(SafetyCatalogDTO.reason), alreadyReported: post.flags.contains { $0.acted && flags.contains($0.id) })
    }
    func submitReport(_ target: ReportTarget, reason: ReportReason, message: String?) async throws -> ReportSubmission {
        var payload: [String: Any] = ["post_action_type_id": reason.id]
        switch target {
        case let .post(id, _, _, _): payload["id"] = id.rawValue
        case let .discussion(topic, _, _): payload["id"] = topic.rawValue; payload["flag_topic"] = "true"
        }
        if let message, !message.isEmpty { payload["message"] = message }
        let data: Data
        do { data = try await api.json("post_actions.json", payload: payload) }
        catch RepositoryError.unconfirmed { return .unconfirmed }
        catch let RepositoryError.server(code) where code >= 500 { _ = code; return .unconfirmed }
        // Success renders the reloaded post. A malformed 2xx stays uncertain; it is never treated as a validation error.
        guard (try? api.decode(PostDTO.self, from: data)) != nil else { return .unconfirmed }
        return .received
    }
    func reportStatus(_ target: ReportTarget) async throws -> ReportStatusCheck {
        let catalog = try await catalog()
        let post = try await freshPost(target.actionPostID).domain(canReply: false)
        let flags = flagIDs(catalog)
        return post.flags.contains { $0.acted && flags.contains($0.id) } ? .received : .notReceived
    }
    func accountSafety() async throws -> AccountSafety {
        struct Envelope: Decodable { struct User: Decodable { var canIgnoreUsers: Bool?; var ignoredUsers: [String]? }; var currentUser: User }
        let value = try await api.get(Envelope.self, "session/current.json", member: true)
        return AccountSafety(canIgnoreUsers: value.currentUser.canIgnoreUsers == true, ignored: Set(value.currentUser.ignoredUsers ?? []))
    }
    func memberSafety(_ username: String) async throws -> MemberSafety {
        struct Envelope: Decodable { struct User: Decodable { var username: String; var ignored: Bool?; var canIgnoreUser: Bool?; var admin: Bool?; var moderator: Bool? }; var user: User }
        let value = try await api.get(Envelope.self, "u/\(username)/card.json").user
        return MemberSafety(username: value.username, ignored: value.ignored == true, canIgnore: value.canIgnoreUser == true, staff: value.admin == true || value.moderator == true)
    }
    func ignore(_ username: String, until: Date) async throws -> PreferenceWrite {
        // Self-service only: never send acting_user_id. Denials arrive as 422 `ignore_error`.
        try await preference(username, payload: ["notification_level": "ignore", "expiring_at": ISO8601DateFormatter().string(from: until)])
    }
    func stopIgnoring(_ username: String) async throws -> PreferenceWrite {
        try await preference(username, payload: ["notification_level": "normal"])
    }
    private func preference(_ username: String, payload: [String: Any]) async throws -> PreferenceWrite {
        do { _ = try await api.json("u/\(username)/notification_level.json", method: "PUT", payload: payload); return .confirmed }
        catch RepositoryError.unconfirmed { return .unconfirmed }
        catch let RepositoryError.server(code) where code >= 500 { _ = code; return .unconfirmed }
    }
    func revealPost(_ id: PostID) async throws -> Post { try await freshPost(id).domain(canReply: false) }
    func safetyResources() async throws -> SafetyResources {
        let catalog = try await catalog()
        struct About: Decodable { struct Info: Decodable { var contactEmail: String? }; var about: Info }
        let about = try? await api.get(About.self, "about.json")
        let base = api.configuration?.baseURL
        func link(_ path: String?) -> URL? { PublicMedia.url(path, base: base) }
        let email = about?.about.contactEmail?.trimmingCharacters(in: .whitespaces)
        return SafetyResources(guidelines: link("/guidelines"), terms: link(catalog.tosUrl), privacy: link(catalog.privacyPolicyUrl), contactEmail: email.flatMap { SafetyResources.validEmail($0) ? $0 : nil })
    }
}

extension SafetyResources {
    static func validEmail(_ value: String) -> Bool {
        value.range(of: "^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", options: .regularExpression) != nil
    }
}
