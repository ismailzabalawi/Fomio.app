import Foundation
import Observation
import Synchronization

/// Development-only (`--media-recovery`) image server for fictional topic media. `fomio-fixture-media://media/<file>`
/// reads `<file>` from the fixture media folder: present files return 200 with the JPEG, missing files 404.
/// Every request is counted per file and never cached, so UI tests can tell how many times the image loader
/// actually asked for each image. Fixture responses are not evidence about any deployed media server.
final class FixtureMediaURLProtocol: URLProtocol {
    static let scheme = "fomio-fixture-media"
    nonisolated(unsafe) static var folder = FileManager.default.temporaryDirectory.appendingPathComponent("fomio-fixture-media", isDirectory: true)
    static let counts = Mutex<[String: Int]>([:])
    static func url(_ file: String) -> URL { URL(string: "\(scheme)://media/\(file)")! }
    static func file(for url: URL) -> URL { folder.appendingPathComponent(url.lastPathComponent) }

    override class func canInit(with request: URLRequest) -> Bool { request.url?.scheme == scheme }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        guard let url = request.url else { return }
        let name = url.lastPathComponent
        Self.counts.withLock { $0[name, default: 0] += 1 }
        Task { @MainActor in FixtureMediaLog.shared.record(name) }
        let data = try? Data(contentsOf: Self.file(for: url))
        let response = HTTPURLResponse(url: url, statusCode: data == nil ? 404 : 200, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": data == nil ? "text/plain" : "image/jpeg", "Cache-Control": "no-store"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data ?? Data())
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

/// Observable mirror of the request counts for the Debug fixture banner's hidden test readout.
@MainActor @Observable final class FixtureMediaLog {
    static let shared = FixtureMediaLog()
    private(set) var counts: [String: Int] = [:]
    func record(_ name: String) { counts[name, default: 0] += 1 }
    /// "missing-original.jpg=1;replacement.jpg=1;restored.jpg=2"
    var summary: String { counts.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: ";") }
}
