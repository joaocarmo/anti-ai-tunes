import Testing

@testable import AntiAITunesCore

struct NowPlayingTests {
    let song = Track(name: "Closure", artist: "D.O.D & Hayley May", album: "Closure - Single")
    let other = Track(
        name: "Think About Us", artist: "Sonny Fodera, D.O.D & Poppy Baskcomb", album: "Think About Us - Single")

    @Test func startsWaiting() {
        #expect(MenuState(.waiting).lines == ["Waiting for the next song"])
    }

    @Test func reportsANewSongOnce() {
        var now = NowPlaying.waiting
        let first = now.apply(.track(song, .playing))
        let repeated = now.apply(.track(song, .playing))
        let next = now.apply(.track(other, nil))
        #expect(first)
        #expect(!repeated)
        #expect(next)
        #expect(now == .track(other, .playing))
    }

    @Test func pausesAndResumesTheCurrentSong() {
        var now = NowPlaying.track(song, .playing)
        let changed = now.apply(.state(.paused))
        #expect(!changed)
        #expect(now == .track(song, .paused))
        #expect(MenuState(now).lines == ["Closure", "D.O.D & Hayley May", "Paused"])
        now.apply(.state(.playing))
        #expect(MenuState(now).lines == ["Closure", "D.O.D & Hayley May"])
    }

    @Test func stopsOnAStoppedStateOrSong() {
        var now = NowPlaying.track(song, .playing)
        now.apply(.state(.stopped))
        #expect(now == .notPlaying)
        #expect(MenuState(now).lines == ["Not playing"])
        let changed = now.apply(.track(other, .stopped))
        #expect(!changed)
        #expect(now == .notPlaying)
    }

    @Test func ignoresAStateWhileWaiting() {
        var now = NowPlaying.waiting
        now.apply(.state(.playing))
        #expect(now == .waiting)
    }

    @Test func leavesOutAnEmptyArtist() {
        let stream = Track(name: "Live stream", artist: "", album: "")
        #expect(MenuState(.track(stream, .playing)).lines == ["Live stream"])
    }
}
