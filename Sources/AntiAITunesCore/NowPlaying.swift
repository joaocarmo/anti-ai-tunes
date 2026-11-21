/// What the Music app is doing, as far as the app knows.
public enum NowPlaying: Equatable, Sendable {
    /// Nothing heard yet since launch.
    case waiting
    /// Music is stopped or not running.
    case notPlaying
    /// A song is loaded, playing or paused.
    case track(Track, PlayerState)

    /// Applies an update and returns true when a different song starts.
    ///
    /// Callers use the result to ignore repeats.
    @discardableResult
    mutating func apply(_ event: PlayerEvent) -> Bool {
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
