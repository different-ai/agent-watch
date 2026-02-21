import Foundation

public final class CapturePipeline {
    private let store: SQLiteStore
    private let extractor: TextExtractor
    private let duplicateWindowSeconds: TimeInterval
    private let now: () -> Date

    private var lastHash: String?
    private var lastAt: Date?

    public init(
        store: SQLiteStore,
        extractor: TextExtractor,
        duplicateWindowSeconds: TimeInterval,
        now: @escaping () -> Date = Date.init
    ) {
        self.store = store
        self.extractor = extractor
        self.duplicateWindowSeconds = duplicateWindowSeconds
        self.now = now
    }

    public func capture(trigger: CaptureTrigger) throws -> CaptureOutcome {
        guard let extracted = try extractor.extract() else {
            return .skippedNoText
        }

        let normalized = extracted.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            return .skippedNoText
        }

        let digest = ScreenTextHasher.sha256(normalized)
        let timestamp = now()

        if let previousHash = lastHash,
           let previousAt = lastAt,
           previousHash == digest,
           timestamp.timeIntervalSince(previousAt) <= duplicateWindowSeconds {
            return .skippedDuplicate
        }

        let record = CaptureRecord(
            timestamp: timestamp,
            appName: extracted.metadata.appName,
            windowTitle: extracted.metadata.windowTitle,
            bundleID: extracted.metadata.bundleID,
            source: extracted.source,
            trigger: trigger,
            displayID: extracted.metadata.displayID,
            textHash: digest,
            textLength: normalized.count,
            textContent: normalized
        )

        try store.insert(record)
        lastHash = digest
        lastAt = timestamp

        return .stored(record)
    }
}
