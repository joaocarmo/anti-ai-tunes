import Foundation
import Testing

@testable import AntiAITunesCore

@MainActor
struct ListRefresherTests {
    let log = EventLog()
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let csv = Data("artist,id\nAtomship,1\nSmokey September,2\n".utf8)

    func refresher(_ responses: [Result<HTTPResponse, any Error>], clock: FakeClock? = nil) -> ListRefresher {
        ListRefresher(
            store: temporaryStore(directory), http: FakeHTTP(log: log, responses: responses),
            clock: clock ?? FakeClock(log: log))
    }

    @Test func downloadsParsesAndCachesTheList() async {
        let first = refresher([.success(HTTPResponse(status: 200, etag: "\"v1\"", body: csv))])
        #expect(first.list == nil)
        #expect(first.names.isEmpty)
        await first.refresh()
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let expected = ListCache(
            names: ["atomship", "smokey september"], etag: "\"v1\"", changedAt: date, checkedAt: date)
        #expect(first.list == expected)
        #expect(log.events == ["get etag=none max=10000000"])

        let second = refresher([.success(HTTPResponse(status: 304, etag: "\"v1\"", body: Data()))])
        #expect(second.list == expected)
        await second.refresh()
        #expect(log.events.last == "get etag=\"v1\" max=10000000")
        #expect(second.names == ["atomship", "smokey september"])
    }

    @Test func onlyDifferentNamesUpdateTheChangeDate() async {
        let clock = FakeClock(log: log)
        let changed = clock.now
        let list = refresher(
            [
                .success(HTTPResponse(status: 200, etag: "e", body: csv)),
                .success(HTTPResponse(status: 304, etag: "e", body: Data())),
                .success(HTTPResponse(status: 200, etag: "f", body: csv)),
            ], clock: clock)
        await list.refresh()
        for _ in 1...2 {
            clock.now = clock.now.addingTimeInterval(60)
            await list.refresh()
            #expect(list.list?.checkedAt == clock.now)
            #expect(list.list?.changedAt == changed)
        }
        #expect(refresher([]).list?.checkedAt == clock.now)
    }

    @Test func keepsTheCacheOnAnyFailure() async {
        let ok = HTTPResponse(status: 200, etag: "e", body: csv)
        let list = refresher([
            .success(ok),
            .failure(HTTPBody.TooLargeError()),
            .success(HTTPResponse(status: 500, etag: nil, body: Data())),
            .success(HTTPResponse(status: nil, etag: nil, body: Data())),
            .success(HTTPResponse(status: 200, etag: "f", body: Data("name\nX".utf8))),
            .success(HTTPResponse(status: 200, etag: "g", body: Data("artist\n-\n".utf8))),
        ])
        await list.refresh()
        let cached = list.list
        for _ in 1...5 { await list.refresh() }
        #expect(list.list == cached)
        #expect(log.events.count == 6)
    }

    @Test func rejectsAListThatLostMoreThanHalfItsNames() async {
        func csv(_ names: String...) -> Data { Data((["artist"] + names).joined(separator: "\n").utf8) }
        let list = refresher([
            .success(
                HTTPResponse(status: 200, etag: "a", body: csv("Atomship", "Smokey September", "The Velvet Sundown"))),
            .success(HTTPResponse(status: 200, etag: "b", body: csv("Atomship"))),
            .success(HTTPResponse(status: 200, etag: "c", body: csv("Atomship", "Smokey September"))),
        ])
        var changes = 0
        list.onChange = { changes += 1 }
        await list.refresh()
        await list.refresh()
        #expect(list.list?.etag == "a")
        await list.refresh()
        #expect(list.names == ["atomship", "smokey september"])
        #expect(changes == 2)
    }

    @Test func refreshesEvery24Hours() async {
        let clock = FakeClock(log: log)
        clock.sleepsLeft = 1
        let response = HTTPResponse(status: 304, etag: nil, body: Data())
        await refresher([.success(response), .success(response)], clock: clock).run()
        let get = "get etag=none max=10000000"
        #expect(log.events == [get, "sleep 86400", get, "sleep 86400"])
    }

    @Test func collectsABodyUpToTheLimit() async throws {
        func bytes() -> AsyncStream<UInt8> {
            AsyncStream { continuation in
                for byte in [1, 2, 3] as [UInt8] { continuation.yield(byte) }
                continuation.finish()
            }
        }
        #expect(try await HTTPBody.collect(bytes(), limit: 3) == Data([1, 2, 3]))
        await #expect(throws: HTTPBody.TooLargeError.self) { try await HTTPBody.collect(bytes(), limit: 2) }
    }
}
