import Foundation

struct HTTPRequest {
    let method: String
    let path: String
    let query: [String: String]
}

struct HTTPResponse {
    let statusCode: Int
    let reasonPhrase: String
    let body: Data
    let contentType: String

    init(statusCode: Int, reasonPhrase: String, body: Data, contentType: String = "application/json; charset=utf-8") {
        self.statusCode = statusCode
        self.reasonPhrase = reasonPhrase
        self.body = body
        self.contentType = contentType
    }

    func serialized() -> Data {
        var header = "HTTP/1.1 \(statusCode) \(reasonPhrase)\r\n"
        header += "Content-Type: \(contentType)\r\n"
        header += "Content-Length: \(body.count)\r\n"
        header += "Connection: close\r\n"
        header += "\r\n"

        var data = Data(header.utf8)
        data.append(body)
        return data
    }
}

enum HTTPParser {
    static func parse(_ data: Data) -> HTTPRequest? {
        guard let raw = String(data: data, encoding: .utf8) else {
            return nil
        }

        guard let requestLine = raw.components(separatedBy: "\r\n").first else {
            return nil
        }

        let parts = requestLine.split(separator: " ")
        guard parts.count >= 2 else {
            return nil
        }

        let method = String(parts[0]).uppercased()
        let target = String(parts[1])
        let components = URLComponents(string: "http://localhost\(target)")
        let path = components?.path ?? "/"

        var query: [String: String] = [:]
        for item in components?.queryItems ?? [] {
            query[item.name] = item.value ?? ""
        }

        return HTTPRequest(method: method, path: path, query: query)
    }
}

enum JSONBody {
    static func encode<T: Encodable>(_ value: T) -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return (try? encoder.encode(value)) ?? Data("{}".utf8)
    }
}
