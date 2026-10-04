#if DEBUG
import Foundation

/// Opens the fixture app at a Screen Pack state (`--preset <name>`), mirroring the mockup's FomioPhone presets.
/// Development only: every outcome is simulated by `FixtureService`; nothing reaches a live community.
@MainActor enum DevelopmentPresets {
    static var requested: String? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "--preset"), arguments.indices.contains(index + 1) else { return nil }
        return arguments[index + 1]
    }
    static let typed = "I used a hardwax oil on white oak two years ago. Mug rings wiped off with a damp cloth, and one scratch spot-repaired fine."
    static func apply(_ preset: String, to app: AppState) async {
        guard let fixture = app.fixture else { return }
        let walnut = TopicID(4182), finishing = CategoryID(2), woodworking = CategoryID(1)
        func reply(_ body: String = typed) async {
            app.navigate(.discussion(walnut, nil))
            guard let opening = try? await fixture.discussion(walnut, page: 0).opening else { return }
            var draft = Draft(account: app.account, intent: .reply(topic: walnut, parent: opening.number), body: body)
            draft.contextTitle = "Oil vs. hardwax on a walnut desk top?"; draft.contextCategory = finishing
            app.composer = ComposerState(draft: draft, app: app, origin: .home)
        }
        func newTopic(body: String) {
            app.selectedTab = .communities; app.navigate(.community(woodworking), in: .communities); app.navigate(.community(finishing), in: .communities)
            app.composer = ComposerState(draft: Draft(account: app.account, intent: .newDiscussion, title: "Hardwax oil on a white oak table: how many coats?", body: body, categoryID: finishing), app: app, origin: .communities)
        }
        let photo = Bundle.main.url(forResource: "fixture-photo", withExtension: "jpg").flatMap { try? Data(contentsOf: $0) } ?? Data()
        switch preset {
        case "communities": app.selectedTab = .communities
        case "findcom": app.selectedTab = .communities; app.tabs[.communities]?.communityQuery = "fin"
        case "findnone": app.selectedTab = .communities; app.tabs[.communities]?.communityQuery = "pottery"
        case "community": app.selectedTab = .communities; app.navigate(.community(woodworking), in: .communities)
        case "subcommunity": app.selectedTab = .communities; app.navigate(.community(woodworking), in: .communities); app.navigate(.community(finishing), in: .communities)
        case "empty": app.selectedTab = .communities; app.navigate(.community(woodworking), in: .communities); app.navigate(.community(.init(9)), in: .communities)
        case "denied": app.selectedTab = .communities; app.navigate(.denied(.init(10)), in: .communities)
        case "discussion": app.navigate(.discussion(walnut, nil))
        case "offline": app.navigate(.discussion(walnut, nil)); try? await Task.sleep(for: .milliseconds(600)); fixture.offline = true
        case "linked": app.selectedTab = .notifications; fixture.readNotices.insert(1); app.navigate(.discussion(.init(4190), .init(14)), in: .notifications, focus: .notification)
        case "unavailable": app.selectedTab = .notifications; app.navigate(.unavailable, in: .notifications)
        case "search": app.tabs[.home]?.searchQuery = "walnut"; app.navigate(.search)
        case "notifications": app.selectedTab = .notifications
        case "me": app.selectedTab = .me
        case "profile": app.navigate(.discussion(walnut, nil)); app.navigate(.profile("mara_k"))
        case "saved": app.selectedTab = .me; app.navigate(.saved, in: .me)
        case "drafts", "draftlost":
            for draft in FixtureService.sampleDrafts(account: app.account) where preset == "drafts" || draft.missingPhoto { try? app.draftStore.save(draft) }
            app.selectedTab = .me; app.navigate(.drafts, in: .me)
        case "resumelost":
            let lost = FixtureService.sampleDrafts(account: app.account)[2]; try? app.draftStore.save(lost)
            app.selectedTab = .me; app.navigate(.drafts, in: .me); app.resume(lost)
        case "chooser": app.choosingDestination = true
        case "reply": await reply()
        case "editor-blocks": await reply("Writing before code\n```swift\nlet greeting = 1\n```")
        case "quote":
            app.navigate(.discussion(walnut, nil))
            if let post = try? await fixture.context(topic: walnut, number: .init(2), focused: true).target.post { app.reply(to: post, quote: true) }
        case "newtopic": newTopic(body: "")
        case "uploading": fixture.uploadFails = false; fixture.uploadStep = .seconds(3); newTopic(body: "Two coats so far. The second one looks patchy where the grain is open."); app.composer?.addPhoto(photo)
        case "uploadfail": fixture.uploadFails = true; newTopic(body: "Two coats so far. The second one looks patchy where the grain is open."); app.composer?.addPhoto(photo)
        case "rejected", "expired", "unconfirmed", "pending":
            fixture.scenario = FixtureService.Scenario(rawValue: preset) ?? .published
            await reply(preset == "rejected" ? "Too short." : typed)
            await app.composer?.submit()
        default: break
        }
    }
}
#endif
