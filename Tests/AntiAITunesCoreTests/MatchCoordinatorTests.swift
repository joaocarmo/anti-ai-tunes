import Foundation
import Testing

@testable import AntiAITunesCore

@MainActor
struct MatchCoordinatorTests {
    let log = EventLog()
    let ai = Track(name: "Closure", artist: "D.O.D & Hayley May", album: "Closure - Single")
    let human = Track(name: "Free Your Mind", artist: "Prospa, Cloonee & Sybil", album: "Free Your Mind - Single")

    func coordinator(listed: Set<String> = ["hayley may"]) -> MatchCoordinator {
        MatchCoordinator(music: FakeMusic(log: log), notifier: FakeNotifier(log: log), listed: { listed })
    }

    @Test func skipsAListedArtistAndNotifies() {
        let match = coordinator()
        match.handle(.track(ai, .playing))
        #expect(log.events == ["nextTrack", "post Skipped D.O.D & Hayley May (AI) | Closure"])
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

    @Test func matchesAFeaturedArtistInTheTitle() {
        let match = coordinator(listed: ["54 ultra"])
        match.handle(.track(Track(name: "Talk To You (feat. 54 Ultra)", artist: "ANOTR", album: ""), nil))
        #expect(log.events == ["nextTrack", "post Skipped ANOTR (AI) | Talk To You (feat. 54 Ultra)"])
    }
}
