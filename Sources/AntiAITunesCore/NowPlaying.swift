/// What the Music app is doing, as far as the app knows.
public enum NowPlaying: Equatable, Sendable {
    /// Nothing heard yet since launch.
    case waiting
    case notPlaying
    case track(Track, PlayerState)

    /// Applies an update. Returns true when a different song starts, so callers can ignore repeats.
    @discardableResult
    public mutating func apply(_ event: PlayerEvent) -> Bool {
        switch event {
        case .track(let track, let state):
            let isNew = currentTrack?.key != track.key
            self = state == .stopped ? .notPlaying : .track(track, state ?? .playing)
            return isNew && state != .stopped
        case .state(.stopped):
            self = .notPlaying
        case .state(let state):
            if let track = currentTrack { self = .track(track, state) }
        }
        return false
    }

    var currentTrack: Track? {
        if case .track(let track, _) = self { return track }
        return nil
    }
}
