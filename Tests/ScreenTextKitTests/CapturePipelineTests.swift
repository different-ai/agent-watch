import Foundation
import Testing
@testable import ScreenTextKit

struct CapturePipelineTests {
    @Test
    func duplicateWindowSkipsRepeatedText() throws {
        let paths = try temporaryPaths(testName: "pipeline")
        let store = try SQLiteStore(paths: paths)

        var now = Date()
        let extractor = QueueExtractor(
            outputs: [
                ExtractedText(
                    text: "hello world",
                    source: .synthetic,
                    metadata: CaptureMetadata(appName: "Notes", windowTitle: "Doc", bundleID: "notes", displayID: "main")
                ),
                ExtractedText(
                    text: "hello world",
                    source: .synthetic,
                    metadata: CaptureMetadata(appName: "Notes", windowTitle: "Doc", bundleID: "notes", displayID: "main")
                ),
                ExtractedText(
                    text: "hello world updated",
                    source: .synthetic,
                    metadata: CaptureMetadata(appName: "Notes", windowTitle: "Doc", bundleID: "notes", displayID: "main")
                ),
            ]
        )

        let pipeline = CapturePipeline(
            store: store,
            extractor: extractor,
            duplicateWindowSeconds: 2,
            now: { now }
        )

        let first = try pipeline.capture(trigger: .manual)
        if case .stored = first {} else { #expect(Bool(false)) }

        now = now.addingTimeInterval(1)
        let second = try pipeline.capture(trigger: .manual)
        if case .skippedDuplicate = second {} else { #expect(Bool(false)) }

        now = now.addingTimeInterval(3)
        let third = try pipeline.capture(trigger: .manual)
        if case .stored = third {} else { #expect(Bool(false)) }

        let status = try store.status()
        #expect(status.recordCount == 2)
    }
}

private final class QueueExtractor: TextExtractor {
    private var outputs: [ExtractedText]

    init(outputs: [ExtractedText]) {
        self.outputs = outputs
    }

    func extract() throws -> ExtractedText? {
        guard !outputs.isEmpty else {
            return nil
        }
        return outputs.removeFirst()
    }
}

private func temporaryPaths(testName: String) throws -> ScreenTextPaths {
    let url = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        .appendingPathComponent("agent-watch-tests", isDirectory: true)
        .appendingPathComponent(testName + "-" + UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return ScreenTextPaths(baseDirectoryOverride: url)
}
