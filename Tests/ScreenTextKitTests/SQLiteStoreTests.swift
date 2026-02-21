import Foundation
import Testing
@testable import ScreenTextKit

struct SQLiteStoreTests {
    @Test
    func insertSearchAndStatus() throws {
        let paths = try temporaryPaths(testName: "insert-search")
        let store = try SQLiteStore(paths: paths)

        let record = CaptureRecord(
            timestamp: Date(),
            appName: "Safari",
            windowTitle: "Invoice",
            bundleID: "com.apple.Safari",
            source: .synthetic,
            trigger: .manual,
            displayID: "main",
            textHash: ScreenTextHasher.sha256("invoice number 4832"),
            textLength: 19,
            textContent: "invoice number 4832"
        )

        try store.insert(record)

        let results = try store.search(query: "invoice", limit: 10)
        #expect(results.count == 1)
        #expect(results[0].appName == "Safari")

        let status = try store.status()
        #expect(status.recordCount == 1)
        #expect(status.lastCaptureAt != nil)
    }

    @Test
    func purgeOldRecords() throws {
        let paths = try temporaryPaths(testName: "purge")
        let store = try SQLiteStore(paths: paths)

        let oldDate = Calendar.current.date(byAdding: .day, value: -5, to: Date()) ?? Date()
        let newDate = Date()

        let old = CaptureRecord(
            timestamp: oldDate,
            appName: "Terminal",
            windowTitle: "Old",
            bundleID: "com.apple.Terminal",
            source: .synthetic,
            trigger: .manual,
            displayID: "main",
            textHash: ScreenTextHasher.sha256("old line"),
            textLength: 8,
            textContent: "old line"
        )

        let current = CaptureRecord(
            timestamp: newDate,
            appName: "Terminal",
            windowTitle: "New",
            bundleID: "com.apple.Terminal",
            source: .synthetic,
            trigger: .manual,
            displayID: "main",
            textHash: ScreenTextHasher.sha256("new line"),
            textLength: 8,
            textContent: "new line"
        )

        try store.insert(old)
        try store.insert(current)

        let cutoff = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        let deleted = try store.purge(olderThan: cutoff)
        #expect(deleted == 1)

        let status = try store.status()
        #expect(status.recordCount == 1)
    }
}

private func temporaryPaths(testName: String) throws -> ScreenTextPaths {
    let url = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        .appendingPathComponent("agent-watch-tests", isDirectory: true)
        .appendingPathComponent(testName + "-" + UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return ScreenTextPaths(baseDirectoryOverride: url)
}
