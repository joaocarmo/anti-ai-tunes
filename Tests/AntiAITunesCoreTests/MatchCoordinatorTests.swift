import Foundation
import Testing

@testable import AntiAITunesCore

@MainActor
struct MatchCoordinatorTests {
    let log = EventLog()
    let ai = Track(name: "Closure", artist: "D.O.D & Hayley May", album: "Closure - Single")
    let human = Track(name: "Free Your Mind", artist: "Prospa, Cloonee & Sybil", album: "Free Your Mind - Single")

    func coordinator(listed: Set<String> = ["hayley may"], music: FakeMusic? = nil) -> MatchCoordinator {
        MatchCoordinator(
            music: music ?? FakeMusic(log: log), notifier: FakeNotifier(log: log), listed: { listed })
    }

    @Test func skipsAListedArtistAndNotifies() {
        let match = coordinator()
        match.handle(.track(ai, .playing))
        #expect(log.events == ["nextTrack", "post Skipped Hayley May (AI) | Closure"])
        #expect(match.nowPlaying == .track(ai, .playing))
    }

    @Test func leavesOtherArtistsAlone() {
        let match = coordinator()
        match.handle(.track(human, .playing))
        #expect(log.events.isEmpty)
    }

    @Test func checksAPausedSongWhenItPlays() {
        let match = coordinator()
        match.handle(.track(ai, .paused))
        #expect(log.events.isEmpty)
        match.handle(.state(.playing))
        #expect(log.events.first == "nextTrack")
    }

    @Test func checksEachSongOnceUntilAnotherStarts() {
        let match = coordinator()
        match.handle(.track(ai, .playing))
        match.handle(.track(ai, .playing))
        match.handle(.state(.paused))
        match.handle(.state(.playing))
        #expect(log.events.count == 2)
        match.handle(.track(human, .paused))
        match.handle(.track(ai, .playing))
        #expect(log.events.count == 4)
    }

    @Test func namesAFeaturedArtistFromTheTitle() {
        let match = coordinator(listed: ["54 ultra"])
        match.handle(.track(Track(name: "Talk To You (feat. 54 Ultra)", artist: "ANOTR", album: ""), nil))
        #expect(log.events == ["nextTrack", "post Skipped 54 Ultra (AI) | Talk To You (feat. 54 Ultra)"])
    }

    @Test func fallsBackToTheNormalizedName() {
        #expect(MatchCoordinator.displayName("a b", in: "A  B Song") == "a b")
        #expect(MatchCoordinator.displayName("eloise", in: "Éloise - Song") == "Éloise")
    }

    @Test func waitsForTheListAndChecksAgainWhenItArrives() {
        final class List { var names: Set<String> = [] }
        let list = List()
        let match = MatchCoordinator(
            music: FakeMusic(log: log), notifier: FakeNotifier(log: log), listed: { list.names })
        match.handle(.track(ai, .playing))
        #expect(log.events.isEmpty)
        list.names = ["hayley may"]
        match.recheck()
        #expect(log.events.first == "nextTrack")
    }

    @Test func actsOnlyWhileMusicRuns() {
        let match = coordinator(music: FakeMusic(log: log, isRunning: false))
        match.handle(.track(ai, .playing))
        #expect(log.events.isEmpty)
    }

    @Test func readsTheCurrentSongAtLaunch() {
        coordinator(music: FakeMusic(log: log, isRunning: false)).start()
        #expect(log.events.isEmpty)
        coordinator(music: FakeMusic(log: log, fields: nil)).start()
        #expect(log.events == ["read"])
        let fields = ["playing", ai.name, ai.artist, ai.album]
        let match = coordinator(music: FakeMusic(log: log, fields: fields))
        match.start()
        #expect(match.nowPlaying == .track(ai, .playing))
        #expect(log.events == ["read", "read", "nextTrack", "post Skipped Hayley May (AI) | Closure"])
    }
}
