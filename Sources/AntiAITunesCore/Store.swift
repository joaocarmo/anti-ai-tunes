import Foundation
import GRDB
import Observation

/// The app's database: the AI lists and the user's decisions.
///
/// It is the only type that touches the database. Names are stored normalized.
@MainActor
@Observable
public final class Store {
    /// Why changes are not saved, or nil while the database works.
    public private(set) var failure: String?
    @ObservationIgnored let queue: DatabaseQueue?

    /// Creates a store in `directory` and brings its schema up to date.
    ///
    /// When the database cannot open, the store saves nothing and reads nothing, and `failure` says why.
    public init(directory: URL) {
        // Versions before 0.3.0 kept the default list in this file.
        try? FileManager.default.removeItem(at: directory.appendingPathComponent("default-list.json"))
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let queue = try DatabaseQueue(path: directory.appendingPathComponent("db.sqlite").path)
            try Self.migrator.migrate(queue)
            self.queue = queue
        } catch {
            queue = nil
            failure = error.localizedDescription
        }
    }

    /// Returns the names the user allowed with **Not AI**.
    func allowed() -> Set<String> {
        (try? queue?.read { try String.fetchSet($0, sql: "SELECT name FROM decision WHERE verdict = 'allow'") }) ?? []
    }

    /// Records an `allow` decision for each name.
    func allow(_ names: [String], at date: Date) {
        write { db in
            let upsert = try db.makeStatement(
                sql: """
                    INSERT INTO decision (name, verdict, decidedAt) VALUES (?, 'allow', ?)
                    ON CONFLICT (name) DO UPDATE SET verdict = 'allow', decidedAt = excluded.decidedAt
                    """)
            for name in names { try upsert.execute(arguments: [name, date]) }
        }
    }

    /// Returns the list downloaded from `url`, or nil before its first download.
    func list(url: URL) -> ListCache? {
        try? queue?.read { db in
            guard
                let row = try Row.fetchOne(
                    db, sql: "SELECT id, etag, changedAt, checkedAt FROM source WHERE url = ?",
                    arguments: [url.absoluteString]),
                let checkedAt = row["checkedAt"] as Date?
            else { return nil }
            let names = try String.fetchSet(
                db, sql: "SELECT name FROM listedArtist WHERE sourceId = ?", arguments: [row["id"] as Int64])
            return ListCache(names: names, etag: row["etag"], changedAt: row["changedAt"], checkedAt: checkedAt)
        }
    }

    /// Replaces the list from `url` and all its names in one transaction.
    func save(_ list: ListCache, url: URL) {
        write { db in
            let id = try Int64.fetchOne(
                db,
                sql: """
                    INSERT INTO source (url, etag, changedAt, checkedAt) VALUES (?, ?, ?, ?)
                    ON CONFLICT (url) DO UPDATE SET
                      etag = excluded.etag, changedAt = excluded.changedAt, checkedAt = excluded.checkedAt
                    RETURNING id
                    """, arguments: [url.absoluteString, list.etag, list.changedAt, list.checkedAt])
            try db.execute(sql: "DELETE FROM listedArtist WHERE sourceId = ?", arguments: [id])
            let insert = try db.makeStatement(sql: "INSERT INTO listedArtist (sourceId, name) VALUES (?, ?)")
            for name in list.names { try insert.execute(arguments: [id, name]) }
        }
    }

    /// Records that the host of `url` answered without changes.
    func markChecked(url: URL, at date: Date) {
        write {
            try $0.execute(sql: "UPDATE source SET checkedAt = ? WHERE url = ?", arguments: [date, url.absoluteString])
        }
    }

    private func write(_ updates: (Database) throws -> Void) {
        do {
            try queue?.write(updates)
        } catch {
            failure = error.localizedDescription
        }
    }

    // A shipped migration never changes. Schema changes add a new one.
    private static let migrator = {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("v1") { db in
            try db.execute(
                sql: """
                    CREATE TABLE source (
                      id INTEGER PRIMARY KEY,
                      url TEXT NOT NULL UNIQUE,
                      etag TEXT,
                      changedAt TEXT,
                      checkedAt TEXT
                    ) STRICT;

                    CREATE TABLE listedArtist (
                      sourceId INTEGER NOT NULL REFERENCES source(id) ON DELETE CASCADE,
                      name TEXT NOT NULL,
                      PRIMARY KEY (sourceId, name)
                    ) STRICT, WITHOUT ROWID;

                    CREATE TABLE decision (
                      id INTEGER PRIMARY KEY,
                      name TEXT NOT NULL UNIQUE,
                      verdict TEXT NOT NULL CHECK (verdict IN ('allow', 'skip')),
                      decidedAt TEXT NOT NULL
                    ) STRICT;
                    """)
        }
        return migrator
    }()
}
