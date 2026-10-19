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
    /// Development-only: the next "load more" page fails once, then succeeds on retry.
    var failNextPage = false
    var uploadStep: Duration = .milliseconds(100)
    var bookmarks: [PostID: Int] = [PostID(418201): 1, PostID(419014): 2]
    /// Fictional notification rows; see `NotificationFixture`.
    var notices = NotificationFixture()
    var submitted: [UUID: (TopicID, PostNumber)] = [:]
    var posts: [TopicID: [Post]] = [:]
    var summaries: [DiscussionSummary] = []
    var ignoredMembers: Set<String> = []
    var reports: Set<PostID> = []
    func safetySession() async throws -> SafetySession {
        if offline { throw RepositoryError.offline }
        return SafetySession(username: Self.member, canIgnoreUsers: true, ignoredUsers: ignoredMembers.sorted())
    }
    func reportReasons(post: Post) async throws -> [ReportReason] {
        if offline { throw RepositoryError.offline }
        return reports.contains(post.id) ? [] : [
            ReportReason(id: 42, title: "Inappropriate", description: "Abusive or harmful content", requiresMessage: false),
            ReportReason(id: 77, title: "Something else", description: "Tell the moderators what happened", requiresMessage: true)
        ]
    }
    func report(post: Post, reason: Int, message: String) async throws {
        guard let option = try await reportReasons(post: post).first(where: { $0.id == reason }), !option.requiresMessage || !message.isEmpty else { throw RepositoryError.denied }
        reports.insert(post.id)
    }
    func setIgnored(username: String, ignored: Bool) async throws -> SafetySession {
        if offline { throw RepositoryError.offline }
        guard username != Self.member else { throw RepositoryError.denied }
        if ignored { ignoredMembers.insert(username) } else { ignoredMembers.remove(username) }
        return try await safetySession()
    }
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
            p("mara_k", "2d", "Dewaxed. Regular shellac can cause adhesion problems with water-based topcoats.", 4)]),
        (4205, 3, "40m", "Hide glue or PVA for a first chair repair?", [
            p("jonah.w", "1d", "A kitchen chair has a loose stretcher. The old joint looks like hide glue. Should I clean it out and use hide glue again, or is PVA fine for a first repair?", 3),
            p("mara_k", "20h", "Hide glue sticks to old hide glue. PVA won’t bond well unless you clean the joint completely.", 2),
            p("theo", "18h", "Liquid hide glue from a bottle is easy to start with. No glue pot needed."),
            p("jonah.w", "3h", "Update: I warmed the joint and it came apart cleanly. Old glue is mostly flakes. How clean does it need to be before regluing?", 1),
            p("devon", "1h", "Hot water and a toothbrush gets most of it. You don’t need bare wood for hide glue.", 2),
            p("alex.h", "50m", "Scrape lightly and keep the tenon shoulders crisp. A loose fit is worse than a little old glue."),
            p("ines.r", "40m", "Clamp it square and leave it overnight. Check the diagonals before the glue grabs."),
            p("priya", "30m", "Following. I have the same chair problem.")])
    ]
    /// Nested replies are the approved native adaptation; the mockup draws them chronologically.
    private static func parent(topic: Int, number: Int) -> PostNumber? {
        if topic == 4205 { return [5, 6, 7].contains(number) ? .init(4) : nil }
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
    #if DEBUG
    /// Screenshot-only presentation of existing fictional seeds. No live service or media requests.
    func prepareStorePreview() {
        let order = [4188, 4176, 4195, 4160, 4201, 4170, 4182, 4190]
        summaries = order.compactMap { id in summaries.first { $0.id.rawValue == id } }
        for index in summaries.indices { summaries[index].image = nil; summaries[index].imageURL = nil }
        for topic in Array(posts.keys) {
            for index in posts[topic, default: []].indices { posts[topic]?[index].image = nil }
        }
    }
    #endif
    /// Fictional topic-card edge cases (`--card-cases`): pinned with no replies, Arabic, absent author/excerpt/activity,
    /// failed media and a long title with a photo. They have no discussion posts, so opening one shows the unavailable state.
    func addCardCases() {
        // A refused loopback HTTPS connection fails deterministically without leaving the device. A missing `file:` URL
        // stays in AsyncImage's loading phase on iOS 27, so it no longer exercised the failure fallback.
        let missingMedia = URL(string: "https://127.0.0.1:9/fomio-fixture/missing-thumbnail.jpg")!
        let cases: [DiscussionSummary] = [
            .init(id: .init(5001), title: "Read first: how photos and measurements help a repair question", slug: "card-pinned", categoryID: .init(5), excerpt: "Include the model, what changed and a clear photo of the bench setup.", author: "devon", replyCount: 0, activity: "3h", pinned: true),
            .init(id: .init(5002), title: "ما أفضل طريقة لري شجرة تين في أصيص خلال الشتاء؟", slug: "card-arabic", categoryID: .init(8), excerpt: "الكراج عندي يبقى قرابة درجتين مئويتين. هل ألف الأصيص أم أدخله إلى البيت؟", author: "ines.r", replyCount: 3, activity: "40m"),
            .init(id: .init(5003), title: "Untitled bench notes without an opening excerpt", slug: "card-sparse", categoryID: .init(9), excerpt: "", author: "", replyCount: 0, activity: ""),
            .init(id: .init(5004), title: "Thumbnail failed to load: the card falls back to text", slug: "card-failed-media", categoryID: .init(6), excerpt: "This fictional topic points at a missing image so the media slot is removed.", author: "theo", replyCount: 1, activity: "2h", imageURL: missingMedia),
            .init(id: .init(5005), title: "Restoring a walnut side table whose top has a decades-old water ring, uneven fading under a lamp, and a veneer edge that has lifted along the back", slug: "card-long", categoryID: .init(2), excerpt: "Before I strip anything: is there a gentler order of operations that keeps the original patina where it is still even?", author: "margaux.delacroix-whitfield", replyCount: 12, activity: "1d", image: "ph-walnut")
        ]
        summaries.insert(contentsOf: cases, at: min(1, summaries.count))
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
        if page > 0 && failNextPage { failNextPage = false; throw RepositoryError.server(503) }
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
    /// Development/tests: the next child-reply request fails as offline once.
    var failNextChildren = false
    func children(topic: TopicID, parent: PostNumber, page: Int, depth: Int) async throws -> ChildPage {
        try check(); if failNextChildren { failNextChildren = false; throw RepositoryError.offline }
        let result = paginate(posts[topic, default: []].filter { $0.parent == parent }.map(node), page: page, size: 2)
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
    func notificationHistory(offset: Int, limit: Int, filter: NotificationFilter) async throws -> NotificationHistoryPage {
        try check()
        if notices.delay > .zero { try await Task.sleep(for: notices.delay) }
        if offset > 0 && notices.failNextPage { notices.failNextPage = false; throw RepositoryError.server(503) }
        if offset == 0 && notices.failNextRefresh { notices.failNextRefresh = false; throw RepositoryError.server(502) }
        let page = notices.page(offset: offset, filter: filter)
        if suspendNextHistory {
            // Tests: the server snapshot is taken, then the response is held until `resumeHistory()`.
            suspendNextHistory = false; historySuspended = true
            await withCheckedContinuation { historyResume = $0 }
            historySuspended = false
        }
        return page
    }
    var suspendNextHistory = false
    private(set) var historySuspended = false
    @ObservationIgnored private var historyResume: CheckedContinuation<Void, Never>?
    func resumeHistory() { let resume = historyResume; historyResume = nil; resume?.resume() }
    func markNotificationRead(_ id: NotificationID) async throws {
        try check(); try await Task.sleep(for: .milliseconds(300))
        switch notices.nextAcknowledgment {
        case .fail: notices.nextAcknowledgment = .succeed; throw RepositoryError.server(500)
        case .unknown:
            // The write may have landed: apply it, then report an unconfirmed outcome.
            notices.nextAcknowledgment = .succeed; notices.markRead(id); throw RepositoryError.unconfirmed
        case .succeed: notices.markRead(id)
        }
    }
    func notificationTotals() async throws -> NotificationTotals { try check(); if credentialExpired { throw RepositoryError.denied }; return NotificationTotals(unread: notices.unseenUnread) }
    /// Development/tests: the stored key was revoked or expired (Discourse answers 403 `invalid_access`).
    var credentialExpired = false
    func credentialIsValid(username: String) async throws -> Bool { try check(); return !credentialExpired }
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

/// Fictional notification history mirroring the approved mock: exact replies, grouped branch and topic replies,
/// an unavailable target, unsupported types, rows filtered after windowing and a seen cursor for server totals.
struct NotificationFixture: Sendable {
    enum Acknowledgment: Sendable { case succeed, fail, unknown }
    struct Row: Sendable { var item: NotificationItem; var inaccessible = false }
    static let site = URL(string: "https://community.example")!
    var rows: [Row]
    var pageSize = 6
    var seenID = 4998
    var nextAcknowledgment: Acknowledgment = .succeed
    var failNextPage = false
    var failNextRefresh = false
    var delay: Duration = .zero
    init() {
        func n(_ id: Int, _ kind: NotificationKind, _ actor: String?, _ topic: Int?, _ post: Int?, _ title: String?, read: Bool, age: String, category: Int? = nil, bucket: Int? = nil, count: Int? = nil, group: String? = nil, inaccessible: Bool = false) -> Row {
            var item = NotificationItem(id: .init(id), kind: kind, read: read, age: age, topicID: topic.map { TopicID($0) }, postNumber: post.map { PostNumber($0) }, topicTitle: title, slug: topic.map { "topic-\($0)" }, displayUsername: actor, originalUsername: actor, replyBucket: bucket.map { PostNumber($0) }, consolidatedCount: count, groupName: group, categoryID: category.map { CategoryID($0) })
            if count != nil { item.displayUsername = "\(count!) replies"; item.originalUsername = "ines.r" }
            return Row(item: item, inaccessible: inaccessible)
        }
        let chair = "Hide glue or PVA for a first chair repair?"
        rows = [
            n(5011, .replied, "devon", 4190, 14, "Bench PSU hums after a fuse swap", read: false, age: "5m", category: 6),
            n(5010, .replied, nil, 4205, 5, chair, read: false, age: "40m", category: 3, bucket: 4, count: 3),
            n(5009, .mentioned, "priya", 4201, 6, "Deep sleep current on a dev board: 40 mA?", read: false, age: "1h", category: 7),
            n(5008, .quoted, "sunil.p", 4182, 4, "Oil vs. hardwax on a walnut desk top?", read: false, age: "2h", category: 2),
            n(5007, .unknown(800), "alex.h", 4195, 1, "First drawbored mortise and tenon", read: false, age: "3h", category: 3),
            n(5006, .replied, "theo", 4999, 6, "Bench power supply recommendations", read: false, age: "4h", category: 5),
            n(5005, .groupMentioned, "alex.h", 4195, 3, "First drawbored mortise and tenon", read: true, age: "5h", category: 3, group: "woodworkers"),
            n(5004, .replied, "theo", 4170, 2, "Overwintering a fig in a large container", read: true, age: "Yesterday", category: 8),
            n(5003, .mentioned, "theo", 4201, 5, "Deep sleep current on a dev board: 40 mA?", read: true, age: "Yesterday", category: 7),
            n(5002, .unknown(1000), nil, nil, nil, nil, read: true, age: "2d"),
            n(5001, .replied, "margaux.delacroix-whitfield", 4199, 2, "Built a standing desk from reclaimed oak flooring", read: true, age: "3d", category: 1),
            n(5000, .liked, "mara_k", 4188, 2, "Blotchy cherry: can gel stain save it?", read: true, age: "4d", category: 2),
            n(4999, .replied, nil, 4205, 2, chair, read: true, age: "5d", category: 3, bucket: 1, count: 3)
        ] + (4993...4998).reversed().map { n($0, .replied, "devon", 4100 + $0 % 7, 3, nil, read: false, age: "1w", inaccessible: true) } + [
            n(4990, .mentioned, "priya", 4201, 6, "Deep sleep current on a dev board: 40 mA?", read: false, age: "2w", category: 7)
        ]
    }
    func page(offset: Int, filter: NotificationFilter) -> NotificationHistoryPage {
        let scoped = rows.filter { filter == .all || !$0.item.read }
        let window = scoped.dropFirst(offset).prefix(pageSize)
        // Like the server, permission filtering happens after the window and after counting the total.
        return NotificationHistoryPage(items: window.filter { !$0.inaccessible }.map(\.item), offset: offset, limit: pageSize, totalRows: scoped.count, seenNotificationID: seenID)
    }
    var unseenUnread: Int { min(NotificationTotals.serverCap, rows.filter { !$0.item.read && $0.item.id.rawValue > seenID }.count) }
    mutating func markRead(_ id: NotificationID) { if let index = rows.firstIndex(where: { $0.item.id == id }) { rows[index].item.read = true } }
    /// Consolidation destroys the earlier grouped row and creates a new ID (server behavior in `PostAlerter`).
    mutating func consolidate(replacing old: NotificationID, with new: NotificationID, count: Int) {
        guard let index = rows.firstIndex(where: { $0.item.id == old }) else { return }
        var row = rows.remove(at: index); row.item.id = new; row.item.consolidatedCount = count; row.item.displayUsername = "\(count) replies"; row.item.read = false; row.item.age = "now"
        rows.insert(row, at: 0)
    }
    mutating func arrive(_ item: NotificationItem) { rows.insert(Row(item: item), at: 0) }
}
