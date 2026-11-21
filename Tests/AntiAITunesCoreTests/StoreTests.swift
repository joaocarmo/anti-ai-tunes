import Foundation
import GRDB
import Testing

@testable import AntiAITunesCore

@MainActor
struct StoreTests {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let url = URL(string: "https://example.com/list.csv")!
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
        store.allow(["a", "b"], at: date)
        store.allow(["a"], at: date.addingTimeInterval(1))
        #expect(Store(directory: directory).allowed() == ["a", "b"])
    }

    @Test func savesReplacesAndChecksAList() {
        let store = Store(directory: directory)
        #expect(store.list(url: url) == nil)
        let list = ListCache(names: ["a", "b"], etag: "e", changedAt: date, checkedAt: date)
        store.save(list, url: url)
        #expect(Store(directory: directory).list(url: url) == list)

        let smaller = ListCache(names: ["c"], etag: "f", changedAt: nil, checkedAt: date)
        store.save(smaller, url: url)
        store.markChecked(url: url, at: date.addingTimeInterval(60))
        #expect(store.list(url: url) == ListCache(names: ["c"], etag: "f", checkedAt: date.addingTimeInterval(60)))
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
        store.save(ListCache(names: ["a"], checkedAt: date), url: url)
        let queue = try #require(store.queue)
        #expect(throws: DatabaseError.self) {
            try queue.write {
                try $0.execute(sql: "INSERT INTO decision (name, verdict, decidedAt) VALUES ('x', 'maybe', 'd')")
            }
        }
        #expect(throws: DatabaseError.self) {
            try queue.write { try $0.execute(sql: "INSERT INTO listedArtist (sourceId, name) VALUES (999, 'x')") }
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
        store.allow(["a"], at: date)
        store.save(ListCache(names: ["a"], checkedAt: date), url: url)
        #expect(store.allowed().isEmpty)
        #expect(store.list(url: url) == nil)
    }

    @Test func reportsAFailedWrite() throws {
        let store = Store(directory: directory)
        try store.queue?.write { try $0.execute(sql: "DROP TABLE decision") }
        store.allow(["a"], at: date)
        #expect(store.failure != nil)
    }
}
