import Foundation

public enum TextSource: String, Codable, CaseIterable, Sendable {
    case accessibility
    case ocr
    case synthetic
}

public enum CaptureTrigger: String, Codable, CaseIterable, Sendable {
    case appSwitch = "app_switch"
    case focusChange = "focus_change"
    case click
    case typingPause = "typing_pause"
    case scrollStop = "scroll_stop"
    case clipboard
    case idle
    case manual
}

public struct CaptureMetadata: Sendable {
    public let appName: String
    public let windowTitle: String?
    public let bundleID: String?
    public let displayID: String?

    public init(appName: String, windowTitle: String?, bundleID: String?, displayID: String?) {
        self.appName = appName
        self.windowTitle = windowTitle
        self.bundleID = bundleID
        self.displayID = displayID
    }
}

public struct ExtractedText: Sendable {
    public let text: String
    public let source: TextSource
    public let metadata: CaptureMetadata

    public init(text: String, source: TextSource, metadata: CaptureMetadata) {
        self.text = text
        self.source = source
        self.metadata = metadata
    }
}

public struct CaptureRecord: Sendable {
    public let id: Int64?
    public let timestamp: Date
    public let appName: String
    public let windowTitle: String?
    public let bundleID: String?
    public let source: TextSource
    public let trigger: CaptureTrigger
    public let displayID: String?
    public let textHash: String
    public let textLength: Int
    public let textContent: String

    public init(
        id: Int64? = nil,
        timestamp: Date,
        appName: String,
        windowTitle: String?,
        bundleID: String?,
        source: TextSource,
        trigger: CaptureTrigger,
        displayID: String?,
        textHash: String,
        textLength: Int,
        textContent: String
    ) {
        self.id = id
        self.timestamp = timestamp
        self.appName = appName
        self.windowTitle = windowTitle
        self.bundleID = bundleID
        self.source = source
        self.trigger = trigger
        self.displayID = displayID
        self.textHash = textHash
        self.textLength = textLength
        self.textContent = textContent
    }
}

public struct SearchResult: Sendable {
    public let id: Int64
    public let timestamp: Date
    public let appName: String
    public let windowTitle: String?
    public let bundleID: String?
    public let source: TextSource
    public let trigger: CaptureTrigger
    public let snippet: String

    public init(
        id: Int64,
        timestamp: Date,
        appName: String,
        windowTitle: String?,
        bundleID: String?,
        source: TextSource,
        trigger: CaptureTrigger,
        snippet: String
    ) {
        self.id = id
        self.timestamp = timestamp
        self.appName = appName
        self.windowTitle = windowTitle
        self.bundleID = bundleID
        self.source = source
        self.trigger = trigger
        self.snippet = snippet
    }
}

public struct StoreStatus: Sendable {
    public let recordCount: Int
    public let lastCaptureAt: Date?
    public let databaseBytes: Int64

    public init(recordCount: Int, lastCaptureAt: Date?, databaseBytes: Int64) {
        self.recordCount = recordCount
        self.lastCaptureAt = lastCaptureAt
        self.databaseBytes = databaseBytes
    }
}

public enum CaptureOutcome: Sendable {
    case stored(CaptureRecord)
    case skippedDuplicate
    case skippedNoText
}
