import Foundation

/// The text the menu shows.
///
/// Views only render it.
public struct MenuState: Equatable, Sendable {
    /// The song lines: name, artist and playback state.
    public let lines: [String]
    /// The AI list lines: the number of artists, when the list last changed and when the app last checked it.
    public let listDetails: [String]
    /// The label of the **Not AI** item for the last skip, or nil when there is none.
    public let notAI: String?
    /// Why changes are not saved, or nil.
    public let warning: String?

    /// Creates the menu text for `nowPlaying`, `list`, the last skip and a store failure.
    public init(nowPlaying: NowPlaying, list: ListCache? = nil, lastSkip: Skip? = nil, failure: String? = nil) {
        notAI = lastSkip.map { "Not AI: \($0.artists)" }
        warning = failure.map { "Changes are not saved: \($0)" }
        if let list {
            let changed = list.changedAt.map { ["Changed \(Self.text($0))"] } ?? []
            listDetails =
                ["\(list.names.count.formatted()) artists"] + changed + ["Checked \(Self.text(list.checkedAt))"]
        } else {
            listDetails = ["Not loaded yet"]
        }
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

    private static func text(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .shortened)
    }
}
