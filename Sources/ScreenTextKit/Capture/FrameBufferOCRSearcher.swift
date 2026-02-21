import Foundation

public struct FrameOCRSearchHit: Sendable {
    public let timestamp: Date
    public let framePath: String
    public let snippet: String

    public init(timestamp: Date, framePath: String, snippet: String) {
        self.timestamp = timestamp
        self.framePath = framePath
        self.snippet = snippet
    }
}

public final class FrameBufferOCRSearcher {
    private let frameBufferStore: FrameBufferStore
    private let ocrExtractor: OCRTextExtractor

    public init(frameBufferStore: FrameBufferStore, ocrExtractor: OCRTextExtractor = OCRTextExtractor()) {
        self.frameBufferStore = frameBufferStore
        self.ocrExtractor = ocrExtractor
    }

    public func search(query: String, withinSeconds: Int, limit: Int) throws -> [FrameOCRSearchHit] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedQuery.isEmpty else {
            return []
        }

        let frames = frameBufferStore.recentFrames(within: withinSeconds, limit: 200)
        var hits: [FrameOCRSearchHit] = []

        for frameURL in frames {
            if hits.count >= limit {
                break
            }

            guard let text = try ocrExtractor.extractText(fromImageURL: frameURL) else {
                continue
            }

            guard text.localizedCaseInsensitiveContains(normalizedQuery) else {
                continue
            }

            let timestamp = frameURLModificationDate(frameURL) ?? Date()
            let snippet = snippetAroundMatch(text: text, query: normalizedQuery)

            hits.append(
                FrameOCRSearchHit(
                    timestamp: timestamp,
                    framePath: frameURL.path,
                    snippet: snippet
                )
            )
        }

        return hits.sorted { $0.timestamp > $1.timestamp }
    }

    private func frameURLModificationDate(_ url: URL) -> Date? {
        let values = try? url.resourceValues(forKeys: [.contentModificationDateKey])
        return values?.contentModificationDate
    }

    private func snippetAroundMatch(text: String, query: String) -> String {
        let lowerText = text.lowercased()
        let lowerQuery = query.lowercased()

        guard let range = lowerText.range(of: lowerQuery) else {
            return String(text.prefix(220))
        }

        let matchStart = lowerText.distance(from: lowerText.startIndex, to: range.lowerBound)
        let start = max(0, matchStart - 80)
        let end = min(lowerText.count, matchStart + lowerQuery.count + 120)

        let startIndex = text.index(text.startIndex, offsetBy: start)
        let endIndex = text.index(text.startIndex, offsetBy: end)

        return text[startIndex..<endIndex].trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
