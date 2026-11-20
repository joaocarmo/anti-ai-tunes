import Foundation
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

    /// Reads the current song once at launch, if Music is running.
    public func start() {
        guard music.isRunning, let fields = music.currentTrackFields(), let event = PlayerEvent(snapshot: fields)
        else { return }
        handle(event)
    }

    /// Applies an update. Checks each song once, the first time it plays.
    public func handle(_ event: PlayerEvent) {
        if nowPlaying.apply(event) { checkedKey = nil }
        check()
    }

    /// Checks the current song again, for example after the list changed.
    public func recheck() {
        checkedKey = nil
        check()
    }

    private func check() {
        let listed = listed()
        // An empty list has not loaded yet. `recheck()` runs when it arrives.
        guard case .track(let track, .playing) = nowPlaying, track.key != checkedKey, !listed.isEmpty else { return }
        checkedKey = track.key
        let verdict = Verdict(parts: ArtistParts.parts(artist: track.artist, title: track.name), listed: listed)
        // This runs in the same main-actor turn as the `playerInfo` that matched, so the key is still the latest.
        // A delay before acting must compare the key again.
        guard verdict.isMatch, music.isRunning else { return }
        music.nextTrack()
        let names = verdict.matched.map { Self.displayName($0, in: track.artist + " " + track.name) }
        notifier.post(title: "Skipped \(names.joined(separator: ", ")) (AI)", body: track.name)
    }

    /// The matched name as Music shows it, or the normalized name when it cannot be found.
    static func displayName(_ part: String, in text: String) -> String {
        text.range(of: part, options: [.caseInsensitive, .diacriticInsensitive]).map { String(text[$0]) } ?? part
    }
}
