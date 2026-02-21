import Foundation

struct ScreenTextAPIResponder {
    private let store: SQLiteStore
    private let permissions: () -> PermissionSnapshot
    private let screenProbe: () -> ScreenRecordingProbe

    init(
        store: SQLiteStore,
        permissions: @escaping () -> PermissionSnapshot,
        screenProbe: @escaping () -> ScreenRecordingProbe = PermissionDoctor.probeScreenRecording
    ) {
        self.store = store
        self.permissions = permissions
        self.screenProbe = screenProbe
    }

    func respond(to request: HTTPRequest) -> HTTPResponse {
        guard request.method == "GET" else {
            return json(statusCode: 405, reason: "Method Not Allowed", payload: APIErrorPayload(error: "method_not_allowed", message: "Only GET is supported."))
        }

        do {
            switch request.path {
            case "/", "/docs", "/openapi":
                return json(
                    statusCode: 200,
                    reason: "OK",
                    payload: DiscoveryPayload(
                        service: "agent-watch",
                        version: "0.1.0",
                        openapi: "/openapi.yaml",
                        routes: [
                            "/",
                            "/health",
                            "/status",
                            "/search",
                            "/screen-recording/probe",
                            "/openapi.yaml",
                        ]
                    )
                )

            case "/openapi.yaml":
                return HTTPResponse(
                    statusCode: 200,
                    reasonPhrase: "OK",
                    body: Data(OpenAPISpec.yaml.utf8),
                    contentType: "application/yaml; charset=utf-8"
                )

            case "/health":
                return json(statusCode: 200, reason: "OK", payload: HealthPayload(ok: true, service: "agent-watch", version: "0.1.0"))

            case "/status":
                let status = try store.status()
                let snapshot = permissions()
                return json(
                    statusCode: 200,
                    reason: "OK",
                    payload: StatusPayload(
                        recordCount: status.recordCount,
                        lastCaptureAt: status.lastCaptureAt,
                        databaseBytes: status.databaseBytes,
                        accessibilityGranted: snapshot.accessibilityGranted,
                        screenRecordingGranted: snapshot.screenRecordingGranted
                    )
                )

            case "/search":
                guard let query = request.query["q"], !query.isEmpty else {
                    return json(
                        statusCode: 400,
                        reason: "Bad Request",
                        payload: APIErrorPayload(error: "missing_query", message: "Expected query parameter 'q'.")
                    )
                }

                let limit: Int
                if let rawLimit = request.query["limit"], let parsed = Int(rawLimit) {
                    limit = min(max(parsed, 1), 200)
                } else {
                    limit = 20
                }

                let app = request.query["app"]
                let results = try store.search(query: query, limit: limit, appName: app)
                let payload = SearchPayload(
                    query: query,
                    count: results.count,
                    results: results.map {
                        SearchResultPayload(
                            id: $0.id,
                            timestamp: $0.timestamp,
                            appName: $0.appName,
                            windowTitle: $0.windowTitle,
                            bundleID: $0.bundleID,
                            source: $0.source.rawValue,
                            trigger: $0.trigger.rawValue,
                            snippet: $0.snippet
                        )
                    }
                )

                return json(statusCode: 200, reason: "OK", payload: payload)

            case "/screen-recording/probe":
                let probe = screenProbe()
                return json(
                    statusCode: 200,
                    reason: "OK",
                    payload: ScreenRecordingProbePayload(
                        granted: probe.granted,
                        width: probe.width,
                        height: probe.height,
                        byteCount: probe.byteCount,
                        sampleHash: probe.sampleHash
                    )
                )

            default:
                return json(
                    statusCode: 404,
                    reason: "Not Found",
                    payload: APIErrorPayload(error: "not_found", message: "Route not found.")
                )
            }
        } catch {
            return json(
                statusCode: 500,
                reason: "Internal Server Error",
                payload: APIErrorPayload(error: "internal_error", message: String(describing: error))
            )
        }
    }

    private func json<T: Encodable>(statusCode: Int, reason: String, payload: T) -> HTTPResponse {
        HTTPResponse(statusCode: statusCode, reasonPhrase: reason, body: JSONBody.encode(payload))
    }
}

private struct HealthPayload: Codable {
    let ok: Bool
    let service: String
    let version: String
}

private struct DiscoveryPayload: Codable {
    let service: String
    let version: String
    let openapi: String
    let routes: [String]
}

private struct StatusPayload: Codable {
    let recordCount: Int
    let lastCaptureAt: Date?
    let databaseBytes: Int64
    let accessibilityGranted: Bool
    let screenRecordingGranted: Bool
}

private struct SearchPayload: Codable {
    let query: String
    let count: Int
    let results: [SearchResultPayload]
}

private struct SearchResultPayload: Codable {
    let id: Int64
    let timestamp: Date
    let appName: String
    let windowTitle: String?
    let bundleID: String?
    let source: String
    let trigger: String
    let snippet: String
}

private struct ScreenRecordingProbePayload: Codable {
    let granted: Bool
    let width: Int
    let height: Int
    let byteCount: Int
    let sampleHash: String?
}

private struct APIErrorPayload: Codable {
    let error: String
    let message: String
}
