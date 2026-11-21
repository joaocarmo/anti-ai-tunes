import Foundation

/// The text the menu shows.
///
/// Views only render it.
public struct MenuState: Equatable, Sendable {
    /// The song lines: name, artist and playback state.
    public let lines: [String]
    /// The size and age of the AI list.
    public let listStatus: String

    /// Creates the menu text for `nowPlaying` and `list`.
    public init(nowPlaying: NowPlaying, list: ListCache? = nil) {
        listStatus =
            list.map {
                let updated = $0.fetchedAt.formatted(date: .abbreviated, time: .shortened)
                return "AI list: \($0.names.count.formatted()) artists, updated \(updated)"
            } ?? "AI list: not loaded yet"
        switch nowPlaying {
        case .waiting:
            lines = ["Waiting for the next song"]
        case .notPlaying:
            lines = ["Not playing"]
        case .track(let track, let state):
            let status = state == .paused ? ["Paused"] : []
            lines = [track.name, track.artist].filter { !$0.isEmpty } + status
        }
    }
}
