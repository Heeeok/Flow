import Foundation
import SQLite3

/// Thread-safe SQLite database service for event storage and retrieval
final class DatabaseService {
    static let shared = DatabaseService()

    private var db: OpaquePointer?
    private let queue = DispatchQueue(label: "com.screenagent.db", qos: .utility)

    private init() {
        openDatabase()
        createTables()
    }

    deinit {
        sqlite3_close(db)
    }

    // MARK: - Database Setup

    private var dbURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("ScreenAgent", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("screenagent.db")
    }

    private func openDatabase() {
        let path = dbURL.path
        if sqlite3_open(path, &db) != SQLITE_OK {
            print("[DB] Failed to open database at \(path)")
            db = nil
        } else {
            // Enable WAL mode for better concurrent performance
            exec("PRAGMA journal_mode=WAL")
            exec("PRAGMA foreign_keys=ON")
            print("[DB] Database opened at \(path)")
        }
    }

    private func createTables() {
        let sql = """
        CREATE TABLE IF NOT EXISTS events (
            id TEXT PRIMARY KEY,
            ts_start REAL NOT NULL,
            ts_end REAL NOT NULL,
            app_bundle TEXT NOT NULL DEFAULT '',
            app_name TEXT NOT NULL DEFAULT '',
            window_title TEXT NOT NULL DEFAULT '',
            summary TEXT NOT NULL DEFAULT '',
            tags_json TEXT NOT NULL DEFAULT '[]',
            sensitivity_flag INTEGER NOT NULL DEFAULT 0,
            thumb_path TEXT,
            ax_text_snippet TEXT
        );

        CREATE INDEX IF NOT EXISTS idx_events_ts ON events(ts_start);
        CREATE INDEX IF NOT EXISTS idx_events_app ON events(app_bundle);
        CREATE INDEX IF NOT EXISTS idx_events_summary ON events(summary);

        CREATE TABLE IF NOT EXISTS schema_version (
            version INTEGER PRIMARY KEY
        );
        """
        exec(sql)

        // Run migrations
        migrate()
    }

    private func migrate() {
        let currentVersion = queryScalar("SELECT MAX(version) FROM schema_version") ?? 0

        if currentVersion < 1 {
            // Initial schema — already created above
            exec("INSERT OR REPLACE INTO schema_version(version) VALUES(1)")
        }

        // Future migrations go here:
        // if currentVersion < 2 { ... exec("ALTER TABLE ...") ... }
    }

    // MARK: - CRUD Operations

    func insertEvent(_ event: ScreenEvent) {
        queue.sync {
            let sql = """
            INSERT OR REPLACE INTO events
            (id, ts_start, ts_end, app_bundle, app_name, window_title, summary, tags_json, sensitivity_flag, thumb_path, ax_text_snippet)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
            defer { sqlite3_finalize(stmt) }

            sqlite3_bind_text(stmt, 1, (event.id as NSString).utf8String, -1, nil)
            sqlite3_bind_double(stmt, 2, event.timestampStart.timeIntervalSince1970)
            sqlite3_bind_double(stmt, 3, event.timestampEnd.timeIntervalSince1970)
            sqlite3_bind_text(stmt, 4, (event.appBundleID as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 5, (event.appName as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 6, (event.windowTitle as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 7, (event.summary as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 8, (event.tagsJSON as NSString).utf8String, -1, nil)
            sqlite3_bind_int(stmt, 9, Int32(event.sensitivityFlag.rawValue))

            if let thumbPath = event.thumbnailPath {
                sqlite3_bind_text(stmt, 10, (thumbPath as NSString).utf8String, -1, nil)
            } else {
                sqlite3_bind_null(stmt, 10)
            }

            if let axText = event.axTextSnippet {
                sqlite3_bind_text(stmt, 11, (axText as NSString).utf8String, -1, nil)
            } else {
                sqlite3_bind_null(stmt, 11)
            }

            sqlite3_step(stmt)
        }
    }

    func updateEvent(_ event: ScreenEvent) {
        insertEvent(event) // REPLACE handles update
    }

    func deleteEvent(id: String) {
        queue.sync {
            let sql = "DELETE FROM events WHERE id = ?"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
            defer { sqlite3_finalize(stmt) }
            sqlite3_bind_text(stmt, 1, (id as NSString).utf8String, -1, nil)
            sqlite3_step(stmt)
        }
    }

    // MARK: - Queries

    func searchEvents(
        keyword: String = "",
        dateFrom: Date? = nil,
        dateTo: Date? = nil,
        appBundle: String? = nil,
        limit: Int = 200
    ) -> [ScreenEvent] {
        return queue.sync {
            var conditions: [String] = []
            var params: [Any] = []

            if !keyword.isEmpty {
                conditions.append("(summary LIKE ? OR window_title LIKE ? OR tags_json LIKE ? OR app_name LIKE ?)")
                let like = "%\(keyword)%"
                params.append(contentsOf: [like, like, like, like])
            }
            if let from = dateFrom {
                conditions.append("ts_start >= ?")
                params.append(from.timeIntervalSince1970)
            }
            if let to = dateTo {
                conditions.append("ts_end <= ?")
                params.append(to.timeIntervalSince1970)
            }
            if let bundle = appBundle, !bundle.isEmpty {
                conditions.append("app_bundle = ?")
                params.append(bundle)
            }

            let whereClause = conditions.isEmpty ? "" : "WHERE " + conditions.joined(separator: " AND ")
            let sql = "SELECT * FROM events \(whereClause) ORDER BY ts_start DESC LIMIT ?"
            params.append(limit)

            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
            defer { sqlite3_finalize(stmt) }

            // Bind parameters
            for (i, param) in params.enumerated() {
                let idx = Int32(i + 1)
                if let s = param as? String {
                    sqlite3_bind_text(stmt, idx, (s as NSString).utf8String, -1, nil)
                } else if let d = param as? Double {
                    sqlite3_bind_double(stmt, idx, d)
                } else if let n = param as? Int {
                    sqlite3_bind_int(stmt, idx, Int32(n))
                }
            }

            var results: [ScreenEvent] = []
            while sqlite3_step(stmt) == SQLITE_ROW {
                results.append(eventFromRow(stmt))
            }
            return results
        }
    }

    func todayEventCount() -> Int {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        return queue.sync {
            let sql = "SELECT COUNT(*) FROM events WHERE ts_start >= ?"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return 0 }
            defer { sqlite3_finalize(stmt) }
            sqlite3_bind_double(stmt, 1, startOfDay.timeIntervalSince1970)
            return sqlite3_step(stmt) == SQLITE_ROW ? Int(sqlite3_column_int(stmt, 0)) : 0
        }
    }

    func recentEvents(limit: Int = 5) -> [ScreenEvent] {
        return searchEvents(limit: limit)
    }

    func allAppBundles() -> [String] {
        return queue.sync {
            let sql = "SELECT DISTINCT app_bundle FROM events WHERE app_bundle != '' ORDER BY app_bundle"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
            defer { sqlite3_finalize(stmt) }
            var results: [String] = []
            while sqlite3_step(stmt) == SQLITE_ROW {
                if let cStr = sqlite3_column_text(stmt, 0) {
                    results.append(String(cString: cStr))
                }
            }
            return results
        }
    }

    // MARK: - Helpers

    private func eventFromRow(_ stmt: OpaquePointer?) -> ScreenEvent {
        func col(_ i: Int32) -> String {
            guard let cStr = sqlite3_column_text(stmt, i) else { return "" }
            return String(cString: cStr)
        }
        func colOpt(_ i: Int32) -> String? {
            guard sqlite3_column_type(stmt, i) != SQLITE_NULL,
                  let cStr = sqlite3_column_text(stmt, i) else { return nil }
            return String(cString: cStr)
        }

        return ScreenEvent(
            id: col(0),
            timestampStart: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 1)),
            timestampEnd: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 2)),
            appBundleID: col(3),
            appName: col(4),
            windowTitle: col(5),
            summary: col(6),
            tags: ScreenEvent.tagsFromJSON(col(7)),
            sensitivityFlag: ScreenEvent.SensitivityLevel(rawValue: Int(sqlite3_column_int(stmt, 8))) ?? .none,
            thumbnailPath: colOpt(9),
            axTextSnippet: colOpt(10)
        )
    }

    @discardableResult
    private func exec(_ sql: String) -> Bool {
        var errMsg: UnsafeMutablePointer<CChar>?
        let result = sqlite3_exec(db, sql, nil, nil, &errMsg)
        if result != SQLITE_OK {
            if let msg = errMsg {
                print("[DB] Error: \(String(cString: msg))")
                sqlite3_free(msg)
            }
            return false
        }
        return true
    }

    private func queryScalar(_ sql: String) -> Int? {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(stmt) }
        return sqlite3_step(stmt) == SQLITE_ROW ? Int(sqlite3_column_int(stmt, 0)) : nil
    }
}
