import Foundation
import Testing
@testable import ScreenTextKit

struct APITests {
    @Test
    func healthAndStatusRoutes() throws {
        let paths = try temporaryPaths(testName: "api-health")
        let store = try SQLiteStore(paths: paths)

        try store.insert(
            CaptureRecord(
                timestamp: Date(),
                appName: "Safari",
                windowTitle: "Docs",
                bundleID: "com.apple.Safari",
                source: .synthetic,
                trigger: .manual,
                displayID: "main",
                textHash: ScreenTextHasher.sha256("status payload line"),
                textLength: 19,
                textContent: "status payload line"
            )
        )

        let responder = ScreenTextAPIResponder(
            store: store,
            permissions: { PermissionSnapshot(accessibilityGranted: true, screenRecordingGranted: true) },
            screenProbe: { ScreenRecordingProbe(granted: true, width: 1728, height: 1117, byteCount: 1000, sampleHash: "abc") }
        )

        let health = responder.respond(to: HTTPRequest(method: "GET", path: "/health", query: [:]))
        #expect(health.statusCode == 200)
        let healthJSON = try parseObject(health.body)
        #expect((healthJSON["ok"] as? Bool) == true)
        #expect((healthJSON["service"] as? String) == "agent-watch")

        let status = responder.respond(to: HTTPRequest(method: "GET", path: "/status", query: [:]))
        #expect(status.statusCode == 200)
        let statusJSON = try parseObject(status.body)
        #expect((statusJSON["recordCount"] as? Int) == 1)
        #expect((statusJSON["screenRecordingGranted"] as? Bool) == true)

        let probe = responder.respond(to: HTTPRequest(method: "GET", path: "/screen-recording/probe", query: [:]))
        #expect(probe.statusCode == 200)
        let probeJSON = try parseObject(probe.body)
        #expect((probeJSON["granted"] as? Bool) == true)
        #expect((probeJSON["width"] as? Int) == 1728)
    }

    @Test
    func searchRouteAndValidation() throws {
        let paths = try temporaryPaths(testName: "api-search")
        let store = try SQLiteStore(paths: paths)

        try store.insert(
            CaptureRecord(
                timestamp: Date(),
                appName: "Terminal",
                windowTitle: "Build",
                bundleID: "com.apple.Terminal",
                source: .synthetic,
                trigger: .manual,
                displayID: "main",
                textHash: ScreenTextHasher.sha256("screen recording proof token"),
                textLength: 28,
                textContent: "screen recording proof token"
            )
        )

        let responder = ScreenTextAPIResponder(
            store: store,
            permissions: { PermissionSnapshot(accessibilityGranted: true, screenRecordingGranted: false) },
            screenProbe: { ScreenRecordingProbe(granted: false, width: 0, height: 0, byteCount: 0, sampleHash: nil) }
        )

        let search = responder.respond(
            to: HTTPRequest(method: "GET", path: "/search", query: ["q": "recording", "limit": "5"])
        )
        #expect(search.statusCode == 200)

        let searchJSON = try parseObject(search.body)
        #expect((searchJSON["count"] as? Int) == 1)

        let missing = responder.respond(to: HTTPRequest(method: "GET", path: "/search", query: [:]))
        #expect(missing.statusCode == 400)

        let wrongMethod = responder.respond(to: HTTPRequest(method: "POST", path: "/health", query: [:]))
        #expect(wrongMethod.statusCode == 405)
    }

    @Test
    func httpParserParsesRequestLineAndQuery() throws {
        let raw = Data("GET /search?q=invoice&limit=3 HTTP/1.1\r\nHost: localhost\r\n\r\n".utf8)
        let parsed = HTTPParser.parse(raw)
        #expect(parsed != nil)
        #expect(parsed?.method == "GET")
        #expect(parsed?.path == "/search")
        #expect(parsed?.query["q"] == "invoice")
        #expect(parsed?.query["limit"] == "3")
    }
}

private func parseObject(_ data: Data) throws -> [String: Any] {
    let object = try JSONSerialization.jsonObject(with: data)
    return object as? [String: Any] ?? [:]
}

private func temporaryPaths(testName: String) throws -> ScreenTextPaths {
    let url = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        .appendingPathComponent("agent-watch-tests", isDirectory: true)
        .appendingPathComponent(testName + "-" + UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return ScreenTextPaths(baseDirectoryOverride: url)
}
