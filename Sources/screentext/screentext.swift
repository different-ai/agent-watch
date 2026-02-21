import Foundation
import ScreenTextKit

@MainActor
@main
struct ScreenTextCLI {
    static func main() {
        do {
            try run(arguments: Array(CommandLine.arguments.dropFirst()))
        } catch {
            fputs("error: \(error)\n", stderr)
            exit(1)
        }
    }

    private static func run(arguments: [String]) throws {
        guard let command = arguments.first else {
            printUsage()
            return
        }

        let subArgs = Array(arguments.dropFirst())
        let paths = ScreenTextPaths()

        switch command {
        case "help", "--help", "-h":
            printUsage()
        case "doctor":
            try runDoctor()
        case "install":
            try runInstall(paths: paths)
        case "uninstall":
            try runUninstall(paths: paths, arguments: subArgs)
        case "status":
            try runStatus(paths: paths)
        case "capture-once":
            try runCaptureOnce(paths: paths)
        case "daemon":
            try runDaemon(paths: paths)
        case "ingest":
            try runIngest(paths: paths, arguments: subArgs)
        case "search":
            try runSearch(paths: paths, arguments: subArgs)
        case "purge":
            try runPurge(paths: paths, arguments: subArgs)
        case "config":
            try runConfig(paths: paths, arguments: subArgs)
        default:
            throw CLIError.invalidCommand(command)
        }
    }

    private static func runDoctor() throws {
        let snapshot = PermissionDoctor.snapshot()

        print("Accessibility: \(snapshot.accessibilityGranted ? "granted" : "denied")")
        print("Screen recording: \(snapshot.screenRecordingGranted ? "granted" : "denied")")
    }

    private static func runInstall(paths: ScreenTextPaths) throws {
        let executablePath = URL(fileURLWithPath: CommandLine.arguments[0]).path
        let manager = LaunchAgentManager()

        try paths.ensureBaseDirectory()
        try manager.install(executablePath: executablePath, paths: paths)

        print("Installed launch agent: \(manager.label)")
        print("Data directory: \(paths.baseDirectory.path)")
    }

    private static func runUninstall(paths: ScreenTextPaths, arguments: [String]) throws {
        let options = try ParsedOptions(arguments: arguments)
        let deleteData = options.flags.contains("delete-data")

        let manager = LaunchAgentManager()
        try manager.uninstall(deleteData: deleteData, paths: paths)

        print("Uninstalled launch agent: \(manager.label)")
        if deleteData {
            print("Removed data directory: \(paths.baseDirectory.path)")
        }
    }

    private static func runStatus(paths: ScreenTextPaths) throws {
        let store = try SQLiteStore(paths: paths)
        let status = try store.status()
        let snapshot = PermissionDoctor.snapshot()

        print("Data directory: \(paths.baseDirectory.path)")
        print("Database: \(paths.databaseURL.path)")
        print("Records: \(status.recordCount)")
        if let lastCaptureAt = status.lastCaptureAt {
            print("Last capture: \(isoString(lastCaptureAt))")
        } else {
            print("Last capture: none")
        }
        print("Database bytes: \(status.databaseBytes)")
        print("Accessibility: \(snapshot.accessibilityGranted ? "granted" : "denied")")
        print("Screen recording: \(snapshot.screenRecordingGranted ? "granted" : "denied")")
    }

    private static func runCaptureOnce(paths: ScreenTextPaths) throws {
        let config = try ScreenTextConfiguration.loadOrCreate(paths: paths)
        let store = try SQLiteStore(paths: paths)
        let extractor = NativeTextExtractor(
            minimumAccessibilityChars: config.minimumAccessibilityChars,
            ocrEnabled: config.ocrEnabled
        )

        let pipeline = CapturePipeline(
            store: store,
            extractor: extractor,
            duplicateWindowSeconds: TimeInterval(config.duplicateWindowSeconds)
        )

        let outcome = try pipeline.capture(trigger: .manual)
        switch outcome {
        case .stored(let record):
            print("Stored capture for \(record.appName) (\(record.source.rawValue))")
        case .skippedDuplicate:
            print("Skipped duplicate capture")
        case .skippedNoText:
            print("No text captured")
        }
    }

    private static func runDaemon(paths: ScreenTextPaths) throws {
        let config = try ScreenTextConfiguration.loadOrCreate(paths: paths)
        let store = try SQLiteStore(paths: paths)
        let extractor = NativeTextExtractor(
            minimumAccessibilityChars: config.minimumAccessibilityChars,
            ocrEnabled: config.ocrEnabled
        )

        let pipeline = CapturePipeline(
            store: store,
            extractor: extractor,
            duplicateWindowSeconds: TimeInterval(config.duplicateWindowSeconds)
        )

        let daemon = DaemonRunner(pipeline: pipeline, idleInterval: TimeInterval(config.idleGapSeconds))
        _ = daemon.run()
    }

    private static func runIngest(paths: ScreenTextPaths, arguments: [String]) throws {
        let options = try ParsedOptions(arguments: arguments)
        let text = try options.requiredValue(for: "text")

        let appName = options.values["app"] ?? "Manual"
        let windowTitle = options.values["window"]
        let bundleID = options.values["bundle-id"]
        let source = TextSource(rawValue: options.values["source"] ?? "synthetic") ?? .synthetic
        let trigger = CaptureTrigger(rawValue: options.values["trigger"] ?? "manual") ?? .manual

        let record = CaptureRecord(
            timestamp: Date(),
            appName: appName,
            windowTitle: windowTitle,
            bundleID: bundleID,
            source: source,
            trigger: trigger,
            displayID: options.values["display-id"],
            textHash: ScreenTextHasher.sha256(text),
            textLength: text.count,
            textContent: text
        )

        let store = try SQLiteStore(paths: paths)
        try store.insert(record)

        print("Stored synthetic capture for \(appName)")
    }

    private static func runSearch(paths: ScreenTextPaths, arguments: [String]) throws {
        guard let query = arguments.first else {
            throw CLIError.message("search requires a query")
        }

        let options = try ParsedOptions(arguments: Array(arguments.dropFirst()))
        let limit = Int(options.values["limit"] ?? "20") ?? 20
        let appName = options.values["app"]

        let store = try SQLiteStore(paths: paths)
        let results = try store.search(query: query, limit: limit, appName: appName)

        if results.isEmpty {
            print("No results.")
            return
        }

        for result in results {
            let window = result.windowTitle ?? "(no window)"
            print("[\(isoString(result.timestamp))] \(result.appName) | \(window) | \(result.source.rawValue)")
            print(result.snippet)
            print("---")
        }
    }

    private static func runPurge(paths: ScreenTextPaths, arguments: [String]) throws {
        let options = try ParsedOptions(arguments: arguments)
        let raw = try options.requiredValue(for: "older-than")
        let days = try parseDays(raw)

        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let store = try SQLiteStore(paths: paths)
        let deleted = try store.purge(olderThan: cutoff)

        print("Deleted \(deleted) records older than \(days)d")
    }

    private static func runConfig(paths: ScreenTextPaths, arguments: [String]) throws {
        guard let subcommand = arguments.first else {
            throw CLIError.message("config requires show or set")
        }

        switch subcommand {
        case "show":
            let config = try ScreenTextConfiguration.loadOrCreate(paths: paths)
            let data = try JSONEncoder.pretty.encode(config)
            print(String(data: data, encoding: .utf8) ?? "{}")
        case "set":
            guard arguments.count >= 3 else {
                throw CLIError.message("config set requires <key> <value>")
            }

            let key = arguments[1]
            let value = arguments[2]

            var config = try ScreenTextConfiguration.loadOrCreate(paths: paths)
            try config.set(key: key, value: value)
            try config.save(paths: paths)

            print("Updated config \(key)=\(value)")
        default:
            throw CLIError.message("config requires show or set")
        }
    }

    private static func parseDays(_ raw: String) throws -> Int {
        let normalized = raw.lowercased().hasSuffix("d") ? String(raw.dropLast()) : raw
        guard let days = Int(normalized), days >= 0 else {
            throw CLIError.message("invalid day value: \(raw)")
        }
        return days
    }

    private static func isoString(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }

    private static func printUsage() {
        print(
            """
            screentext - Swift-native macOS text memory

            Commands:
              help
              doctor
              install
              uninstall [--delete-data]
              status
              capture-once
              daemon
              ingest --text <value> [--app <name>] [--window <title>] [--source <accessibility|ocr|synthetic>] [--trigger <manual|app_switch|...>]
              search <query> [--limit <n>] [--app <name>]
              purge --older-than <Nd>
              config show
              config set <key> <value>

            Environment:
              SCREENTEXT_DATA_DIR  Override default data directory.
            """
        )
    }
}

private struct ParsedOptions {
    var values: [String: String] = [:]
    var flags: Set<String> = []

    init(arguments: [String]) throws {
        var index = 0
        while index < arguments.count {
            let token = arguments[index]
            guard token.hasPrefix("--") else {
                throw CLIError.message("unexpected argument: \(token)")
            }

            let key = String(token.dropFirst(2))
            let next = index + 1 < arguments.count ? arguments[index + 1] : nil

            if let next, !next.hasPrefix("--") {
                values[key] = next
                index += 2
            } else {
                flags.insert(key)
                index += 1
            }
        }
    }

    func requiredValue(for key: String) throws -> String {
        guard let value = values[key], !value.isEmpty else {
            throw CLIError.message("missing required option --\(key)")
        }
        return value
    }
}

private enum CLIError: Error, CustomStringConvertible {
    case invalidCommand(String)
    case message(String)

    var description: String {
        switch self {
        case .invalidCommand(let command):
            return "unknown command: \(command)"
        case .message(let message):
            return message
        }
    }
}
