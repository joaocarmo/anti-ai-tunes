import Foundation
import GRDB
import Observation

/// The app's database: the AI lists, the user's decisions and the songs played.
///
/// It is the only type that touches the database. Names are stored normalized. History rows also keep the song's
/// name, artist and album as Music shows them.
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

    /// Records that `track` started playing, and returns the new row's ID.
    func addPlay(_ track: Track, at date: Date) -> Int64? {
        write { db in
            try db.execute(
                sql: "INSERT INTO play (playedAt, trackKey, name, artist, album) VALUES (?, ?, ?, ?, ?)",
                arguments: [date, track.key, track.name, track.artist, track.album])
            return db.lastInsertedRowID
        }
    }

    /// Records that the app skipped the play with `id`, and the result of the dislike before the skip.
    func recordSkip(play id: Int64?, dislike: Dislike) {
        write {
            try $0.execute(
                sql: "UPDATE play SET action = 'skip', dislike = ? WHERE id = ?", arguments: [dislike.rawValue, id])
        }
    }

    /// Records that the play with `id` got a notification.
    func recordNotification(play id: Int64?) {
        write { try $0.execute(sql: "UPDATE play SET notified = 1 WHERE id = ?", arguments: [id]) }
    }

    /// Returns how many plays of the song with `trackKey` got a notification since `date`.
    func notificationCount(trackKey: String, since date: Date) -> Int {
        let count = try? queue?.read {
            try Int.fetchOne(
                $0, sql: "SELECT count(*) FROM play WHERE trackKey = ? AND notified = 1 AND playedAt >= ?",
                arguments: [trackKey, date])
        }
        return count ?? 0
    }

    @discardableResult
    private func write<T>(_ updates: (Database) throws -> T) -> T? {
        do {
            return try queue?.write(updates)
        } catch {
            failure = error.localizedDescription
            return nil
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
        migrator.registerMigration("v2") { db in
            try db.execute(
                sql: """
                    CREATE TABLE play (
                      id INTEGER PRIMARY KEY,
                      playedAt TEXT NOT NULL,
                      trackKey TEXT NOT NULL,
                      name TEXT NOT NULL,
                      artist TEXT NOT NULL,
                      album TEXT NOT NULL,
                      action TEXT CHECK (action IN ('skip', 'pause', 'nothing')),
                      dislike TEXT CHECK (dislike IN ('accepted', 'ignored', 'failed')),
                      notified INTEGER NOT NULL DEFAULT 0 CHECK (notified IN (0, 1))
                    ) STRICT;

                    CREATE INDEX playOnTrackKeyAndPlayedAt ON play (trackKey, playedAt);
                    """)
        }
        return migrator
    }()
}
