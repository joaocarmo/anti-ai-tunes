import Foundation

/// Controls playback in the Music app. Callers check `isRunning` first, because any Apple Event launches Music.
@MainActor
public protocol MusicControlling {
    var isRunning: Bool { get }
    /// Player state, name, artist and album of the current song, or nil when the read fails.
    func currentTrackFields() -> [String]?
    func nextTrack()
}

/// Shows notifications to the user.
@MainActor
public protocol Notifying {
    func post(title: String, body: String)
}

/// The only source of time, so tests never sleep.
@MainActor
public protocol Clock {
    var now: Date { get }
    func sleep(seconds: Double) async throws
}

/// Sends HTTP requests.
@MainActor
public protocol HTTPClient {
    /// GETs `url`, with `If-None-Match` when `etag` is set. Throws when the body is larger than `maxBytes`.
    func get(_ url: URL, etag: String?, maxBytes: Int) async throws -> HTTPResponse
}

/// The answer to an HTTP GET.
public struct HTTPResponse: Equatable, Sendable {
    /// Nil when the response was not HTTP.
    public let status: Int?
    public let etag: String?
    public let body: Data

    public init(status: Int?, etag: String?, body: Data) {
        self.status = status
        self.etag = etag
        self.body = body
    }
}

/// Reads a response body with a size limit.
public enum HTTPBody {
    public struct TooLarge: Error {
        public init() {}
    }

    /// Collects the bytes, and throws as soon as there are more than `limit`.
    @inlinable
    public static func collect<Bytes: AsyncSequence>(_ bytes: Bytes, limit: Int) async throws -> Data
    where Bytes.Element == UInt8 {
        var data = Data()
        for try await byte in bytes {
            guard data.count < limit else { throw TooLarge() }
            data.append(byte)
        }
        return data
    }
}
