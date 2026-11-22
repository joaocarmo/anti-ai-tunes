import Foundation
import Observation

/// Follows the Music app, records each song, skips songs by listed artists and undoes a skip with **Not AI**.
@MainActor
@Observable
public final class MatchCoordinator {
    /// What the Music app is doing.
    public private(set) var nowPlaying = NowPlaying.waiting
    /// The most recent skip that **Not AI** can still undo, or nil.
    public private(set) var lastSkip: Skip?
    @ObservationIgnored private var checkedKey: String?
    // The song that started after `lastSkip`. Going back is safe only while it plays.
    @ObservationIgnored private var followerKey: String?
    @ObservationIgnored private var allowed: Set<String>
    // The current song's history row, from the first time it plays.
    @ObservationIgnored private var play: Play?
    // The skipped song whose dislike **Not AI** clears when it plays again.
    @ObservationIgnored private var clearKey: String?
    private let music: any MusicControlling
    private let notifier: any Notifying
    private let store: Store
    private let clock: any TimeSource
    private let listed: @MainActor () -> Set<String>
    private let calendar: Calendar

    /// The most notifications a song gets on one local day.
    static let dailyNotificationCap = 3

    /// Creates a coordinator that skips songs by the artists that `listed` returns, unless `store` allows them.
    ///
    /// `calendar` sets the local day of the notification cap.
    public init(
        music: any MusicControlling, notifier: any Notifying, store: Store, clock: any TimeSource,
        calendar: Calendar = .current, listed: @escaping @MainActor () -> Set<String>
    ) {
        self.music = music
        self.notifier = notifier
        self.store = store
        self.clock = clock
        self.calendar = calendar
        self.listed = listed
        allowed = store.allowed()
    }

    /// Reads the current song once at launch, if Music is running.
    public func start() {
        guard music.isRunning, let fields = music.currentTrackFields(), let event = PlayerEvent(snapshot: fields)
        else { return }
        handle(event)
    }

    /// Applies an update from the Music app.
    ///
    /// Checks each song once, the first time it plays.
    public func handle(_ event: PlayerEvent) {
        if nowPlaying.apply(event) {
            checkedKey = nil
            play = nil
            if lastSkip != nil, followerKey == nil { followerKey = nowPlaying.currentTrack?.key }
            if clearKey == nowPlaying.currentTrack?.key, music.isRunning { music.clearDislike() }
            clearKey = nil
        }
        check()
    }

    /// Checks the current song again, for example after the list changed.
    public func recheck() {
        checkedKey = nil
        check()
    }

    /// Allows the skipped artists and, for the most recent skip, goes back to the skipped song.
    ///
    /// It goes back only while the song after the skip plays. It sends `previous track`, waits 1 second, and sends it
    /// once more if the skipped song is not back, because the first call may only restart the current song. When the
    /// skipped song plays again, it clears the dislike if the dislike stuck.
    public func notAI(_ skip: Skip) async {
        allowed.formUnion(skip.parts)
        store.allow(skip.parts, at: clock.now)
        guard skip == lastSkip else { return }
        lastSkip = nil
        guard let follower = followerKey, nowPlaying.currentTrack?.key == follower, music.isRunning else { return }
        clearKey = skip.disliked ? skip.key : nil
        music.previousTrack()
        guard (try? await clock.sleep(seconds: 1)) != nil, nowPlaying.currentTrack?.key != skip.key, music.isRunning
        else { return }
        music.previousTrack()
    }

    private func check() {
        guard case .track(let track, .playing) = nowPlaying else { return }
        if play == nil { play = Play(key: track.key, id: store.addPlay(track, at: clock.now)) }
        let listed = listed()
        // An empty list has not loaded yet. `recheck()` runs when it arrives.
        guard track.key != checkedKey, !listed.isEmpty else { return }
        checkedKey = track.key
        let verdict = Verdict(parts: track.artistParts(), listed: listed, allowed: allowed)
        if !verdict.isMatch, Normalizer.normalize(track.artist).isEmpty, mayNotify() {
            notifier.post(title: "Couldn't detect the artist for \(track.name)", body: "")
        }
        // This runs in the same main-actor turn as the `playerInfo` that matched, so the key is still the latest.
        // A delay before acting must compare the key again.
        guard verdict.isMatch, music.isRunning else { return }
        // A dislike after `next track` would land on the next song.
        let dislike = Dislike(readBack: music.dislikeCurrentTrack())
        music.nextTrack()
        store.recordSkip(play: play?.id, dislike: dislike)
        let names = verdict.matched.map { Self.displayName($0, in: track.artist + " " + track.name) }
        let skip = Skip(
            key: track.key, parts: verdict.matched, artists: names.joined(separator: ", "),
            disliked: dislike == .accepted)
        lastSkip = skip
        followerKey = nil
        if mayNotify() { notifier.post(title: "Skipped \(skip.artists) (AI)", body: track.name, skip: skip) }
    }

    /// Returns true and records the notification, unless this play already got one or the song reached the daily cap.
    private func mayNotify() -> Bool {
        guard var play, !play.notified,
            store.notificationCount(trackKey: play.key, since: calendar.startOfDay(for: clock.now))
                < Self.dailyNotificationCap
        else { return false }
        play.notified = true
        self.play = play
        store.recordNotification(play: play.id)
        return true
    }

    /// The matched name as Music shows it, or the normalized name when it cannot be found.
    static func displayName(_ part: String, in text: String) -> String {
        text.range(of: part, options: [.caseInsensitive, .diacriticInsensitive]).map { String(text[$0]) } ?? part
    }
}

/// A song's history row while it plays.
private struct Play {
    let key: String
    let id: Int64?
    var notified = false
}
