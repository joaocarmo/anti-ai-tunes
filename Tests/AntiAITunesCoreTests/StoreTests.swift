import Foundation
import GRDB
import Testing

@testable import AntiAITunesCore

@MainActor
struct StoreTests {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let url = ListRefresher.url
    let date = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func createsAValidSchemaOnce() throws {
        let store = Store(directory: directory)
        #expect(store.failure == nil)
        try store.queue?.read { try $0.checkForeignKeys() }
        #expect(Store(directory: directory).failure == nil)
    }

    @Test func keepsDecisionsAcrossLaunches() {
        let store = Store(directory: directory)
        #expect(store.allowed().isEmpty)
        store.allow(["the velvet sundown", "atomship"], at: date)
        store.allow(["the velvet sundown"], at: date.addingTimeInterval(1))
        #expect(Store(directory: directory).allowed() == ["the velvet sundown", "atomship"])
    }

    @Test func savesReplacesAndChecksAList() {
        let store = Store(directory: directory)
        #expect(store.list(url: url) == nil)
        let list = ListCache(names: ["atomship", "smokey september"], etag: "e", changedAt: date, checkedAt: date)
        store.save(list, url: url)
        #expect(Store(directory: directory).list(url: url) == list)

        let smaller = ListCache(names: ["the velvet sundown"], etag: "f", changedAt: nil, checkedAt: date)
        store.save(smaller, url: url)
        store.markChecked(url: url, at: date.addingTimeInterval(60))
        #expect(
            store.list(url: url)
                == ListCache(names: ["the velvet sundown"], etag: "f", checkedAt: date.addingTimeInterval(60)))
    }

    @Test func recordsPlaysAndCountsTheirNotifications() throws {
        let store = Store(directory: directory)
        let track = Track(name: "Dust on the Wind", artist: "The Velvet Sundown", album: "Floating on Echoes")
        let first = try #require(store.addPlay(track, at: date))
        let second = store.addPlay(track, at: date.addingTimeInterval(60))
        #expect(store.notificationCount(trackKey: track.key, since: date) == 0)
        store.recordSkip(play: second, dislike: .failed)
        store.recordNotification(play: first)
        store.recordNotification(play: second)
        #expect(store.notificationCount(trackKey: track.key, since: date) == 2)
        #expect(store.notificationCount(trackKey: track.key, since: date.addingTimeInterval(1)) == 1)
        #expect(store.notificationCount(trackKey: "other", since: date) == 0)
        let skipped = try store.queue?.read {
            try String.fetchOne($0, sql: "SELECT action || ' ' || dislike FROM play WHERE id = ?", arguments: [second])
        }
        #expect(skipped == "skip failed")
    }

    @Test func skipsASourceThatWasNeverChecked() throws {
        let store = Store(directory: directory)
        try store.queue?.write {
            try $0.execute(sql: "INSERT INTO source (url) VALUES (?)", arguments: [url.absoluteString])
        }
        #expect(store.list(url: url) == nil)
    }

    @Test func enforcesTheSchema() throws {
        let store = Store(directory: directory)
        store.save(ListCache(names: ["atomship"], checkedAt: date), url: url)
        let queue = try #require(store.queue)
        #expect(throws: DatabaseError.self) {
            try queue.write {
                try $0.execute(
                    sql: "INSERT INTO decision (name, verdict, decidedAt) VALUES ('the velvet sundown', 'maybe', 'd')")
            }
        }
        #expect(throws: DatabaseError.self) {
            try queue.write {
                try $0.execute(
                    sql:
                        "INSERT INTO play (playedAt, trackKey, name, artist, album, action) VALUES ('d', 'k', 'n', 'a', 'b', 'maybe')"
                )
            }
        }
        #expect(throws: DatabaseError.self) {
            try queue.write {
                try $0.execute(sql: "INSERT INTO listedArtist (sourceId, name) VALUES (999, 'atomship')")
            }
        }
        try queue.write { try $0.execute(sql: "DELETE FROM source") }
        #expect(try queue.read { try Int.fetchOne($0, sql: "SELECT count(*) FROM listedArtist") } == 0)
    }

    @Test func deletesTheOldListFile() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let old = directory.appendingPathComponent("default-list.json")
        try Data("{}".utf8).write(to: old)
        _ = Store(directory: directory)
        #expect(!FileManager.default.fileExists(atPath: old.path))
    }

    @Test func worksWithoutSavingWhenTheDatabaseCannotOpen() throws {
        try Data().write(to: directory)
        let store = Store(directory: directory)
        #expect(store.failure != nil)
        store.allow(["the velvet sundown"], at: date)
        store.save(ListCache(names: ["atomship"], checkedAt: date), url: url)
        #expect(store.allowed().isEmpty)
        #expect(store.list(url: url) == nil)
        let track = Track(name: "Dust on the Wind", artist: "The Velvet Sundown", album: "Floating on Echoes")
        #expect(store.addPlay(track, at: date) == nil)
        #expect(store.notificationCount(trackKey: track.key, since: date) == 0)
    }

    @Test func reportsAFailedWrite() throws {
        let store = Store(directory: directory)
        try store.queue?.write { try $0.execute(sql: "DROP TABLE decision") }
        store.allow(["the velvet sundown"], at: date)
        #expect(store.failure != nil)
    }
}
