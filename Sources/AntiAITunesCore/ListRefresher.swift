import Foundation
import Observation

// shortcut: a JSON file holds the one default list; it moves into `Store` when the database arrives.
/// The default list as last downloaded.
public struct ListCache: Codable, Equatable, Sendable {
    var names: Set<String>
    var etag: String?
    /// When a download last brought different names.
    ///
    /// Nil in caches written before this was recorded.
    var changedAt: Date?
    /// When the list host last answered.
    var checkedAt: Date

    // The check date keeps its first JSON key, so older caches still load.
    enum CodingKeys: String, CodingKey {
        case names, etag, changedAt
        case checkedAt = "fetchedAt"
    }
}

/// Keeps the default AI-artist list fresh.
///
/// Any failure keeps the cached list.
@MainActor
@Observable
public final class ListRefresher {
    static let url = URL(
        string: "https://raw.githubusercontent.com/CennoxX/spotify-ai-blocker/main/SpotifyAiArtists.csv")!
    static let maxBytes = 10_000_000

    /// The cached list, or nil before the first download.
    public private(set) var list: ListCache?
    /// Called after a download replaces the list.
    @ObservationIgnored public var onChange: @MainActor () -> Void = {}
    private let file: URL
    private let http: any HTTPClient
    private let clock: any TimeSource

    /// Creates a refresher that keeps its cache in `directory`, and loads the cached list if there is one.
    public init(directory: URL, http: any HTTPClient, clock: any TimeSource) {
        file = directory.appendingPathComponent("default-list.json")
        self.http = http
        self.clock = clock
        list = try? JSONDecoder().decode(ListCache.self, from: Data(contentsOf: file))
    }

    /// The listed artist names, or an empty set before the first download.
    public var names: Set<String> { list?.names ?? [] }

    func refresh() async {
        guard let response = try? await http.get(Self.url, etag: list?.etag, maxBytes: Self.maxBytes) else { return }
        switch response.status {
        case 304:
            list?.checkedAt = clock.now
        case 200:
            let text = String(decoding: response.body, as: UTF8.self)
            // A list that lost more than half its names is more likely broken than cleaned up.
            guard let parsed = CSVNames.parse(text, column: "artist").map(Set.init), !parsed.isEmpty,
                parsed.count * 2 >= names.count
            else { return }
            list = ListCache(
                names: parsed, etag: response.etag, changedAt: parsed == names ? list?.changedAt : clock.now,
                checkedAt: clock.now)
            onChange()
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
