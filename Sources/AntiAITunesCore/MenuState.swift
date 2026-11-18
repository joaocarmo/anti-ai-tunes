/// The text the menu shows. Views only render it.
public struct MenuState: Equatable, Sendable {
    public let lines: [String]

    public init(_ nowPlaying: NowPlaying) {
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
