import Foundation
import Testing
@testable import ScreenTextKit

struct ConfigurationTests {
    @Test
    func defaultsPreferLowCpuMode() {
        let config = ScreenTextConfiguration.default
        #expect(config.retentionDays == 14)
        #expect(config.ocrEnabled == false)
        #expect(config.idleGapSeconds == 30)
        #expect(config.frameBufferEnabled == true)
        #expect(config.frameBufferIntervalSeconds == 5)
        #expect(config.frameBufferRetentionSeconds == 120)
    }

    @Test
    func setAcceptsFrameBufferKeys() throws {
        var config = ScreenTextConfiguration.default

        try config.set(key: "frame_buffer_enabled", value: "false")
        try config.set(key: "frame_buffer_interval_seconds", value: "8")
        try config.set(key: "frame_buffer_retention_seconds", value: "180")

        #expect(config.frameBufferEnabled == false)
        #expect(config.frameBufferIntervalSeconds == 8)
        #expect(config.frameBufferRetentionSeconds == 180)
    }

    @Test
    func loadOrCreateUpgradesLegacyConfig() throws {
        let paths = try temporaryPaths(testName: "config-upgrade")
        try paths.ensureBaseDirectory()

        let legacyConfig: [String: Any] = [
            "retentionDays": 30,
            "maxDatabaseSizeMB": 200,
            "idleGapSeconds": 30,
            "activeGapSeconds": 10,
            "minCaptureIntervalMS": 200,
            "ocrEnabled": true,
            "minimumAccessibilityChars": 12,
            "duplicateWindowSeconds": 2,
            "ignoredApps": [],
        ]

        let data = try JSONSerialization.data(withJSONObject: legacyConfig, options: [.sortedKeys])
        try data.write(to: paths.configURL, options: .atomic)

        let loaded = try ScreenTextConfiguration.loadOrCreate(paths: paths)
        #expect(loaded.ocrEnabled == true)
        #expect(loaded.frameBufferEnabled == true)
        #expect(loaded.frameBufferIntervalSeconds == 5)
        #expect(loaded.frameBufferRetentionSeconds == 120)
    }
}

private func temporaryPaths(testName: String) throws -> ScreenTextPaths {
    let url = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        .appendingPathComponent("agent-watch-tests", isDirectory: true)
        .appendingPathComponent(testName + "-" + UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return ScreenTextPaths(baseDirectoryOverride: url)
}
