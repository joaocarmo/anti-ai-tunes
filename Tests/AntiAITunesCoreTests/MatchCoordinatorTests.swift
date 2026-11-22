import Foundation
import GRDB
import Testing

@testable import AntiAITunesCore

@MainActor
struct MatchCoordinatorTests {
    let log = EventLog()
    // The Velvet Sundown is on the default AI list. Metadata as Apple Music shows it.
    let ai = Track(name: "Dust on the Wind", artist: "The Velvet Sundown", album: "Floating on Echoes")
    let human = Track(name: "Chop Suey!", artist: "System Of A Down", album: "Toxicity")

    func coordinator(
        listed: Set<String> = ["the velvet sundown"], music: FakeMusic? = nil, store: Store? = nil,
        clock: FakeClock? = nil
    ) -> MatchCoordinator {
        MatchCoordinator(
            music: music ?? FakeMusic(log: log), notifier: FakeNotifier(log: log), store: store ?? temporaryStore(),
            clock: clock ?? FakeClock(log: log), listed: { listed })
    }

    @Test func skipsAListedArtistAndNotifies() {
        let match = coordinator()
        match.handle(.track(ai, .playing))
        #expect(log.events == ["dislike", "nextTrack", "post Skipped The Velvet Sundown (AI) | Dust on the Wind"])
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
        #expect(log.events.first == "dislike")
    }

    @Test func checksEachSongOnceUntilAnotherStarts() {
        let match = coordinator()
        match.handle(.track(ai, .playing))
        match.handle(.track(ai, .playing))
        match.handle(.state(.paused))
        match.handle(.state(.playing))
        #expect(log.events.count == 3)
        match.handle(.track(human, .paused))
        match.handle(.track(ai, .playing))
        #expect(log.events.count == 6)
    }

    @Test func namesAFeaturedArtistFromTheTitle() {
        // A fictional credit: no real song features The Velvet Sundown.
        let match = coordinator(listed: ["grimesai"])
        let song = Track(
            name: "Cold Touch (feat. GrimesAI)", artist: "kito", album: "Cold Touch (feat. GrimesAI) - Single")
        match.handle(.track(song, nil))
        #expect(log.events == ["dislike", "nextTrack", "post Skipped GrimesAI (AI) | Cold Touch (feat. GrimesAI)"])
    }

    @Test func fallsBackToTheNormalizedName() {
        #expect(
            MatchCoordinator.displayName("the velvet sundown", in: "The  Velvet Sundown Dust") == "the velvet sundown")
        #expect(MatchCoordinator.displayName("beyonce", in: "Beyoncé Halo") == "Beyoncé")
    }

    @Test func waitsForTheListAndChecksAgainWhenItArrives() {
        final class List { var names: Set<String> = [] }
        let list = List()
        let match = MatchCoordinator(
            music: FakeMusic(log: log), notifier: FakeNotifier(log: log), store: temporaryStore(),
            clock: FakeClock(log: log), listed: { list.names })
        match.handle(.track(ai, .playing))
        #expect(log.events.isEmpty)
        list.names = ["the velvet sundown"]
        match.recheck()
        #expect(log.events.first == "dislike")
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
        #expect(
            log.events == [
                "read", "read", "dislike", "nextTrack", "post Skipped The Velvet Sundown (AI) | Dust on the Wind",
            ])
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
        #expect(skip == Skip(key: ai.key, parts: ["the velvet sundown"], artists: "The Velvet Sundown"))
        await match.notAI(skip)
        #expect(log.events == ["previousTrack", "sleep 1", "previousTrack"])
        #expect(match.lastSkip == nil)
        #expect(store.allowed() == ["the velvet sundown"])
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
        let newer = Track(name: "End the Pain", artist: "The Velvet Sundown", album: "Floating on Echoes")
        let match = coordinator(store: store)
        match.handle(.track(ai, .playing))
        let older = try #require(match.lastSkip)
        match.handle(.track(newer, .playing))
        #expect(match.lastSkip == Skip(key: newer.key, parts: ["the velvet sundown"], artists: "The Velvet Sundown"))
        log.events.removeAll()
        await match.notAI(older)
        #expect(log.events.isEmpty)
        #expect(store.allowed() == ["the velvet sundown"])
        #expect(match.lastSkip != nil)
    }

    @Test func notAIDoesNotGoBackOnceAnotherSongStarted() async throws {
        let match = coordinator()
        let skip = try skipThenFollow(match)
        match.handle(.track(Track(name: "Aerials", artist: "System Of A Down", album: "Toxicity"), .playing))
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
        store.allow(["the velvet sundown"], at: .now)
        coordinator(store: store).handle(.track(ai, .playing))
        #expect(log.events.isEmpty)
    }

    @Test func recordsEachSongAndWhatTheAppDid() throws {
        let store = temporaryStore()
        let match = coordinator(store: store)
        match.handle(.track(human, .paused))
        match.handle(.state(.playing))
        match.recheck()
        match.handle(.track(ai, .playing))
        let rows = try #require(store.queue).read {
            try String.fetchAll(
                $0,
                sql: """
                    SELECT name || ' | ' || ifnull(action, '-') || ' | ' || ifnull(dislike, '-') || ' | ' || notified
                    FROM play ORDER BY id
                    """)
        }
        #expect(rows == ["Chop Suey! | - | - | 0", "Dust on the Wind | skip | ignored | 1"])
    }

    @Test func skipsWhenTheDislikeFails() throws {
        let match = coordinator(music: FakeMusic(log: log, readBack: nil))
        match.handle(.track(ai, .playing))
        #expect(log.events == ["dislike", "nextTrack", "post Skipped The Velvet Sundown (AI) | Dust on the Wind"])
        #expect(try #require(match.lastSkip).disliked == false)
    }

    @Test func notAIClearsADislikeThatStuckOnceTheSongIsBack() async throws {
        final class Box { var match: MatchCoordinator? }
        let box = Box()
        let clock = FakeClock(log: log)
        clock.sleepsLeft = 1
        let ai = ai
        let music = FakeMusic(log: log, readBack: "true", onPrevious: { box.match?.handle(.track(ai, .playing)) })
        let match = coordinator(music: music, clock: clock)
        box.match = match
        let skip = try skipThenFollow(match)
        #expect(skip.disliked)
        await match.notAI(skip)
        #expect(log.events == ["previousTrack", "clearDislike", "sleep 1"])
    }

    @Test func notAIDoesNotClearTheDislikeWhileMusicIsClosed() async throws {
        final class Box {
            var match: MatchCoordinator?
            var music: FakeMusic?
        }
        let box = Box()
        let ai = ai
        let music = FakeMusic(
            log: log, readBack: "true",
            onPrevious: {
                box.music?.isRunning = false
                box.match?.handle(.track(ai, .playing))
            })
        let match = coordinator(music: music)
        box.match = match
        box.music = music
        let skip = try skipThenFollow(match)
        await match.notAI(skip)
        #expect(log.events == ["previousTrack", "sleep 1"])
    }

    @Test func notAIClearsTheDislikeOnlyOnTheSkippedSong() async throws {
        let match = coordinator(music: FakeMusic(log: log, readBack: "true"))
        let skip = try skipThenFollow(match)
        await match.notAI(skip)
        match.handle(.track(Track(name: "Aerials", artist: "System Of A Down", album: "Toxicity"), .playing))
        match.handle(.track(ai, .playing))
        #expect(!log.events.contains("clearDislike"))
    }

    @Test func saysWhenASongHasNoArtist() {
        // Fictional: a stream title without an artist.
        let match = coordinator()
        match.handle(.track(Track(name: "Example Radio Show", artist: " ", album: ""), .playing))
        match.recheck()
        #expect(log.events == ["post Couldn't detect the artist for Example Radio Show |  | no actions"])
    }

    @Test func skipsAFeaturedArtistWhenTheArtistIsMissing() {
        // Fictional: no real song credits GrimesAI only in the title.
        let match = coordinator(listed: ["grimesai"])
        match.handle(.track(Track(name: "Example Song (feat. GrimesAI)", artist: "", album: ""), .playing))
        #expect(log.events == ["dislike", "nextTrack", "post Skipped GrimesAI (AI) | Example Song (feat. GrimesAI)"])
    }

    @Test func capsNotificationsPerSongAndLocalDay() throws {
        var calendar = Calendar(identifier: .gregorian)
        // The clock starts at 17h00min on 15 January 2027 in UTC+9, so local midnight is 7 hours later.
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 9 * 3600))
        let clock = FakeClock(log: log)
        let match = MatchCoordinator(
            music: FakeMusic(log: log), notifier: FakeNotifier(log: log), store: temporaryStore(), clock: clock,
            calendar: calendar, listed: { ["the velvet sundown"] })
        func playAI() {
            match.handle(.track(ai, .playing))
            match.handle(.track(human, .playing))
        }
        for _ in 1...4 { playAI() }
        #expect(log.events.filter { $0.hasPrefix("post") }.count == 3)
        #expect(log.events.filter { $0 == "nextTrack" }.count == 4)
        clock.now += 7 * 3600 - 1
        playAI()
        #expect(log.events.filter { $0.hasPrefix("post") }.count == 3)
        clock.now += 1
        playAI()
        #expect(log.events.filter { $0.hasPrefix("post") }.count == 4)
    }
}
