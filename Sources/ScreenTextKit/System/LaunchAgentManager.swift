import Darwin
import Foundation

public enum LaunchAgentError: Error, CustomStringConvertible {
    case launchctl(String)

    public var description: String {
        switch self {
        case .launchctl(let message):
            return "launchctl failed: \(message)"
        }
    }
}

public final class LaunchAgentManager {
    public let label = "com.differentai.screentext"

    public init() {}

    public func install(executablePath: String, paths: ScreenTextPaths) throws {
        let plistURL = launchAgentPlistURL()
        let plistContent = plistTemplate(executablePath: executablePath, dataDirectory: paths.baseDirectory.path)

        try FileManager.default.createDirectory(at: plistURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try plistContent.write(to: plistURL, atomically: true, encoding: .utf8)

        _ = try? runLaunchctl(["bootout", "gui/\(getuid())", plistURL.path])
        _ = try runLaunchctl(["bootstrap", "gui/\(getuid())", plistURL.path])
    }

    public func uninstall(deleteData: Bool, paths: ScreenTextPaths) throws {
        let plistURL = launchAgentPlistURL()
        _ = try? runLaunchctl(["bootout", "gui/\(getuid())", plistURL.path])

        if FileManager.default.fileExists(atPath: plistURL.path) {
            try FileManager.default.removeItem(at: plistURL)
        }

        if deleteData, FileManager.default.fileExists(atPath: paths.baseDirectory.path) {
            try FileManager.default.removeItem(at: paths.baseDirectory)
        }
    }

    private func launchAgentPlistURL() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("LaunchAgents", isDirectory: true)
            .appendingPathComponent("\(label).plist", isDirectory: false)
    }

    private func plistTemplate(executablePath: String, dataDirectory: String) -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>\(label)</string>
            <key>ProgramArguments</key>
            <array>
                <string>\(executablePath)</string>
                <string>daemon</string>
            </array>
            <key>EnvironmentVariables</key>
            <dict>
                <key>SCREENTEXT_DATA_DIR</key>
                <string>\(dataDirectory)</string>
            </dict>
            <key>RunAtLoad</key>
            <true/>
            <key>KeepAlive</key>
            <true/>
            <key>StandardOutPath</key>
            <string>\(dataDirectory)/logs/daemon.out.log</string>
            <key>StandardErrorPath</key>
            <string>\(dataDirectory)/logs/daemon.err.log</string>
        </dict>
        </plist>
        """
    }

    @discardableResult
    private func runLaunchctl(_ arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = arguments

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: outputData, encoding: .utf8) ?? ""
        let error = String(data: errorData, encoding: .utf8) ?? ""

        guard process.terminationStatus == 0 else {
            throw LaunchAgentError.launchctl(error.isEmpty ? output : error)
        }

        return output
    }
}
