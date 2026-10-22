import XCTest
@testable import Fomio

@MainActor final class AdaptiveSearchTests: XCTestCase {
    private func settings(_ minimum: Int = 3) throws -> SearchSettings { try .init(minimumTermLength: minimum, locale: "en") }
    private var catalog: [Community] {
        [Community(id: .init(45), name: "Parent", slug: "parent", description: "", canCreate: false),
         Community(id: .init(46), name: "Child", slug: "child", parentID: .init(45), description: "", canCreate: true)]
    }
    private func request(_ query: String = "Fomio", scope: BrowseScope = .all, page: Int = 1) throws -> DiscussionSearchRequest {
        try .init(query: query, scope: scope, page: page, settings: settings(), catalog: catalog)
    }
    private func service(_ body: String, member: Bool = false) -> DiscourseService {
        StubURLProtocol.handler = nil; StubURLProtocol.status = 200; StubURLProtocol.data = Data(body.utf8); StubURLProtocol.captured = nil
        let config = URLSessionConfiguration.ephemeral; config.protocolClasses = [StubURLProtocol.self]; config.urlCache = nil
        let configuration = LiveConfiguration(baseURL: URL(string: "https://search.example/forum")!, callbackURL: URL(string: "test://auth")!, scopes: "read")
        let credential = member ? Credential(key: "fictional-member-key", clientID: "fictional-client", site: configuration.baseURL.absoluteString) : nil
        return DiscourseService(configuration: configuration, session: URLSession(configuration: config), credentials: { _ in credential })
    }
    private let success = #"{"posts":[{"id":145,"topic_id":14,"post_number":5,"blurb":"match"}],"topics":[{"id":14,"title":"Result","slug":"result","category_id":46,"archetype":"regular"}],"grouped_search_result":{"more_full_page_results":true,"error":null}}"#

    func testMinimumAppliesBeforeGeneratedCategoryConstraint() throws {
        XCTAssertThrowsError(try request("xy", scope: .category(.init(45))))
        XCTAssertThrowsError(try request("\"xy\"", scope: .category(.init(45))))
        XCTAssertThrowsError(try request("\"\""))
        XCTAssertNoThrow(try request("مرحبا C++ & tools", scope: .category(.init(45))))
    }
    func testGrammarRejectsModeAndScopeOperatorsEvenInsideQuotes() throws {
        for query in ["topic:12", "\"category:45\"", "in:all", "in:personal", "#private", "@member", "Fomio | other", "-private", "unbalanced \"phrase", "a\u{0}b", "hello\\world"] {
            XCTAssertThrowsError(try request(query), query)
        }
        XCTAssertNoThrow(try request("\"hand tools\" cherry-wood C++ & steel"))
    }
    func testScopeRequiresVisibleNumericIdentityAndIncludesChildren() throws {
        XCTAssertEqual(try request(scope: .category(.init(45))).allowedCategoryIDs, Set([CategoryID(45), CategoryID(46)]))
        XCTAssertEqual(try request(scope: .category(.init(46))).allowedCategoryIDs, Set([CategoryID(46)]))
        XCTAssertThrowsError(try request(scope: .category(.init(0))))
        XCTAssertThrowsError(try request(scope: .category(.init(99))))
        XCTAssertThrowsError(try request(page: 0)); XCTAssertThrowsError(try request(page: 11))
    }
    func testScopedRequestRetainsEncodingMemberHeadersAndBypassesHTTPCache() async throws {
        let service = service(success, member: true)
        let result = try await service.search(request("مرحبا C++ & tools", scope: .category(.init(45))))
        let captured = try XCTUnwrap(StubURLProtocol.captured)
        let components = try XCTUnwrap(URLComponents(url: try XCTUnwrap(captured.url), resolvingAgainstBaseURL: false))
        let query = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })
        XCTAssertEqual(query, ["q":"مرحبا C++ & tools category:45", "page":"1", "context":"category", "context_id":"45"])
        XCTAssertTrue(components.percentEncodedQuery?.contains("%2B%2B") == true)
        XCTAssertEqual(captured.url?.path, "/forum/search.json")
        XCTAssertEqual(captured.cachePolicy, .reloadIgnoringLocalCacheData)
        XCTAssertEqual(captured.value(forHTTPHeaderField: "User-Api-Key"), "fictional-member-key")
        XCTAssertNil(captured.value(forHTTPHeaderField: "Api-Key"))
        XCTAssertEqual(result.items.first?.id, PostID(145)); XCTAssertEqual(result.items.first?.number, PostNumber(5))
        XCTAssertEqual(result.nextPage, 2)
    }
    func testGroupedErrorWinsOverPopulatedOrMalformedFacets() async throws {
        for body in [
            #"{"grouped_search_result":{"error":"Search could not be completed. Please try again."},"posts":[],"users":[]}"#,
            #"{"grouped_search_result":{"error":"حاول مرة أخرى"},"posts":"malformed","topics":42}"#,
            success.replacingOccurrences(of: #""error":null"#, with: #""error":"unknown future error""#)
        ] {
            let service = service(body)
            do { _ = try await service.search(request()); XCTFail("Must throw grouped failure") }
            catch { XCTAssertEqual(error as? SearchFailure, .serverSearch) }
            // Search metadata must not select the failed result's slug for a later exact request.
            StubURLProtocol.data = Data("{}".utf8)
            _ = try? await service.discussion(.init(14), page: 0)
            XCTAssertEqual(StubURLProtocol.captured?.url?.path, "/forum/n/topic/14.json")
        }
    }
    func testMissingNullAndBlankErrorAllowValidSuccess() async throws {
        for replacement in [#""error":null"#, #""error":"""#, #""error":"  \n ""#] {
            let service = service(success.replacingOccurrences(of: #""error":null"#, with: replacement))
            let result = try await service.search(request())
            XCTAssertEqual(result.items.count, 1)
        }
        let service = service(success.replacingOccurrences(of: #","error":null"#, with: ""))
        let result = try await service.search(request())
        XCTAssertEqual(result.items.count, 1)
    }
    func testMalformedErrorsAndEnvelopesAreContractFailures() async throws {
        for body in ["{}", "[]", "not json", #"{"grouped_search_result":{"error":42}}"#, #"{"grouped_search_result":"bad"}"#, #"{"grouped_search_result":{}}"#, #"{"posts":[],"grouped_search_result":{"more_full_page_results":true}}"#] {
            let service = service(body)
            do { _ = try await service.search(request()); XCTFail(body) }
            catch { XCTAssertEqual(error as? SearchFailure, .contract, body) }
        }
    }
    func testEmptyPostsAndStopwordEnvelopeAreValidEmptyResults() async throws {
        for body in [#"{"posts":[],"grouped_search_result":{"more_full_page_results":false,"error":null}}"#, #"{"posts":[],"grouped_search_result":{"term":"the","more_full_page_results":null,"error":null}}"#] {
            let service = service(body)
            let page = try await service.search(request("the"))
            XCTAssertTrue(page.items.isEmpty); XCTAssertNil(page.nextPage)
        }
    }
    func testScopeJoinAndPublicDiscussionValidationRejectWholeResponse() async throws {
        let failures = [
            success.replacingOccurrences(of: #""category_id":46"#, with: #""category_id":99"#),
            success.replacingOccurrences(of: #""archetype":"regular""#, with: #""archetype":"private_message""#),
            success.replacingOccurrences(of: #""topic_id":14"#, with: #""topic_id":99"#),
            success.replacingOccurrences(of: #""id":145"#, with: #""id":0"#),
            success.replacingOccurrences(of: #""post_number":5"#, with: #""post_number":0"#)
        ]
        for body in failures {
            let service = service(body)
            do { _ = try await service.search(request(scope: .category(.init(45)))); XCTFail(body) }
            catch { XCTAssertEqual(error as? SearchFailure, .contract) }
        }
    }
    func testSettingsAreFetchedAndValidatedRatherThanAssumed() async throws {
        let service = service(#"{"min_search_term_length":4,"default_locale":"ar"}"#)
        let settings = try await service.searchSettings()
        XCTAssertEqual(settings.minimumTermLength, 4); XCTAssertEqual(settings.locale, "ar")
        XCTAssertEqual(StubURLProtocol.captured?.url?.path, "/forum/site/settings.json")
        StubURLProtocol.data = Data(#"{"min_search_term_length":0,"default_locale":""}"#.utf8)
        do { _ = try await service.searchSettings(); XCTFail("Invalid settings") } catch { XCTAssertEqual(error as? SearchFailure, .settings) }
    }
    func testTenthPageStopsOnlyAtTheVerifiedServerContinuationBoundary() async throws {
        let service = service(success)
        let last = try await service.search(request(page: 10))
        XCTAssertNil(last.nextPage); XCTAssertTrue(last.reachedLimit)
        StubURLProtocol.data = Data(success.replacingOccurrences(of: "true", with: "false").utf8)
        let exhausted = try await service.search(request(page: 10))
        XCTAssertNil(exhausted.nextPage); XCTAssertFalse(exhausted.reachedLimit)
    }
    func testRetryAfterParsesBothHTTPFormsAndRejectsInvalidValues() {
        let now = Date(timeIntervalSince1970: 0)
        XCTAssertEqual(APIClient.retryDate("12", now: now), now.addingTimeInterval(12))
        XCTAssertEqual(APIClient.retryDate("Thu, 01 Jan 1970 00:01:00 GMT", now: now), now.addingTimeInterval(60))
        XCTAssertNil(APIClient.retryDate("NaN", now: now)); XCTAssertNil(APIClient.retryDate("-1", now: now)); XCTAssertNil(APIClient.retryDate(nil, now: now))
    }
    func testRetryCountdownHandlesLargeServerDelayAndLocalizesFallback() throws {
        let now = Date(timeIntervalSince1970: 0)
        let english = Locale(identifier: "en"), arabic = Locale(identifier: "ar")
        XCTAssertEqual(BrowseLocalization.retryCountdown(until: now.addingTimeInterval(2.2), now: now, locale: english), "Try again in 3 seconds")
        let deadline = try XCTUnwrap(APIClient.retryDate("999999999999999999999999999999999999999999", now: now))
        XCTAssertGreaterThan(deadline.timeIntervalSince(now), Double(Int.max))
        XCTAssertEqual(BrowseLocalization.retryCountdown(until: deadline, now: now, locale: english), "Try again later")
        XCTAssertEqual(BrowseLocalization.retryCountdown(until: deadline, now: now, locale: arabic), "حاول لاحقًا")
        XCTAssertEqual(BrowseLocalization.retryCountdown(until: now.addingTimeInterval(Double(Int.max)), now: now, locale: english), "Try again later")
    }
    func testCategoryFallbackRequiresMatchingIdentityAndKeepsReadOnlyVisibility() async throws {
        let service = service(#"{"category":{"id":46,"name":"Private child","parent_category_id":45,"permission":2,"read_restricted":true}}"#, member: true)
        let category = try await service.community(.init(46))
        XCTAssertEqual(category.id, CategoryID(46)); XCTAssertEqual(category.parentID, CategoryID(45))
        XCTAssertFalse(category.canCreate); XCTAssertFalse(category.restricted)
        XCTAssertEqual(StubURLProtocol.captured?.url?.path, "/forum/c/46/show.json")
        XCTAssertEqual(StubURLProtocol.captured?.value(forHTTPHeaderField: "User-Api-Key"), "fictional-member-key")
        do { _ = try await service.community(.init(99)); XCTFail("Cannot accept another category's metadata") }
        catch { XCTAssertEqual(error as? SearchFailure, .contract) }
        StubURLProtocol.data = Data(#"{"category":{"id":46,"name":"Writable","permission":1}}"#.utf8)
        let writable = try await service.community(.init(46))
        XCTAssertTrue(writable.canCreate)
    }
    func testResolvedWritableCategoryUsesTheSameCreateAndComposerPermissionContract() async throws {
        let service = service(#"{"category":{"id":46,"name":"Empty writable community","permission":1}}"#, member: true)
        let fixture = FixtureService()
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let app = AppState(service: service, fixture: fixture, configuration: nil, store: DraftStore(directory: directory))
        app.communitiesLoaded = true // C01 can prune an empty category; C08 explicitly authorizes it.
        await app.resolveCategory(.init(46))
        XCTAssertTrue(app.communities.isEmpty); XCTAssertEqual(app.browseCatalog.map(\.id), [CategoryID(46)])
        app.create(category: .init(46))
        let clock = ContinuousClock(), deadline = ContinuousClock.now + .seconds(2)
        while app.composer == nil && clock.now < deadline { await Task.yield() }
        let composer = try XCTUnwrap(app.composer)
        XCTAssertEqual(composer.draft.categoryID, CategoryID(46))
        composer.draft.title = "A resolved destination"; composer.draft.body = "Writing stays native."
        XCTAssertTrue(composer.canPost)
        // A read-only catalog replacement is authoritative for subsequent posting eligibility.
        app.communities = [Community(id: .init(46), name: "Read only", slug: "read-only", description: "", canCreate: false)]
        XCTAssertFalse(composer.canPost)
        XCTAssertTrue(fixture.submitted.isEmpty, "This acceptance check never submits a post")
    }
    func testViewerInvalidationRemovesSearchMetadataBeforeNextTopicRead() async throws {
        let service = service(success)
        _ = try await service.search(request())
        service.invalidateViewerCaches()
        StubURLProtocol.data = Data("{}".utf8)
        _ = try? await service.discussion(.init(14), page: 0)
        XCTAssertEqual(StubURLProtocol.captured?.url?.path, "/forum/n/topic/14.json")
    }
    func testUnexpectedDeeperTaxonomyCannotBroadenSearch() throws {
        let grandchild = Community(id: .init(47), name: "Grandchild", slug: "grandchild", parentID: .init(46), description: "", canCreate: false)
        for scope: BrowseScope in [.category(.init(45)), .category(.init(46)), .category(.init(47))] {
            XCTAssertThrowsError(try DiscussionSearchRequest(query: "Fomio", scope: scope, page: 1, settings: settings(), catalog: catalog + [grandchild]))
        }
    }
    func testScopeAndSiblingReadingChangesStayInOriginatingTab() async throws {
        let fixture = FixtureService()
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let app = AppState(service: fixture, fixture: fixture, configuration: nil, store: DraftStore(directory: directory))
        let home = try XCTUnwrap(app.tabs[.home]), communities = try XCTUnwrap(app.tabs[.communities])
        home.discussionSearch.query = "Retained query"
        app.navigate(.discussion(.init(4182), .init(2)), in: .home)
        app.navigate(.thread(.init(4182), .init(3)), in: .home)
        app.selectedTab = .me
        app.selectScope(.category(.init(2)), in: .home)
        XCTAssertEqual(home.path, [.discussion(.init(4182), .init(2)), .thread(.init(4182), .init(3))])
        XCTAssertEqual(home.discussionSearch.query, "Retained query")
        XCTAssertEqual(communities.browseScope, .all); XCTAssertTrue(communities.path.isEmpty)
        app.navigate(.discussion(.init(4183), .init(5)), in: .home)
        XCTAssertEqual(home.path, [.discussion(.init(4183), .init(5))])
        let revision = home.readingSelectionRevision
        app.navigate(.discussion(.init(4183), .init(5)), in: .home)
        XCTAssertEqual(home.readingSelectionRevision, revision + 1)
        app.selectScope(.category(.init(2)), in: .communities)
        XCTAssertEqual(communities.path, [.community(.init(2))])
        XCTAssertEqual(app.selectedTab, .me)
    }
    func testExplicitPublicationAndPublicLinkRemainVisibleOutsidePreviousScope() async throws {
        let fixture = FixtureService()
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let configuration = LiveConfiguration(baseURL: URL(string: "https://search.example/forum")!, callbackURL: URL(string: "test://auth")!, scopes: "read")
        let app = AppState(service: fixture, fixture: fixture, configuration: configuration, store: DraftStore(directory: directory))
        await app.loadCommunities()
        let home = try XCTUnwrap(app.tabs[.home])
        app.selectScope(.category(.init(9)))
        app.published(topic: .init(4182), number: .init(4), origin: .home, isReply: true, categoryID: .init(2))
        XCTAssertEqual(home.browseScope, .all)
        XCTAssertEqual(home.path.last, .discussion(.init(4182), .init(4)))
        app.selectScope(.category(.init(1)))
        app.published(topic: .init(4182), number: .init(5), origin: .home, isReply: true, categoryID: .init(2))
        XCTAssertEqual(home.browseScope, .category(.init(1)), "A containing root remains selected")
        app.selectScope(.category(.init(9)))
        app.handleLink(URL(string: "https://search.example/forum/t/4182/7")!)
        XCTAssertEqual(home.browseScope, .all)
        XCTAssertEqual(home.path.last, .discussion(.init(4182), .init(7)))
    }
    func testCanonicalAPIRedirectCannotLeaveConfiguredForumBasePath() {
        let base = URL(string: "https://search.example/forum")!
        let delegate = SameOriginDelegate(baseURL: base)
        let original = base.appendingPathComponent("c/45/l/latest.json")
        XCTAssertTrue(delegate.permitsRedirect(from: original, to: base.appendingPathComponent("c/woodworking/45/l/latest.json")))
        for value in ["https://search.example/c/45/l/latest.json", "https://search.example/forum2/c/45/l/latest.json", "https://search.example/forum/../other/c/45", "https://other.example/forum/c/45", "http://search.example/forum/c/45", "https://search.example:444/forum/c/45", "https://user:password@search.example/forum/c/45"] {
            XCTAssertFalse(delegate.permitsRedirect(from: original, to: URL(string: value)!), value)
        }
    }
    func testIntroductionLinksRespectOriginBasePathAndSupportedExactDestinations() {
        let base = URL(string: "https://search.example/forum")!
        XCTAssertEqual(LinkRouter.communityIntroductionURL("/forum/t/about/14", baseURL: base)?.path, "/forum/t/about/14")
        for value in ["https://other.example/forum/t/14", "https://search.example:444/forum/t/14", "/t/14", "/forum2/t/14", "https://member:password@search.example/forum/t/14", "/forum/t/14/children/2", "/forum/search?q=Fomio", "/forum/t/14?api_key=fictional"] {
            XCTAssertNil(LinkRouter.communityIntroductionURL(value, baseURL: base), value)
        }
        XCTAssertEqual(LinkRouter.route(URL(string: "https://search.example/forum/n/topic/14/context/5")!, baseURL: base), .discussion(.init(14), .init(5)))
        XCTAssertNil(LinkRouter.route(URL(string: "https://search.example/forum/n/topic/14/children/5")!, baseURL: base))
    }
    func testArabicSearchValidationAndFailureCopyUsesRequestedUILocale() throws {
        let arabic = Locale(identifier: "ar")
        XCTAssertEqual(SearchFailure.serverSearch.localizedMessage(locale: arabic), "تعذر إكمال البحث. حاول مجددًا.")
        let mixedDirection = BrowseLocalization.format("Search in %@", locale: arabic, "Finishing")
        // Foundation uses LRI on iOS26 and FSI on iOS27. Both isolate the server-owned
        // Latin name from the Arabic sentence and close it with PDI; neither may be stripped.
        XCTAssertTrue(["البحث في \u{2066}Finishing\u{2069}", "البحث في \u{2068}Finishing\u{2069}"].contains(mixedDirection))
        do {
            _ = try DiscussionSearchRequest(query: "xy", scope: .all, page: 1, settings: settings(), catalog: [], validationLocale: arabic)
            XCTFail("Must validate original term")
        } catch let SearchFailure.input(message) { XCTAssertTrue(message.contains("أحرف")) }
    }

    func testSearchResponsesCannotEnterTheTransportCache() async throws {
        let session = URLSession(configuration: .ephemeral)
        let task = session.dataTask(with: URL(string: "https://cache.example/forum/search.json?q=fixture")!)
        let response = try XCTUnwrap(HTTPURLResponse(url: task.originalRequest!.url!, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: ["Cache-Control":"max-age=60"]))
        let proposed = CachedURLResponse(response: response, data: Data(success.utf8))
        let checked = expectation(description: "Search response is not cacheable")
        SameOriginDelegate().urlSession(session, dataTask: task, willCacheResponse: proposed) { cached in
            XCTAssertNil(cached); checked.fulfill()
        }
        let checkedResult = await XCTWaiter.fulfillment(of: [checked], timeout: 1)
        XCTAssertEqual(checkedResult, .completed)
        session.invalidateAndCancel()
    }

}

@MainActor private final class ControlledSearch: SearchRepository {
    struct Call { var request: DiscussionSearchRequest; var continuation: CheckedContinuation<DiscussionSearchPage, any Error> }
    var calls: [Call] = []
    var verificationError: RepositoryError?
    var verified: [String] = []
    func verifySearchViewer(username: String) async throws { verified.append(username); if let verificationError { throw verificationError } }
    func searchSettings() async throws -> SearchSettings { try .init(minimumTermLength: 3, locale: "en") }
    func search(_ request: DiscussionSearchRequest) async throws -> DiscussionSearchPage {
        try await withCheckedThrowingContinuation { calls.append(.init(request: request, continuation: $0)) }
    }
    func succeed(_ index: Int, hits: [DiscussionSearchHit], next: Int? = nil) { calls[index].continuation.resume(returning: DiscussionSearchPage(items: hits, nextPage: next)) }
    func fail(_ index: Int, _ error: any Error = SearchFailure.serverSearch) { calls[index].continuation.resume(throwing: error) }
}

@MainActor final class AdaptiveSearchStateTests: XCTestCase {
    private let viewer = SearchViewer(site: "https://fixture.example", account: .fixture, revision: 0, locale: "en")
    private func hit(_ id: Int) -> DiscussionSearchHit {
        .init(id: .init(id), discussion: DiscussionSummary(id: .init(id), title: "Topic", slug: "topic", categoryID: .init(45), excerpt: "", author: "fictional", replyCount: 0, activity: "", targetPostNumber: .init(1)), number: .init(1))
    }
    private func until(_ predicate: () -> Bool, file: StaticString = #filePath, line: UInt = #line) async {
        let clock = ContinuousClock(); let deadline = clock.now + .seconds(3)
        while !predicate(), clock.now < deadline { await Task.yield() }
        XCTAssertTrue(predicate(), file: file, line: line)
    }
    private func start(_ state: DiscussionSearchState, _ service: ControlledSearch, query: String = "Fomio", viewer: SearchViewer? = nil) {
        state.query = query
        state.schedule(service: service, viewer: viewer ?? self.viewer, scope: .all, catalog: [], debounce: .zero)
    }
    func testInitialFailureNeverLooksEmptyAndRetryIsCoalesced() async {
        let state = DiscussionSearchState(), service = ControlledSearch()
        start(state, service); await until { service.calls.count == 1 }
        service.fail(0); await until { !state.loading }
        XCTAssertFalse(state.showsNoResults); XCTAssertEqual(state.failure?.operation, .initial)
        state.retry(service: service, viewer: viewer, scope: .all, catalog: [])
        state.retry(service: service, viewer: viewer, scope: .all, catalog: [])
        await until { service.calls.count == 2 }
        service.succeed(1, hits: []); await until { !state.loading }
        XCTAssertTrue(state.showsNoResults); XCTAssertNil(state.failure)
        state.schedule(service: service, viewer: viewer, scope: .all, catalog: [], debounce: .zero)
        XCTAssertEqual(service.calls.count, 2)
    }
    func testRepeatedFailureGetsNewAnnouncementIdentityWithoutRemountRetry() async {
        let state = DiscussionSearchState(), service = ControlledSearch()
        start(state, service); await until { service.calls.count == 1 }
        service.fail(0); await until { !state.loading }
        let first = state.failure
        state.schedule(service: service, viewer: viewer, scope: .all, catalog: [], debounce: .zero)
        XCTAssertEqual(state.failure?.attemptID, first?.attemptID)
        XCTAssertEqual(service.calls.count, 1, "Remount preserves failure without another request or announcement identity")
        state.retry(service: service, viewer: viewer, scope: .all, catalog: [])
        await until { service.calls.count == 2 }
        service.fail(1); await until { !state.loading }
        XCTAssertEqual(state.failure?.message, first?.message)
        XCTAssertNotEqual(state.failure?.attemptID, first?.attemptID, "An identical failure from a new accepted attempt can be announced once")
    }
    func testPaginationFailureKeepsRowsAndRetriesExactFailedPage() async {
        let state = DiscussionSearchState(), service = ControlledSearch()
        start(state, service); await until { service.calls.count == 1 }
        service.succeed(0, hits: [hit(1)], next: 2); await until { !state.loading }
        state.anchor = .init(1)
        state.more(service: service, viewer: viewer, scope: .all, catalog: [])
        await until { service.calls.count == 2 }; service.fail(1); await until { !state.loading }
        XCTAssertEqual(state.hits.map(\.id), [PostID(1)]); XCTAssertEqual(state.anchor, PostID(1)); XCTAssertEqual(state.nextPage, 2)
        state.retry(service: service, viewer: viewer, scope: .all, catalog: [])
        await until { service.calls.count == 3 }; XCTAssertEqual(service.calls[2].request.page, 2)
        service.succeed(2, hits: [hit(1), hit(2)]); await until { !state.loading }
        XCTAssertEqual(state.hits.map(\.id), [PostID(1), PostID(2)])
    }
    func testFailedRefreshKeepsSnapshotUntilValidatedReplacement() async {
        let state = DiscussionSearchState(), service = ControlledSearch()
        start(state, service); await until { service.calls.count == 1 }
        service.succeed(0, hits: [hit(1)], next: 2); await until { !state.loading }
        state.refresh(service: service, viewer: viewer, scope: .all, catalog: [])
        await until { service.calls.count == 2 }; service.fail(1); await until { !state.loading }
        XCTAssertTrue(state.showingPreviousResults); XCTAssertEqual(state.hits.count, 1)
        state.more(service: service, viewer: viewer, scope: .all, catalog: [])
        XCTAssertEqual(service.calls.count, 2)
        state.retry(service: service, viewer: viewer, scope: .all, catalog: [])
        await until { service.calls.count == 3 }; XCTAssertEqual(service.calls[2].request.page, 1)
        service.succeed(2, hits: []); await until { !state.loading }
        XCTAssertTrue(state.showsNoResults); XCTAssertFalse(state.showingPreviousResults); XCTAssertNil(state.nextPage)
    }
    func testLateErrorAndCleanupCannotOverwriteNewerSearch() async {
        let state = DiscussionSearchState(), service = ControlledSearch()
        start(state, service); await until { service.calls.count == 1 }
        start(state, service, query: "New query"); await until { service.calls.count == 2 }
        service.fail(0); await Task.yield()
        XCTAssertTrue(state.loading); XCTAssertNil(state.failure)
        service.succeed(1, hits: [hit(2)]); await until { !state.loading }
        XCTAssertEqual(state.hits.map(\.id), [PostID(2)]); XCTAssertNil(state.failure)
    }
    func testOldAccountSuccessAndCancelledRequestCannotPublish() async {
        let state = DiscussionSearchState(), service = ControlledSearch()
        start(state, service); await until { service.calls.count == 1 }
        var guest = viewer; guest.account = .guest
        state.schedule(service: service, viewer: guest, scope: .all, catalog: [], debounce: .zero)
        await until { service.calls.count == 2 }
        service.succeed(0, hits: [hit(1)]); await Task.yield()
        XCTAssertTrue(state.hits.isEmpty); XCTAssertTrue(state.loading)
        state.cancel(); service.fail(1, URLError(.cancelled)); await Task.yield()
        XCTAssertFalse(state.loading); XCTAssertNil(state.failure); XCTAssertFalse(state.active); XCTAssertFalse(state.revealed)
    }
    func testAmbiguousMemberDenialRechecksIdentityWithoutGuestFallback() async {
        for expired in [false, true] {
            let state = DiscussionSearchState(), service = ControlledSearch()
            var member = viewer; member.username = "fictional-member"
            service.verificationError = expired ? .unauthorized : nil
            start(state, service, viewer: member); await until { service.calls.count == 1 }
            service.succeed(0, hits: [hit(1)], next: 2); await until { !state.loading }
            state.more(service: service, viewer: member, scope: .all, catalog: [])
            await until { service.calls.count == 2 }; service.fail(1, SearchFailure.accessDenied); await until { !state.loading }
            XCTAssertEqual(service.verified, ["fictional-member"])
            XCTAssertTrue(state.hits.isEmpty); XCTAssertNil(state.nextPage)
            XCTAssertEqual(state.failure?.needsSignIn, expired); XCTAssertEqual(service.calls.count, 2)
        }
    }
    func testPermissionChangeAcrossWindowsStopsAutomaticSearchResubmission() async throws {
        let fixture = FixtureService(), service = ControlledSearch()
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let windows = AppWindows(service: fixture, fixture: fixture, configuration: nil, store: DraftStore(directory: directory))
        let first = windows.makeWindow(), second = windows.makeWindow()
        await first.loadCommunities(); await second.loadCommunities()
        let a = try XCTUnwrap(first.tabs[.home]?.discussionSearch)
        let b = try XCTUnwrap(second.tabs[.home]?.discussionSearch)
        start(a, service, viewer: first.searchViewer); await until { service.calls.count == 1 }
        service.succeed(0, hits: [hit(1)], next: 2); await until { !a.loading }
        start(b, service, viewer: second.searchViewer); await until { service.calls.count == 2 }
        service.succeed(1, hits: [hit(2)]); await until { !b.loading }
        a.more(service: service, viewer: first.searchViewer, scope: .all, catalog: [])
        await until { service.calls.count == 3 }; service.fail(2, SearchFailure.accessDenied)
        await until { !a.loading }
        first.invalidateSearchAccess(in: .home)
        XCTAssertTrue(b.hits.isEmpty)
        // A second visible scene schedules when its viewer revision changes.
        b.schedule(service: service, viewer: second.searchViewer, scope: .all, catalog: [], debounce: .zero)
        await until { service.calls.count > 3 || !b.loading }
        XCTAssertEqual(service.calls.count, 3, "Another visible window must wait for explicit Retry after shared access invalidation")
        XCTAssertNotNil(b.failure)
        if service.calls.count > 3 { service.succeed(3, hits: []); await until { !b.loading }; return }
        b.retry(service: service, viewer: second.searchViewer, scope: .all, catalog: [])
        await until { service.calls.count == 4 }; service.fail(3, SearchFailure.accessDenied)
        await until { !b.loading }; second.invalidateSearchAccess(in: .home)
        a.schedule(service: service, viewer: first.searchViewer, scope: .all, catalog: [], debounce: .zero)
        await until { service.calls.count > 4 || !a.loading }
        XCTAssertEqual(service.calls.count, 4, "The second denial must not restart the first window either")
        XCTAssertEqual(a.query, "Fomio"); XCTAssertEqual(b.query, "Fomio")
        XCTAssertTrue(a.hits.isEmpty); XCTAssertTrue(b.hits.isEmpty)
        if service.calls.count > 4 { service.succeed(4, hits: []); await until { !a.loading }; return }
        a.retry(service: service, viewer: first.searchViewer, scope: .all, catalog: [])
        await until { service.calls.count == 5 }; service.succeed(4, hits: [hit(3)])
        await until { !a.loading }
        XCTAssertEqual(a.hits.map(\.id), [PostID(3)])
    }
    func testExplicitAccessFailureClearsOtherTabsWithoutAutomaticallyRetrying() async throws {
        let fixture = FixtureService(), service = ControlledSearch()
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let app = AppState(service: fixture, fixture: fixture, configuration: nil, store: DraftStore(directory: directory))
        await app.loadCommunities()
        let home = try XCTUnwrap(app.tabs[.home]), other = try XCTUnwrap(app.tabs[.communities])
        let state = home.discussionSearch
        var viewer = app.searchViewer; viewer.locale = "ar"
        start(state, service, viewer: viewer); await until { service.calls.count == 1 }
        service.succeed(0, hits: [hit(1)], next: 2); await until { !state.loading }
        start(other.discussionSearch, service, viewer: viewer); await until { service.calls.count == 2 }
        service.succeed(1, hits: [hit(2)]); await until { !other.discussionSearch.loading }
        _ = other.feed(key: "private")
        app.navigate(.discussion(.init(2), .init(1)), in: .communities)
        _ = app.discussionState(.discussion(.init(2), .init(1)), in: .communities)
        state.more(service: service, viewer: viewer, scope: .all, catalog: [])
        await until { service.calls.count == 3 }; service.fail(2, SearchFailure.accessDenied)
        await until { !state.loading }
        app.invalidateSearchAccess(in: .home)
        XCTAssertTrue(other.discussionSearch.hits.isEmpty); XCTAssertTrue(other.feeds.isEmpty); XCTAssertTrue(other.discussions.isEmpty)
        XCTAssertTrue(app.communities.isEmpty); XCTAssertFalse(app.communitiesLoaded)
        XCTAssertTrue(state.hits.isEmpty); XCTAssertNotNil(state.failure)
        XCTAssertEqual(state.failure?.operation, .initial)
        var updated = app.searchViewer; updated.locale = "ar"
        state.schedule(service: service, viewer: updated, scope: .all, catalog: [], debounce: .zero)
        await Task.yield()
        XCTAssertEqual(service.calls.count, 3, "Permission invalidation must retain recovery instead of automatic resubmission")
        XCTAssertNotNil(state.failure)
        app.invalidateSearchAccess(in: .home) // Consumed once, even if a parent renders again.
        XCTAssertEqual(app.searchViewer.revision, updated.revision)
    }
    func testGroupedFailureDoesNotInvalidatePermittedReadCaches() async throws {
        let fixture = FixtureService(), service = ControlledSearch()
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let app = AppState(service: fixture, fixture: fixture, configuration: nil, store: DraftStore(directory: directory))
        await app.loadCommunities()
        let home = try XCTUnwrap(app.tabs[.home])
        _ = home.feed(key: "retained")
        start(home.discussionSearch, service, viewer: app.searchViewer); await until { service.calls.count == 1 }
        service.fail(0); await until { !home.discussionSearch.loading }
        app.invalidateSearchAccess(in: .home)
        XCTAssertFalse(app.communities.isEmpty); XCTAssertNotNil(home.feeds["retained"])
        XCTAssertEqual(home.discussionSearch.failure?.kind, .serverSearch)
    }
    func testRateLimitBlocksRetryAndChangedQueryUntilServerDeadline() async {
        let state = DiscussionSearchState(), service = ControlledSearch()
        start(state, service); await until { service.calls.count == 1 }
        let deadline = Date().addingTimeInterval(60)
        service.fail(0, SearchFailure.rateLimited(deadline)); await until { !state.loading }
        XCTAssertEqual(state.failure?.retryAfter, deadline)
        state.retry(service: service, viewer: viewer, scope: .all, catalog: [])
        start(state, service, query: "Changed query")
        XCTAssertEqual(service.calls.count, 1); XCTAssertFalse(state.loading)
        XCTAssertEqual(state.failure?.retryAfter, deadline); XCTAssertFalse(state.showsNoResults)
    }


    func testReadingLayoutFollowsReviewedMinimaAndSlowerTextScaling() {
        XCTAssertEqual(ReadingLayout.scale(body: 17), 1, accuracy: 0.001)
        XCTAssertEqual(ReadingLayout.scale(body: 23), 1.15, accuracy: 0.001)
        XCTAssertEqual(ReadingLayout.scale(body: 34), 1.6, accuracy: 0.001)
        XCTAssertEqual(ReadingLayout.scale(body: 14), 1, accuracy: 0.001)
        let wide = ReadingLayout(width: 1180, scale: 1)
        XCTAssertTrue(wide.twoPanes); XCTAssertTrue(wide.sidebar)
        XCTAssertEqual(wide.listIdeal, 331.2, accuracy: 0.01)
        let large = ReadingLayout(width: 1180, scale: 1.15)
        XCTAssertTrue(large.twoPanes); XCTAssertFalse(large.sidebar)
        let accessibility = ReadingLayout(width: 1180, scale: 1.6)
        XCTAssertTrue(accessibility.twoPanes); XCTAssertFalse(accessibility.sidebar)
        XCTAssertTrue(ReadingLayout(width: 1366, scale: ReadingLayout.scale(body: 40)).twoPanes)
        XCTAssertFalse(ReadingLayout(width: 466, scale: 1).twoPanes)
        XCTAssertTrue(ReadingLayout(width: 980, scale: 1).twoPanes)
        XCTAssertFalse(ReadingLayout(width: 980, scale: 1).sidebar)
    }
    func testKeptReplyIsOfferedOnItsTopicAndReplyContinuesIt() async throws {
        let fixture = FixtureService()
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let app = AppState(service: fixture, fixture: fixture, configuration: nil, store: DraftStore(directory: directory))
        app.username = FixtureService.member
        let post = try await fixture.context(topic: TopicID(4182), number: PostNumber(1), focused: true).target.post
        var draft = Draft(account: app.account, intent: .reply(topic: post.topicID, parent: post.number)); draft.body = "Kept writing"
        try app.draftStore.save(draft)
        XCTAssertEqual(app.keptReplies(topic: post.topicID).map(\.id), [draft.id])
        XCTAssertTrue(app.keptReplies(topic: TopicID(15)).isEmpty)
        app.reply(to: post)
        for _ in 0..<50 where app.composer == nil { await Task.yield() }
        XCTAssertEqual(app.composer?.draft.id, draft.id)
        XCTAssertEqual(app.composer?.draft.body, "Kept writing")
        XCTAssertTrue(app.keptReplies(topic: post.topicID).isEmpty, "An open draft is not offered again")
        XCTAssertEqual(try app.draftStore.list(account: app.account).count, 1)
    }
    func testScopeTopicCountsAddVisibleChildrenAndNeedEveryCount() async throws {
        let fixture = FixtureService()
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let app = AppState(service: fixture, fixture: fixture, configuration: nil, store: DraftStore(directory: directory))
        await app.loadCommunities()
        let own = { (id: Int) in fixture.summaries.filter { $0.categoryID == CategoryID(id) }.count }
        XCTAssertEqual(app.topicCount(.category(CategoryID(1))), [1, 4, 2, 3, 9].map(own).reduce(0, +))
        XCTAssertEqual(app.topicCount(.category(CategoryID(9))), own(9))
        XCTAssertEqual(app.topicCount(.all), [1, 4, 2, 3, 9, 5, 6, 7, 8].map(own).reduce(0, +), "Restricted communities are not counted")
        app.communities[0].topicCount = nil
        XCTAssertNil(app.topicCount(.all), "A missing count is not shown as a smaller total")
    }
}
