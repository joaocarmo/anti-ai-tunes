import Foundation

@testable import AntiAITunesCore

/// One log for every fake, so a test can check the order of calls.
@MainActor
final class EventLog {
    var events: [String] = []
}

@MainActor
final class FakeMusic: MusicControlling {
    let log: EventLog
    var isRunning: Bool
    let fields: [String]?
    /// The read-back after a dislike: false by default, as Music answers for streamed songs on macOS 27.
    let readBack: String?
    /// Runs after each `previousTrack`, to simulate what Music announces next.
    let onPrevious: @MainActor () -> Void

    init(
        log: EventLog, isRunning: Bool = true, fields: [String]? = nil, readBack: String? = "false",
        onPrevious: @escaping @MainActor () -> Void = {}
    ) {
        self.log = log
        self.isRunning = isRunning
        self.fields = fields
        self.readBack = readBack
        self.onPrevious = onPrevious
    }

    func currentTrackFields() -> [String]? {
        log.events.append("read")
        return fields
    }

    func nextTrack() { log.events.append("nextTrack") }

    func previousTrack() {
        log.events.append("previousTrack")
        onPrevious()
    }

    func dislikeCurrentTrack() -> String? {
        log.events.append("dislike")
        return readBack
    }

    func clearDislike() { log.events.append("clearDislike") }
}

@MainActor
struct FakeNotifier: Notifying {
    let log: EventLog
    func post(title: String, body: String, skip: Skip) { log.events.append("post \(title) | \(body)") }
    func post(title: String, body: String) { log.events.append("post \(title) | \(body) | no actions") }
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

/// A store in a new temporary directory.
@MainActor
func temporaryStore(_ directory: URL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
    -> Store
{
    Store(directory: directory)
}
