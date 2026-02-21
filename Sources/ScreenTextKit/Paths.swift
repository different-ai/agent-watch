import Foundation

public struct ScreenTextPaths: Sendable {
    public let baseDirectory: URL
    public let databaseURL: URL
    public let configURL: URL
    public let logsDirectory: URL

    public init(baseDirectoryOverride: URL? = nil, environment: [String: String] = ProcessInfo.processInfo.environment) {
        if let override = baseDirectoryOverride {
            baseDirectory = override
        } else if let envDir = environment["AGENT_WATCH_DATA_DIR"], !envDir.isEmpty {
            baseDirectory = URL(fileURLWithPath: envDir, isDirectory: true)
        } else if let envDir = environment["SCREENTEXT_DATA_DIR"], !envDir.isEmpty {
            baseDirectory = URL(fileURLWithPath: envDir, isDirectory: true)
        } else {
            let home = FileManager.default.homeDirectoryForCurrentUser
            baseDirectory = home
                .appendingPathComponent("Library", isDirectory: true)
                .appendingPathComponent("Application Support", isDirectory: true)
                .appendingPathComponent("AgentWatch", isDirectory: true)
        }

        databaseURL = baseDirectory.appendingPathComponent("agent_watch.db", isDirectory: false)
        configURL = baseDirectory.appendingPathComponent("config.json", isDirectory: false)
        logsDirectory = baseDirectory.appendingPathComponent("logs", isDirectory: true)
    }

    public func ensureBaseDirectory() throws {
        try FileManager.default.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: logsDirectory, withIntermediateDirectories: true)
    }
}
