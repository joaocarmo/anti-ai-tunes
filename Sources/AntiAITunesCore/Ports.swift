import Foundation

/// Controls playback in the Music app.
///
/// Callers check `isRunning` first, because any Apple Event launches Music.
@MainActor
public protocol MusicControlling {
    /// Whether the Music app is running.
    var isRunning: Bool { get }
    /// Returns the player state, name, artist and album of the current song, or nil when the read fails.
    func currentTrackFields() -> [String]?
    /// Skips to the next song.
    func nextTrack()
    /// Goes back to the previous song, or to the start of the current one if it has played for a few seconds.
    func previousTrack()
}

/// Shows notifications to the user.
@MainActor
public protocol Notifying {
    /// Shows a notification with `title` and `body`, and a **Not AI** action for `skip`.
    func post(title: String, body: String, skip: Skip)
}

/// The only source of time, so tests never sleep.
@MainActor
public protocol TimeSource {
    /// The current date and time.
    var now: Date { get }
    /// Waits for `seconds`, and throws when the wait is cancelled.
    func sleep(seconds: Double) async throws
}

/// Sends HTTP requests.
@MainActor
public protocol HTTPClient {
    /// Returns the response to a GET of `url`, with `If-None-Match` when `etag` is set.
    ///
    /// Throws when the body is larger than `maxBytes`.
    func get(_ url: URL, etag: String?, maxBytes: Int) async throws -> HTTPResponse
}

/// The answer to an HTTP GET.
public struct HTTPResponse: Equatable, Sendable {
    /// Nil when the response was not HTTP.
    let status: Int?
    let etag: String?
    let body: Data

    /// Creates a response.
    public init(status: Int?, etag: String?, body: Data) {
        self.status = status
        self.etag = etag
        self.body = body
    }
}

/// Reads a response body with a size limit.
public enum HTTPBody {
    /// The error thrown when a body is larger than the limit.
    public struct TooLargeError: Error {
        /// Creates the error.
        public init() {}
    }

    /// Returns the bytes as data, and throws as soon as there are more than `limit`.
    @inlinable
    public static func collect<Bytes: AsyncSequence>(_ bytes: Bytes, limit: Int) async throws -> Data
    where Bytes.Element == UInt8 {
        var data = Data()
        for try await byte in bytes {
            guard data.count < limit else { throw TooLargeError() }
            data.append(byte)
        }
        return data
    }
}
