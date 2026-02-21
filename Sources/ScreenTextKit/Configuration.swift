import Foundation

public struct ScreenTextConfiguration: Codable, Sendable {
    public var retentionDays: Int
    public var maxDatabaseSizeMB: Int
    public var idleGapSeconds: Int
    public var activeGapSeconds: Int
    public var minCaptureIntervalMS: Int
    public var ocrEnabled: Bool
    public var minimumAccessibilityChars: Int
    public var duplicateWindowSeconds: Int
    public var ignoredApps: [String]

    public static let `default` = ScreenTextConfiguration(
        retentionDays: 30,
        maxDatabaseSizeMB: 200,
        idleGapSeconds: 30,
        activeGapSeconds: 10,
        minCaptureIntervalMS: 200,
        ocrEnabled: true,
        minimumAccessibilityChars: 12,
        duplicateWindowSeconds: 2,
        ignoredApps: []
    )

    public static func loadOrCreate(paths: ScreenTextPaths) throws -> ScreenTextConfiguration {
        try paths.ensureBaseDirectory()

        if FileManager.default.fileExists(atPath: paths.configURL.path) {
            let data = try Data(contentsOf: paths.configURL)
            return try JSONDecoder().decode(ScreenTextConfiguration.self, from: data)
        }

        let config = ScreenTextConfiguration.default
        try config.save(paths: paths)
        return config
    }

    public func save(paths: ScreenTextPaths) throws {
        try paths.ensureBaseDirectory()
        let data = try JSONEncoder.pretty.encode(self)
        try data.write(to: paths.configURL, options: .atomic)
    }

    public mutating func set(key: String, value: String) throws {
        switch key {
        case "retention_days":
            retentionDays = try value.asInt(min: 1)
        case "max_db_size_mb":
            maxDatabaseSizeMB = try value.asInt(min: 50)
        case "idle_gap_seconds":
            idleGapSeconds = try value.asInt(min: 5)
        case "active_gap_seconds":
            activeGapSeconds = try value.asInt(min: 1)
        case "min_capture_interval_ms":
            minCaptureIntervalMS = try value.asInt(min: 100)
        case "ocr_enabled":
            ocrEnabled = try value.asBool()
        case "minimum_accessibility_chars":
            minimumAccessibilityChars = try value.asInt(min: 1)
        case "duplicate_window_seconds":
            duplicateWindowSeconds = try value.asInt(min: 0)
        case "ignored_apps":
            ignoredApps = value
                .split(separator: ",")
                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        default:
            throw ConfigurationError.unknownKey(key)
        }
    }
}

public enum ConfigurationError: Error, CustomStringConvertible {
    case unknownKey(String)
    case invalidValue(String)

    public var description: String {
        switch self {
        case .unknownKey(let key):
            return "Unknown config key: \(key)"
        case .invalidValue(let value):
            return "Invalid value: \(value)"
        }
    }
}

extension String {
    fileprivate func asInt(min: Int) throws -> Int {
        guard let parsed = Int(self), parsed >= min else {
            throw ConfigurationError.invalidValue(self)
        }
        return parsed
    }

    fileprivate func asBool() throws -> Bool {
        switch lowercased() {
        case "true", "1", "yes", "on":
            return true
        case "false", "0", "no", "off":
            return false
        default:
            throw ConfigurationError.invalidValue(self)
        }
    }
}

extension JSONEncoder {
    public static var pretty: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}
