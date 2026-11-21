import Foundation
import Testing

@testable import AntiAITunesCore

@MainActor
struct MatchCoordinatorTests {
    let log = EventLog()
    let ai = Track(name: "Closure", artist: "D.O.D & Hayley May", album: "Closure - Single")
    let human = Track(name: "Free Your Mind", artist: "Prospa, Cloonee & Sybil", album: "Free Your Mind - Single")

    func coordinator(
        listed: Set<String> = ["hayley may"], music: FakeMusic? = nil, store: Store? = nil, clock: FakeClock? = nil
    ) -> MatchCoordinator {
        MatchCoordinator(
            music: music ?? FakeMusic(log: log), notifier: FakeNotifier(log: log), store: store ?? temporaryStore(),
            clock: clock ?? FakeClock(log: log), listed: { listed })
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
            music: FakeMusic(log: log), notifier: FakeNotifier(log: log), store: temporaryStore(),
            clock: FakeClock(log: log), listed: { list.names })
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

    // Plays `ai`, which is skipped, then `human`, the song that follows it.
    func skipThenFollow(_ match: MatchCoordinator) throws -> Skip {
        match.handle(.track(ai, .playing))
        match.handle(.track(human, .playing))
        log.events.removeAll()
        return try #require(match.lastSkip)
    }

    @Test func notAIAllowsAndGoesBackTwiceWhenTheFirstCallOnlyRestarts() async throws {
        let clock = FakeClock(log: log)
        clock.sleepsLeft = 1
        let store = temporaryStore()
        let match = coordinator(store: store, clock: clock)
        let skip = try skipThenFollow(match)
        #expect(skip == Skip(key: ai.key, parts: ["hayley may"], artists: "Hayley May"))
        await match.notAI(skip)
        #expect(log.events == ["previousTrack", "sleep 1", "previousTrack"])
        #expect(match.lastSkip == nil)
        #expect(store.allowed() == ["hayley may"])
        match.handle(.track(ai, .playing))
        #expect(log.events.count == 3)
    }

    @Test func notAIStopsWhenTheSkippedSongIsBack() async throws {
        final class Box { var match: MatchCoordinator? }
        let box = Box()
        let clock = FakeClock(log: log)
        clock.sleepsLeft = 1
        let ai = ai
        let music = FakeMusic(log: log, onPrevious: { box.match?.handle(.track(ai, .playing)) })
        let match = coordinator(music: music, clock: clock)
        box.match = match
        let skip = try skipThenFollow(match)
        await match.notAI(skip)
        #expect(log.events == ["previousTrack", "sleep 1"])
    }

    @Test func notAIStopsWhenTheWaitIsCancelled() async throws {
        let match = coordinator()
        let skip = try skipThenFollow(match)
        await match.notAI(skip)
        #expect(log.events == ["previousTrack", "sleep 1"])
    }

    @Test func notAIOnlyAllowsAnOlderSkip() async throws {
        let store = temporaryStore()
        let match = coordinator(listed: ["hayley may", "sybil"], store: store)
        match.handle(.track(ai, .playing))
        let older = try #require(match.lastSkip)
        match.handle(.track(human, .playing))
        #expect(match.lastSkip == Skip(key: human.key, parts: ["sybil"], artists: "Sybil"))
        log.events.removeAll()
        await match.notAI(older)
        #expect(log.events.isEmpty)
        #expect(store.allowed() == ["hayley may"])
        #expect(match.lastSkip != nil)
    }

    @Test func notAIDoesNotGoBackOnceAnotherSongStarted() async throws {
        let match = coordinator()
        let skip = try skipThenFollow(match)
        match.handle(.track(Track(name: "Other", artist: "Someone", album: ""), .playing))
        await match.notAI(skip)
        #expect(log.events.isEmpty)
        #expect(match.lastSkip == nil)
    }

    @Test func notAIDoesNotGoBackBeforeTheNextSongStarts() async {
        let match = coordinator()
        match.handle(.track(ai, .playing))
        log.events.removeAll()
        await match.notAI(match.lastSkip!)
        #expect(log.events.isEmpty)
    }

    @Test func notAIDoesNotGoBackWhileMusicIsClosed() async throws {
        let music = FakeMusic(log: log)
        let match = coordinator(music: music)
        let skip = try skipThenFollow(match)
        music.isRunning = false
        await match.notAI(skip)
        #expect(log.events.isEmpty)
    }

    @Test func remembersAllowedArtistsAcrossLaunches() {
        let store = temporaryStore()
        store.allow(["hayley may"], at: .now)
        coordinator(store: store).handle(.track(ai, .playing))
        #expect(log.events.isEmpty)
    }
}
