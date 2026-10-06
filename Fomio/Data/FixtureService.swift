import Foundation
import Observation

/// Fictional development data matching the 2026-10-03 MVP mockup seed. Nothing here describes a real community.
@MainActor @Observable final class FixtureService: CommunityService {
    enum Scenario: String, CaseIterable { case published, pending, rejected, expired, unconfirmed }
    var scenario: Scenario = .published
    var offline = false
    var uploadFails = false
    var nestedEnabled = true
    /// Development-only latency for showing the loading state.
    var feedDelay: Duration = .zero
    var uploadStep: Duration = .milliseconds(100)
    var bookmarks: [PostID: Int] = [PostID(418201): 1, PostID(419014): 2]
    var readNotices: Set<Int> = [3]
    var submitted: [UUID: (TopicID, PostNumber)] = [:]
    var posts: [TopicID: [Post]] = [:]
    var summaries: [DiscussionSummary] = []
    static let member = "jonah.w"
    static let sampleCommunities: [Community] = {
        let categories: [Community] = [
        .init(id: .init(1), name: "Woodworking", slug: "woodworking", description: "Furniture, tools and techniques. Show your builds and ask for help.", canCreate: true),
        .init(id: .init(4), name: "Hand Tools", slug: "hand-tools", parentID: .init(1), description: "Planes, saws, chisels and keeping them sharp.", canCreate: true),
        .init(id: .init(2), name: "Finishing", slug: "finishing", parentID: .init(1), description: "Stains, oils, film finishes and fixing blotchy results.", canCreate: true),
        .init(id: .init(3), name: "Joinery", slug: "joinery", parentID: .init(1), description: "Mortise and tenon, dovetails and everything that holds furniture together.", canCreate: true),
        .init(id: .init(9), name: "Turning", slug: "turning", parentID: .init(1), description: "Lathe work, from bowls to pens.", canCreate: true),
        .init(id: .init(5), name: "Electronics", slug: "electronics", description: "Repairs, microcontrollers and test gear.", canCreate: true),
        .init(id: .init(6), name: "Repairs", slug: "repairs", parentID: .init(5), description: "Fixing what broke, and finding out why.", canCreate: true),
        .init(id: .init(7), name: "Microcontrollers", slug: "microcontrollers", parentID: .init(5), description: "Boards, firmware and power budgets.", canCreate: true),
        .init(id: .init(8), name: "Gardening", slug: "gardening", description: "Growing food and flowers.", canCreate: true),
        .init(id: .init(10), name: "Makers Council", slug: "makers-council", description: "Restricted community", canCreate: false, restricted: true)
    ]
    return categories.map { category in
        var category = category
        let colors = [1: "3E8561", 4: "A56B43", 2: "BC704A", 3: "7464BC", 9: "478C94", 5: "4679B3", 6: "99637D", 7: "3F9490", 8: "719546", 10: "73718A"]
        let icons = [1: "hammer", 4: "wrench", 2: "paintbrush", 5: "microchip", 6: "screwdriver-wrench", 8: "seedling"]
        category.identity = CategoryIdentity(color: colors[category.id.rawValue], style: icons[category.id.rawValue] == nil ? "square" : "icon", icon: icons[category.id.rawValue])
        return category
    }
    }()
    func siteTheme() async throws -> SiteTheme {
        if ProcessInfo.processInfo.arguments.contains("--teal-theme") {
            return SiteTheme(light: ["primary": "182A2A", "secondary": "FFFFFF", "tertiary": "147A74"], dark: ["primary": "E3F0EF", "secondary": "081615", "tertiary": "73D4C9"])
        }
        return SiteTheme()
    }
    static let people: [String: (name: String, joined: String, bio: String)] = [
        "jonah.w": ("Jonah Wells", "Mar 2024", "Weekend furniture maker in a one-car garage. Mostly walnut and oak, hand tools where I can."),
        "margaux.delacroix-whitfield": ("Margaux Delacroix-Whitfield", "2025", "Learning furniture making on weekends, mostly with reclaimed timber."),
        "mara_k": ("Mara K.", "2021", "Restoring mid-century pieces, one veneer patch at a time."),
        "devon": ("Devon Price", "2022", "Bench repairs and vintage test gear."),
        "priya": ("Priya S.", "2023", "Low-power firmware, mostly sensors that run on a coin cell."),
        "ines.r": ("Inês R.", "2020", "Balcony fruit trees in a cold climate."),
        "theo": ("Theo M.", "2022", ""), "sunil.p": ("Sunil P.", "2021", ""), "alex.h": ("Alex H.", "2024", "")
    ]
    private typealias Seed = (author: String, age: String, body: String, likes: Int, image: String?)
    private static func p(_ author: String, _ age: String, _ body: String, _ likes: Int = 0, _ image: String? = nil) -> Seed { (author, age, body, likes, image) }
    private static let seed: [(id: Int, category: Int, activity: String, title: String, posts: [Seed])] = [
        (4190, 6, "2m", "Bench PSU hums after a fuse swap", [
            p("devon", "5h", "Replaced the 2A fuse with the same rating, and now there’s a 50 Hz hum from the transformer side. Output voltage looks normal on the meter. Anything I should check before I open it up again?", 3),
            p("priya", "5h", "Is it the same fuse type? A slow-blow and a fast-blow can look identical.", 1),
            p("devon", "5h", "Same type, T2A, from the same bag as the original spare."),
            p("alex.h", "4h", "A hum at 50 Hz rather than 100 Hz usually points at the transformer, not the rectifier.", 2),
            p("theo", "4h", "Could be a loose lamination. Does pressing on the transformer case change it?"),
            p("devon", "4h", "Pressing on it does nothing. It’s quieter with no load."),
            p("ines.r", "3h", "Mine did that when a mounting screw had backed out."),
            p("devon", "3h", "Screws are tight. I’ll scope the output tonight."),
            p("priya", "2h", "Post the ripple if you can. Scope at the output, AC coupled.", 1),
            p("devon", "1h", "About 40 mV of ripple at 1 A, AC coupled at 10 mV per division. That seems high for a linear supply. Photo of the bench scope I’m using attached.", 0, "ph-scope"),
            p("alex.h", "1h", "That’s high for this unit. The spec sheet says under 5 mV."),
            p("sunil.p", "40m", "Check the main filter cap too. They dry out on older units.", 2),
            p("jonah.w", "20m", "If the ripple went up at the same time as the hum, I’d test the bridge rectifier before the caps.", 4),
            p("devon", "5m", "You were right. One diode in the bridge rectifier reads open, and a cracked diode hums exactly like that.", 2),
            p("theo", "2m", "Good find. Replace the whole bridge, they’re cheap.")]),
        (4182, 2, "10m", "Oil vs. hardwax on a walnut desk top?", [
            p("mara_k", "2h", "Sanded to 220. It’s a daily desk: coffee mugs and a laptop. Rubbing oil looks great, but I’m worried about rings. Would hardwax oil hold up better, or should I go straight to a film finish?", 12, "ph-walnut"),
            p("devon", "1h", "Hardwax oil is easier to spot-repair. Two thin coats, buff off the excess, and give it a full week before the mugs come back.", 4),
            p("ines.r", "40m", "Test both on an offcut from the same board. Walnut can go darker under oil than you expect.", 2),
            p("sunil.p", "30m", "If the laptop always sits in one place, a film finish resists the heat better. Hardwax will dull there eventually.", 1),
            p("theo", "10m", "Whatever you pick, try it on the underside first.", 3)]),
        (4199, 1, "25m", "Built a standing desk from reclaimed oak flooring and the top has cupped about 3 mm across the width since spring. Can I still flatten it without taking it apart?", [
            p("margaux.delacroix-whitfield", "3h", "The boards were glued edge to edge with the growth rings all facing the same way, which I now realise was a mistake. The cup is worst on the window side. Finish is two coats of water-based poly on the top only, nothing underneath.", 5),
            p("sunil.p", "2h", "Finishing only one face is probably most of it. The bare underside takes on moisture faster than the top.", 3),
            p("alex.h", "1h", "Seal the underside and give it a few weeks before you plane anything.", 1)]),
        (4201, 7, "1h", "Deep sleep current on a dev board: 40 mA?", [
            p("priya", "3h", "My board draws 40 mA in deep sleep. The datasheet says microamps. Is the USB-serial chip the culprit, or am I measuring wrong?", 4),
            p("alex.h", "3h", "Most dev boards keep the USB bridge and the power LED on. Try powering it from the 3.3 V pin.", 2),
            p("priya", "2h", "From the 3.3 V pin it drops to 9 mA. Better, still not microamps."),
            p("devon", "2h", "The regulator’s quiescent current might be most of that."),
            p("theo", "1h", "Check whether any GPIO is left driving a pull-up."),
            p("priya", "1h", "@jonah.w you measured this on the same board last year, didn’t you? What did you get?")]),
        (4195, 3, "4h", "First drawbored mortise and tenon", [
            p("alex.h", "4h", "Offset the peg hole by about 1.5 mm and it pulled the shoulder tight without clamps. Oak peg, riven, not dowel stock.", 9),
            p("mara_k", "3h", "That’s a clean shoulder. Did you taper the peg tip?", 1),
            p("alex.h", "3h", "Yes, a short taper with a knife. Without it the peg split on the first test.")]),
        (4188, 2, "6h", "Blotchy cherry: can gel stain save it?", [
            p("theo", "6h", "First cherry project, and the oil stain went on blotchy. Can I sand back and use a gel stain, or is it too late?", 2),
            p("sunil.p", "5h", "Sand back to bare wood, then a thin washcoat of dewaxed shellac before the gel. It evens out the absorption.", 5)]),
        (4176, 4, "1d", "Low-angle jack or a No. 5 for a first plane?", [
            p("mara_k", "1d", "Setting up a small shop and I can only buy one bench plane this year. Which one would you start with?", 6),
            p("devon", "1d", "A No. 5. It does a bit of everything and teaches you how to set a chipbreaker.", 3)]),
        (4170, 8, "1d", "Overwintering a fig in a large container", [
            p("ines.r", "1d", "This is the fig in summer. My garage stays around 2°C in winter. Should I wrap the container and leave it there, or bring it inside?", 31, "ph-fig"),
            p("theo", "1d", "Leave it in the garage. Indoors it’ll wake up too early.", 4),
            p("sunil.p", "20h", "Water it lightly once a month so the roots don’t dry out completely.", 2)]),
        (4160, 2, "2d", "Dewaxed shellac under water-based poly", [
            p("sunil.p", "2d", "Does it have to be dewaxed, or will regular shellac work as a sealer under water-based poly?", 3),
            p("mara_k", "2d", "Dewaxed. Regular shellac can cause adhesion problems with water-based topcoats.", 4)])
    ]
    /// Nested replies are the approved native adaptation; the mockup draws them chronologically.
    private static func parent(topic: Int, number: Int) -> PostNumber? {
        guard topic == 4190 else { return nil }
        switch number { case 3...6: return .init(number - 1); case 14: return .init(13); case 15: return .init(14); default: return nil }
    }
    init() {
        for item in Self.seed {
            let topic = TopicID(item.id)
            posts[topic] = item.posts.enumerated().map { index, seed in
                let number = index + 1
                return Post(id: .init(item.id * 100 + number), number: .init(number), topicID: topic, parent: number == 1 ? nil : Self.parent(topic: item.id, number: number),
                            author: seed.author, body: seed.body, image: seed.image, likeCount: seed.likes, canLike: seed.author != Self.member, canReply: true,
                            age: seed.age, authorName: Self.people[seed.author]?.name)
            }
            let opening = item.posts[0]
            summaries.append(DiscussionSummary(id: topic, title: item.title, slug: "topic-\(item.id)", categoryID: .init(item.category), excerpt: opening.body, author: opening.author, replyCount: item.posts.count - 1, activity: item.activity, image: opening.image))
        }
    }
    static func sampleDrafts(account: AccountID) -> [Draft] {
        var reply = Draft(account: account, intent: .reply(topic: .init(4170), parent: .init(1)), body: "Mine survived at 0°C wrapped in burlap, but I brought it in when it dropped below −5°C.")
        reply.contextTitle = "Overwintering a fig in a large container"; reply.contextCategory = .init(8)
        let new = Draft(account: account, intent: .newDiscussion, title: "Spoon carving knives for a beginner?", body: "Looking for a first hook knife and a straight knife. Budget is modest, and I’d rather buy once than twice.", categoryID: .init(4))
        let lost = Draft(account: account, intent: .newDiscussion, title: "Hardwax oil on a white oak table: how many coats?", body: "Two coats so far. The second one looks patchy where the grain is open.", categoryID: .init(2), missingPhoto: true)
        return [reply, new, lost]
    }
    func check() throws { if offline { throw RepositoryError.offline } }
    func communities() async throws -> [Community] {
        try check()
        return Self.sampleCommunities.map { community in
            var value = community
            guard community.parentID == nil, !community.restricted else { return value }
            let family = [community.id] + Self.sampleCommunities.filter { $0.parentID == community.id }.map(\.id)
            if let latest = summaries.first(where: { family.contains($0.categoryID) }) { value.latest = LatestPreview(topicID: latest.id, title: latest.title, categoryID: latest.categoryID, activity: latest.activity) }
            return value
        }
    }
    func feed(category: Community?, page: Int) async throws -> Page<DiscussionSummary> {
        try check()
        if feedDelay > .zero { try await Task.sleep(for: feedDelay) }
        if category?.restricted == true { throw RepositoryError.denied }
        let ids = category.map { value in [value.id] + Self.sampleCommunities.filter { $0.parentID == value.id }.map(\.id) }
        let values = summaries.filter { ids == nil || ids!.contains($0.categoryID) }
        return paginate(values, page: page, size: 5)
    }
    private func paginate<T: Sendable>(_ values: [T], page: Int, size: Int) -> Page<T> {
        let start = min(page * size, values.count), end = min((page + 1) * size, values.count)
        return Page(items: Array(values[start..<end]), nextPage: end < values.count ? page + 1 : nil)
    }
    private func node(_ post: Post) -> ThreadNode {
        var post = post
        post.bookmarkID = bookmarks[post.id]
        post.childCount = posts[post.topicID, default: []].filter { $0.parent == post.number }.count
        return ThreadNode(post: post)
    }
    func discussion(_ id: TopicID, page: Int) async throws -> DiscussionPage {
        try check(); guard nestedEnabled else { throw RepositoryError.unsupported }
        guard let summary = summaries.first(where: { $0.id == id }), let opening = posts[id]?.first else { throw RepositoryError.unavailable }
        let roots = posts[id, default: []].filter { $0.number.rawValue > 1 && ($0.parent == nil || $0.parent == .init(1)) }.map(node)
        let result = paginate(roots, page: page, size: 3)
        return DiscussionPage(summary: summary, opening: node(opening).post, roots: result.items, nextPage: result.nextPage, canReply: true)
    }
    func children(topic: TopicID, parent: PostNumber, page: Int, depth: Int) async throws -> ChildPage {
        try check(); let result = paginate(posts[topic, default: []].filter { $0.parent == parent }.map(node), page: page, size: 2)
        return ChildPage(nodes: result.items, nextPage: result.nextPage)
    }
    func context(topic: TopicID, number: PostNumber, focused: Bool) async throws -> ThreadContext {
        let page = try await discussion(topic, page: 0)
        guard let target = posts[topic]?.first(where: { $0.number == number }) else { throw RepositoryError.unavailable }
        var ancestors: [Post] = [], current = target
        if !focused {
            while let parent = current.parent, let post = posts[topic]?.first(where: { $0.number == parent }), post.number.rawValue > 1 {
                guard !ancestors.contains(where: { $0.id == post.id }) else { break }
                ancestors.insert(node(post).post, at: 0); current = post
            }
        }
        return ThreadContext(page: page, ancestors: ancestors, target: node(target), truncated: false)
    }
    func like(_ post: Post) async throws -> Post {
        try check(); var value = post; value.liked.toggle(); value.likeCount += value.liked ? 1 : -1
        if let index = posts[post.topicID]?.firstIndex(where: { $0.id == post.id }) { posts[post.topicID]?[index] = value }
        return value
    }
    func bookmark(_ post: Post) async throws -> Post {
        try check(); var value = post
        if bookmarks[post.id] != nil { bookmarks.removeValue(forKey: post.id); value.bookmarkID = nil }
        else { let id = (bookmarks.values.max() ?? 0) + 1; bookmarks[post.id] = id; value.bookmarkID = id }
        return value
    }
    /// Title matches open the discussion; otherwise the first matching post is the exact target.
    func search(_ query: String, page: Int) async throws -> Page<DiscussionSummary> {
        try check()
        let hits: [DiscussionSummary] = summaries.compactMap { summary in
            if summary.title.localizedCaseInsensitiveContains(query) { return summary }
            guard let post = posts[summary.id]?.first(where: { $0.body.localizedCaseInsensitiveContains(query) }) else { return nil }
            var hit = summary; hit.excerpt = post.body
            if post.number.rawValue > 1 { hit.targetPostNumber = post.number; hit.matchAuthor = post.author }
            return hit
        }
        let result = paginate(hits, page: max(0, page - 1), size: 6); return Page(items: result.items, nextPage: result.nextPage.map { $0 + 1 })
    }
    func notifications(page: Int) async throws -> Page<Notice> {
        try check()
        return Page(items: [
            Notice(id: 1, kind: .reply, actor: "devon", title: "Bench PSU hums after a fuse swap", topicID: .init(4190), number: .init(14), age: "5m", read: readNotices.contains(1)),
            Notice(id: 2, kind: .mention, actor: "priya", title: "Deep sleep current on a dev board: 40 mA?", topicID: .init(4201), number: .init(6), age: "1h", read: readNotices.contains(2)),
            Notice(id: 3, kind: .reply, actor: "sunil.p", title: "Walnut darkening under water-based finish", topicID: nil, number: .init(4), age: "2d", read: readNotices.contains(3))
        ], nextPage: nil)
    }
    func markRead(_ notice: Notice) async throws { try check(); readNotices.insert(notice.id) }
    func profile(_ username: String) async throws -> Member {
        try check(); let person = Self.people[username]
        return Member(username: username, name: person?.name, bio: person?.bio ?? "", recent: summaries.filter { $0.author == username }, joined: person?.joined)
    }
    func saved(username: String, page: Int) async throws -> Page<SavedItem> {
        try check()
        let items = posts.values.flatMap { $0 }.filter { bookmarks[$0.id] != nil }.sorted { bookmarks[$0.id]! < bookmarks[$1.id]! }.map { post in
            let summary = summaries.first { $0.id == post.topicID }
            return SavedItem(id: bookmarks[post.id]!, title: summary?.title ?? "Saved reply", topicID: post.topicID, number: post.number, categoryID: summary?.categoryID, postAuthor: post.author)
        }
        return Page(items: items, nextPage: nil)
    }
    func publish(_ draft: Draft) async throws -> PostingOutcome {
        try check(); try await Task.sleep(for: .milliseconds(400))
        guard !draft.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw RepositoryError.invalid("Write something before posting.") }
        switch scenario {
        case .pending: return .pending
        case .rejected: throw RepositoryError.invalid(draft.intent.isNew ? "Title seems unclear, is it a complete sentence?" : "Body is too short (minimum is 20 characters).")
        case .expired: throw RepositoryError.unauthorized
        case .unconfirmed: return .unconfirmed
        case .published:
            if let previous = submitted[draft.id] { return .published(topic: previous.0, number: previous.1) }
            let topic: TopicID
            let number: PostNumber
            if let existing = draft.intent.topicID {
                topic = existing; number = .init((posts[topic]?.map(\.number.rawValue).max() ?? 1) + 1)
                if let index = summaries.firstIndex(where: { $0.id == topic }) { summaries[index].replyCount += 1; summaries[index].activity = "now"; summaries.insert(summaries.remove(at: index), at: 0) }
            } else {
                topic = .init((summaries.map(\.id.rawValue).max() ?? 4200) + 1); number = .init(1)
                summaries.insert(.init(id: topic, title: draft.title, slug: "new-discussion", categoryID: draft.categoryID ?? .init(1), excerpt: draft.body, author: Self.member, replyCount: 0, activity: "now"), at: 0)
            }
            let parent: PostNumber? = { if case let .reply(_, p) = draft.intent, p?.rawValue != 1 { p } else { nil } }()
            posts[topic, default: []].append(Post(id: .init(topic.rawValue * 100 + number.rawValue), number: number, topicID: topic, parent: parent, author: Self.member, body: draft.body, canReply: true, age: "now", quote: draft.quote, authorName: Self.people[Self.member]?.name))
            submitted[draft.id] = (topic, number); return .published(topic: topic, number: number)
        }
    }
    func reconcile(_ draft: Draft) async throws -> Reconciliation {
        try check(); if let found = submitted[draft.id] { return .published(topic: found.0, number: found.1) }; return .unresolved
    }
    var composerCapabilities: ComposerCapabilities { .fixture }
    func similarDiscussions(title: String, raw: String) async throws -> [DiscussionSummary] {
        try check(); try await Task.sleep(for: .milliseconds(100))
        return Array(try await feed(category: nil, page: 0).items.prefix(3))
    }
    func oneboxPreview(url: URL, context: OneboxContext) async throws -> OneboxMetadata? {
        try check(); try await Task.sleep(for: .milliseconds(100))
        return OneboxMetadata(url: url, title: url.host ?? "Link", summary: "Fixture link preview")
    }
    func upload(_ data: Data, progress: @escaping @MainActor @Sendable (Double) -> Void) async throws -> UploadedPhoto {
        try check()
        for i in 1...10 { try await Task.sleep(for: uploadStep); progress(Double(i)/10); if uploadFails && i == 6 { throw RepositoryError.invalid("Photo upload failed. Retry or remove it.") } }
        return UploadedPhoto(url: "fixture-photo", shortURL: "upload://fixture-\(UUID().uuidString).jpg")
    }
}
