import Foundation
import Network
import os

public enum ScreenTextAPIServerError: Error, CustomStringConvertible {
    case invalidPort(Int)

    public var description: String {
        switch self {
        case .invalidPort(let value):
            return "Invalid port: \(value)"
        }
    }
}

public final class ScreenTextAPIServer: @unchecked Sendable {
    private let host: String
    private let port: Int
    private let responder: ScreenTextAPIResponder
    private let logger = Logger(subsystem: "com.differentai.screentext", category: "api")
    private let queue = DispatchQueue(label: "com.differentai.screentext.api")

    public init(host: String, port: Int, store: SQLiteStore) {
        self.host = host
        self.port = port
        responder = ScreenTextAPIResponder(store: store, permissions: PermissionDoctor.snapshot)
    }

    @MainActor
    public func run() throws -> Never {
        guard let nwPort = NWEndpoint.Port(rawValue: UInt16(port)) else {
            throw ScreenTextAPIServerError.invalidPort(port)
        }

        let parameters = NWParameters.tcp
        let listener = try NWListener(using: parameters, on: nwPort)

        if host == "127.0.0.1" || host == "localhost" {
            listener.newConnectionLimit = 64
        }

        listener.newConnectionHandler = { [weak self] connection in
            self?.handle(connection: connection)
        }

        listener.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                self?.logger.info("API listening on \(self?.host ?? "127.0.0.1", privacy: .public):\(self?.port ?? 0)")
            case .failed(let error):
                self?.logger.error("API listener failed: \(error.localizedDescription, privacy: .public)")
            default:
                break
            }
        }

        listener.start(queue: queue)

        print("API listening on http://\(host):\(port)")
        RunLoop.main.run()
        fatalError("API listener exited unexpectedly")
    }

    private func handle(connection: NWConnection) {
        connection.start(queue: queue)

        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, _, error in
            guard let self else {
                connection.cancel()
                return
            }

            if let error {
                self.logger.error("Receive error: \(error.localizedDescription, privacy: .public)")
                connection.cancel()
                return
            }

            guard let data,
                  let request = HTTPParser.parse(data)
            else {
                let response = HTTPResponse(
                    statusCode: 400,
                    reasonPhrase: "Bad Request",
                    body: JSONBody.encode([
                        "error": "bad_request",
                        "message": "Malformed HTTP request.",
                    ])
                )
                self.send(response: response, on: connection)
                return
            }

            let response = self.responder.respond(to: request)
            self.send(response: response, on: connection)
        }
    }

    private func send(response: HTTPResponse, on connection: NWConnection) {
        connection.send(content: response.serialized(), completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
}
