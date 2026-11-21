import Foundation
import Observation

/// The default list as last downloaded.
public struct ListCache: Equatable, Sendable {
    var names: Set<String>
    var etag: String?
    /// When a download last brought different names.
    var changedAt: Date?
    /// When the list host last answered.
    var checkedAt: Date
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
    private let store: Store
    private let http: any HTTPClient
    private let clock: any TimeSource

    /// Creates a refresher that keeps the list in `store`, and loads the stored list if there is one.
    public init(store: Store, http: any HTTPClient, clock: any TimeSource) {
        self.store = store
        self.http = http
        self.clock = clock
        list = store.list(url: Self.url)
    }

    /// The listed artist names, or an empty set before the first download.
    public var names: Set<String> { list?.names ?? [] }

    func refresh() async {
        guard let response = try? await http.get(Self.url, etag: list?.etag, maxBytes: Self.maxBytes) else { return }
        switch response.status {
        case 304:
            list?.checkedAt = clock.now
            store.markChecked(url: Self.url, at: clock.now)
        case 200:
            let text = String(decoding: response.body, as: UTF8.self)
            // A list that lost more than half its names is more likely broken than cleaned up.
            guard let parsed = CSVNames.parse(text, column: "artist").map(Set.init), !parsed.isEmpty,
                parsed.count * 2 >= names.count
            else { return }
            let new = ListCache(
                names: parsed, etag: response.etag, changedAt: parsed == names ? list?.changedAt : clock.now,
                checkedAt: clock.now)
            list = new
            store.save(new, url: Self.url)
            onChange()
        default:
            return
        }
    }

    /// Refreshes now and then every 24 hours, until the clock's sleep throws.
    public func run() async {
        repeat { await refresh() } while (try? await clock.sleep(seconds: 86_400)) != nil
    }
}
