import Foundation
import Observation

@MainActor @Observable final class DiscussionState {
    let route: Route
    let service: any CommunityService
    var page: DiscussionPage?
    var nodes: [PostID: Post] = [:]
    var roots: [PostID] = []
    var children: [PostID: [PostID]] = [:]
    var childNext: [PostID: Int] = [:]
    var childrenLoaded: Set<PostID> = []
    var expanded: Set<PostID> = []
    var loadingChildren: Set<PostID> = []
    var childErrors: [PostID: String] = [:]
    var loading = false
    var error: String?
    var errorKind: RepositoryError?
    var focus: FocusReason?
    var highlight: PostID?
    var anchor: PostID?
    var truncated = false
    var mutating: Set<PostID> = []
    var topicID: TopicID { switch route { case let .discussion(id, _), let .thread(id, _): id; default: .init(0) } }
    init(route: Route, service: any CommunityService) { self.route = route; self.service = service }
    func ingest(_ node: ThreadNode) {
        nodes[node.id] = node.post
        if !node.children.isEmpty {
            children[node.id] = node.children.map(\.id)
            for child in node.children { ingest(child) }
            if node.children.count >= node.post.childCount { childrenLoaded.insert(node.id) }
        }
    }
    func load(refresh: Bool = false) async {
        guard !loading else { return }; loading = true; defer { loading = false }
        do {
            let number: PostNumber?
            let focused: Bool
            switch route { case let .discussion(_, n): number = n; focused = false; case let .thread(_, n): number = n; focused = true; default: number = nil; focused = false }
            if let number {
                let context = try await service.context(topic: topicID, number: number, focused: focused)
                page = context.page; nodes[context.page.opening.id] = context.page.opening
                roots = []; ingest(context.target); highlight = context.target.id; truncated = context.truncated || context.ancestors.count > 2
                var previous: PostID?
                for ancestor in context.ancestors.suffix(2) {
                    nodes[ancestor.id] = ancestor
                    if let previous { children[previous] = [ancestor.id] } else { roots = [ancestor.id] }
                    expanded.insert(ancestor.id); previous = ancestor.id
                }
                if let previous { children[previous] = [context.target.id] } else { roots = context.target.post.number.rawValue == 1 ? [] : [context.target.id] }
                page?.nextPage = nil; anchor = context.target.id
            } else {
                let result = try await service.discussion(topicID, page: 0)
                page = result; nodes[result.opening.id] = result.opening; roots = result.roots.map(\.id); result.roots.forEach(ingest)
            }
            error = nil; errorKind = nil
        } catch is CancellationError {} catch { self.error = error.localizedDescription; errorKind = error as? RepositoryError }
    }
    var opening: Post? { page.flatMap { nodes[$0.opening.id] } }
    var highlighted: Post? { highlight.flatMap { nodes[$0] } }
    func moreRoots() async {
        guard !loading, let next = page?.nextPage else { return }
        loading = true; defer { loading = false }
        do { let result = try await service.discussion(topicID, page: next); result.roots.forEach(ingest); roots += result.roots.map(\.id).filter { !roots.contains($0) }; page?.nextPage = result.nextPage; error = nil }
        catch { self.error = error.localizedDescription }
    }
    func toggle(_ id: PostID, depth: Int) async {
        if expanded.contains(id) { expanded.remove(id); return }
        expanded.insert(id)
        if !childrenLoaded.contains(id) { await loadChildren(id, depth: depth, first: true) }
    }
    func loadChildren(_ id: PostID, depth: Int, first: Bool = false) async {
        guard !loadingChildren.contains(id), let post = nodes[id] else { return }
        loadingChildren.insert(id); defer { loadingChildren.remove(id) }
        do {
            let result = try await service.children(topic: topicID, parent: post.number, page: first ? 0 : childNext[id] ?? 0, depth: depth + 1)
            result.nodes.forEach(ingest)
            let existing = first ? [] : children[id, default: []]
            children[id] = existing + result.nodes.map(\.id).filter { !existing.contains($0) }
            childrenLoaded.insert(id); childNext[id] = result.nextPage; childErrors[id] = nil
        } catch { childErrors[id] = error.localizedDescription }
    }
    func act(_ id: PostID, bookmark: Bool) async throws {
        guard !mutating.contains(id), let post = nodes[id] else { return }
        mutating.insert(id); defer { mutating.remove(id) }
        nodes[id] = try await (bookmark ? service.bookmark(post) : service.like(post))
    }
}
