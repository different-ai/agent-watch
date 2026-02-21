import Foundation
import SQLite3

private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

public enum SQLiteStoreError: Error, CustomStringConvertible {
    case openDatabase(String)
    case execute(String)
    case prepare(String)
    case step(String)
    case invalidDate(String)

    public var description: String {
        switch self {
        case .openDatabase(let message):
            return "Failed to open database: \(message)"
        case .execute(let message):
            return "Failed to execute SQL: \(message)"
        case .prepare(let message):
            return "Failed to prepare statement: \(message)"
        case .step(let message):
            return "Failed to execute statement: \(message)"
        case .invalidDate(let value):
            return "Failed to parse date: \(value)"
        }
    }
}

public final class SQLiteStore {
    private let db: OpaquePointer
    private let paths: ScreenTextPaths
    private let formatter: ISO8601DateFormatter

    public init(paths: ScreenTextPaths) throws {
        self.paths = paths
        try paths.ensureBaseDirectory()

        var pointer: OpaquePointer?
        if sqlite3_open(paths.databaseURL.path, &pointer) != SQLITE_OK {
            let message = pointer.flatMap { sqlite3_errmsg($0) }.map { String(cString: $0) } ?? "unknown"
            if let pointer {
                sqlite3_close(pointer)
            }
            throw SQLiteStoreError.openDatabase(message)
        }

        guard let opened = pointer else {
            throw SQLiteStoreError.openDatabase("no pointer")
        }

        db = opened

        formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        try execute("PRAGMA journal_mode=WAL;")
        try execute("PRAGMA synchronous=NORMAL;")
        try migrate()
    }

    deinit {
        sqlite3_close(db)
    }

    public func insert(_ record: CaptureRecord) throws {
        let sql = """
        INSERT INTO captures (
          timestamp,
          app_name,
          window_title,
          bundle_id,
          text_source,
          capture_trigger,
          display_id,
          text_hash,
          text_length,
          text_content,
          created_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteStoreError.prepare(lastErrorMessage())
        }
        defer { sqlite3_finalize(statement) }

        bindText(formatter.string(from: record.timestamp), at: 1, in: statement)
        bindText(record.appName, at: 2, in: statement)
        bindTextOptional(record.windowTitle, at: 3, in: statement)
        bindTextOptional(record.bundleID, at: 4, in: statement)
        bindText(record.source.rawValue, at: 5, in: statement)
        bindText(record.trigger.rawValue, at: 6, in: statement)
        bindTextOptional(record.displayID, at: 7, in: statement)
        bindText(record.textHash, at: 8, in: statement)
        sqlite3_bind_int(statement, 9, Int32(record.textLength))
        bindText(record.textContent, at: 10, in: statement)
        bindText(formatter.string(from: Date()), at: 11, in: statement)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw SQLiteStoreError.step(lastErrorMessage())
        }
    }

    public func search(query: String, limit: Int = 20, appName: String? = nil) throws -> [SearchResult] {
        var sql = """
        SELECT
          c.id,
          c.timestamp,
          c.app_name,
          c.window_title,
          c.bundle_id,
          c.text_source,
          c.capture_trigger,
          snippet(captures_fts, 0, '[', ']', ' ... ', 16) AS snippet
        FROM captures_fts
        JOIN captures c ON c.id = captures_fts.rowid
        WHERE captures_fts MATCH ?
        """

        if appName != nil {
            sql += " AND c.app_name = ?"
        }

        sql += " ORDER BY c.timestamp DESC LIMIT ?;"

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteStoreError.prepare(lastErrorMessage())
        }
        defer { sqlite3_finalize(statement) }

        bindText(query, at: 1, in: statement)

        if let appName {
            bindText(appName, at: 2, in: statement)
            sqlite3_bind_int(statement, 3, Int32(limit))
        } else {
            sqlite3_bind_int(statement, 2, Int32(limit))
        }

        var results: [SearchResult] = []

        while sqlite3_step(statement) == SQLITE_ROW {
            let id = sqlite3_column_int64(statement, 0)
            let timestampRaw = stringColumn(statement, at: 1) ?? ""
            guard let timestamp = formatter.date(from: timestampRaw) else {
                throw SQLiteStoreError.invalidDate(timestampRaw)
            }

            let app = stringColumn(statement, at: 2) ?? "Unknown"
            let window = stringColumn(statement, at: 3)
            let bundle = stringColumn(statement, at: 4)
            let source = TextSource(rawValue: stringColumn(statement, at: 5) ?? "") ?? .accessibility
            let trigger = CaptureTrigger(rawValue: stringColumn(statement, at: 6) ?? "") ?? .manual
            let snippet = stringColumn(statement, at: 7) ?? ""

            results.append(
                SearchResult(
                    id: id,
                    timestamp: timestamp,
                    appName: app,
                    windowTitle: window,
                    bundleID: bundle,
                    source: source,
                    trigger: trigger,
                    snippet: snippet
                )
            )
        }

        return results
    }

    public func status() throws -> StoreStatus {
        let sql = "SELECT COUNT(*), MAX(timestamp) FROM captures;"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteStoreError.prepare(lastErrorMessage())
        }
        defer { sqlite3_finalize(statement) }

        guard sqlite3_step(statement) == SQLITE_ROW else {
            throw SQLiteStoreError.step(lastErrorMessage())
        }

        let count = Int(sqlite3_column_int(statement, 0))
        let lastCaptureRaw = stringColumn(statement, at: 1)
        let lastCapture = lastCaptureRaw.flatMap { formatter.date(from: $0) }

        let attributes = try FileManager.default.attributesOfItem(atPath: paths.databaseURL.path)
        let bytes = (attributes[.size] as? NSNumber)?.int64Value ?? 0

        return StoreStatus(recordCount: count, lastCaptureAt: lastCapture, databaseBytes: bytes)
    }

    @discardableResult
    public func purge(olderThan: Date) throws -> Int {
        let sql = "DELETE FROM captures WHERE timestamp < ?;"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteStoreError.prepare(lastErrorMessage())
        }
        defer { sqlite3_finalize(statement) }

        bindText(formatter.string(from: olderThan), at: 1, in: statement)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw SQLiteStoreError.step(lastErrorMessage())
        }

        return Int(sqlite3_changes(db))
    }

    private func migrate() throws {
        let schema = [
            """
            CREATE TABLE IF NOT EXISTS captures (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                timestamp TEXT NOT NULL,
                app_name TEXT NOT NULL,
                window_title TEXT,
                bundle_id TEXT,
                text_source TEXT NOT NULL,
                capture_trigger TEXT NOT NULL,
                display_id TEXT,
                text_hash TEXT NOT NULL,
                text_length INTEGER NOT NULL,
                text_content TEXT NOT NULL,
                created_at TEXT NOT NULL
            );
            """,
            "CREATE INDEX IF NOT EXISTS idx_captures_timestamp ON captures(timestamp);",
            "CREATE INDEX IF NOT EXISTS idx_captures_app_name ON captures(app_name);",
            "CREATE INDEX IF NOT EXISTS idx_captures_source ON captures(text_source);",
            "CREATE VIRTUAL TABLE IF NOT EXISTS captures_fts USING fts5(text_content, content='captures', content_rowid='id');",
            """
            CREATE TRIGGER IF NOT EXISTS captures_ai AFTER INSERT ON captures BEGIN
                INSERT INTO captures_fts(rowid, text_content) VALUES (new.id, new.text_content);
            END;
            """,
            """
            CREATE TRIGGER IF NOT EXISTS captures_ad AFTER DELETE ON captures BEGIN
                INSERT INTO captures_fts(captures_fts, rowid, text_content) VALUES('delete', old.id, old.text_content);
            END;
            """,
            """
            CREATE TRIGGER IF NOT EXISTS captures_au AFTER UPDATE ON captures BEGIN
                INSERT INTO captures_fts(captures_fts, rowid, text_content) VALUES('delete', old.id, old.text_content);
                INSERT INTO captures_fts(rowid, text_content) VALUES (new.id, new.text_content);
            END;
            """,
        ]

        for statement in schema {
            try execute(statement)
        }
    }

    private func execute(_ sql: String) throws {
        var errorPointer: UnsafeMutablePointer<Int8>?
        guard sqlite3_exec(db, sql, nil, nil, &errorPointer) == SQLITE_OK else {
            let message = errorPointer.map { String(cString: $0) } ?? lastErrorMessage()
            sqlite3_free(errorPointer)
            throw SQLiteStoreError.execute(message)
        }
    }

    private func bindText(_ value: String, at index: Int32, in statement: OpaquePointer?) {
        _ = value.withCString { cString in
            sqlite3_bind_text(statement, index, cString, -1, sqliteTransient)
        }
    }

    private func bindTextOptional(_ value: String?, at index: Int32, in statement: OpaquePointer?) {
        guard let value else {
            sqlite3_bind_null(statement, index)
            return
        }
        _ = value.withCString { cString in
            sqlite3_bind_text(statement, index, cString, -1, sqliteTransient)
        }
    }

    private func stringColumn(_ statement: OpaquePointer?, at index: Int32) -> String? {
        guard let pointer = sqlite3_column_text(statement, index) else {
            return nil
        }
        return String(cString: pointer)
    }

    private func lastErrorMessage() -> String {
        String(cString: sqlite3_errmsg(db))
    }
}
