import Foundation

@testable import AntiAITunesCore

/// One log for every fake, so a test can check the order of calls.
@MainActor
final class EventLog {
    var events: [String] = []
}

@MainActor
struct FakeMusic: MusicControlling {
    let log: EventLog
    var isRunning = true
    var fields: [String]?

    func currentTrackFields() -> [String]? {
        log.events.append("read")
        return fields
    }

    func nextTrack() { log.events.append("nextTrack") }
}

@MainActor
struct FakeNotifier: Notifying {
    let log: EventLog
    func post(title: String, body: String) { log.events.append("post \(title) | \(body)") }
}

/// A time source whose sleeps return at once.
///
/// After `sleepsLeft` sleeps, the next one throws.
@MainActor
final class FakeClock: TimeSource {
    let log: EventLog
    var now = Date(timeIntervalSince1970: 1_800_000_000)
    var sleepsLeft = 0

    init(log: EventLog) { self.log = log }

    func sleep(seconds: Double) async throws {
        log.events.append("sleep \(Int(seconds))")
        guard sleepsLeft > 0 else { throw CancellationError() }
        sleepsLeft -= 1
    }
}

/// Answers with `responses` in order.
@MainActor
final class FakeHTTP: HTTPClient {
    let log: EventLog
    var responses: [Result<HTTPResponse, any Error>]

    init(log: EventLog, responses: [Result<HTTPResponse, any Error>]) {
        self.log = log
        self.responses = responses
    }

    func get(_ url: URL, etag: String?, maxBytes: Int) async throws -> HTTPResponse {
        log.events.append("get etag=\(etag ?? "none") max=\(maxBytes)")
        return try responses.removeFirst().get()
    }
}
