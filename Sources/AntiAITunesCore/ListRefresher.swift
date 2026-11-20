import Foundation
import Observation

/// The default list as last downloaded.
// shortcut: a JSON file holds the one default list; it moves into `Store` when the database arrives.
public struct ListCache: Codable, Equatable, Sendable {
    public var names: Set<String>
    public var etag: String?
    public var fetchedAt: Date

    public init(names: Set<String>, etag: String?, fetchedAt: Date) {
        self.names = names
        self.etag = etag
        self.fetchedAt = fetchedAt
    }
}

/// Keeps the default AI-artist list fresh. Any failure keeps the cached list.
@MainActor
@Observable
public final class ListRefresher {
    public static let url = URL(
        string: "https://raw.githubusercontent.com/CennoxX/spotify-ai-blocker/main/SpotifyAiArtists.csv")!
    public static let maxBytes = 10_000_000

    public private(set) var list: ListCache?
    private let file: URL
    private let http: any HTTPClient
    private let clock: any Clock

    /// Loads the cached list from `directory`, if there is one.
    public init(directory: URL, http: any HTTPClient, clock: any Clock) {
        file = directory.appendingPathComponent("default-list.json")
        self.http = http
        self.clock = clock
        list = try? JSONDecoder().decode(ListCache.self, from: Data(contentsOf: file))
    }

    public var names: Set<String> { list?.names ?? [] }

    public func refresh() async {
        guard let response = try? await http.get(Self.url, etag: list?.etag, maxBytes: Self.maxBytes) else { return }
        switch response.status {
        case 304:
            list?.fetchedAt = clock.now
        case 200:
            let text = String(decoding: response.body, as: UTF8.self)
            guard let names = CSVNames.parse(text, column: "artist"), !names.isEmpty else { return }
            list = ListCache(names: Set(names), etag: response.etag, fetchedAt: clock.now)
        default:
            return
        }
        try? FileManager.default.createDirectory(
            at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? JSONEncoder().encode(list).write(to: file, options: .atomic)
    }

    /// Refreshes now and then every 24 hours, until the clock's sleep throws.
    public func run() async {
        repeat { await refresh() } while (try? await clock.sleep(seconds: 86_400)) != nil
    }
}
