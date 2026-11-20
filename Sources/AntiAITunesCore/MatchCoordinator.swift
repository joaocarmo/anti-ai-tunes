import Observation

/// Follows the Music app and skips songs by listed artists.
@MainActor
@Observable
public final class MatchCoordinator {
    public private(set) var nowPlaying = NowPlaying.waiting
    @ObservationIgnored private var checkedKey: String?
    private let music: any MusicControlling
    private let notifier: any Notifying
    private let listed: @MainActor () -> Set<String>

    public init(music: any MusicControlling, notifier: any Notifying, listed: @escaping @MainActor () -> Set<String>) {
        self.music = music
        self.notifier = notifier
        self.listed = listed
    }

    /// Applies an update. Checks each song once, the first time it plays.
    public func handle(_ event: PlayerEvent) {
        if nowPlaying.apply(event) { checkedKey = nil }
        guard case .track(let track, .playing) = nowPlaying, track.key != checkedKey else { return }
        checkedKey = track.key
        let verdict = Verdict(parts: ArtistParts.parts(artist: track.artist, title: track.name), listed: listed())
        // Act only while the matched song is still the latest one Music reported.
        guard verdict.isMatch, nowPlaying.currentTrack?.key == track.key else { return }
        music.nextTrack()
        notifier.post(title: "Skipped \(track.artist) (AI)", body: track.name)
    }
}
