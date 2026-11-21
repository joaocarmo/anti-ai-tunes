import Foundation
import Testing

@testable import AntiAITunesCore

struct NowPlayingTests {
    let song = Track(name: "Closure", artist: "D.O.D & Hayley May", album: "Closure - Single")
    let other = Track(
        name: "Think About Us", artist: "Sonny Fodera, D.O.D & Poppy Baskcomb", album: "Think About Us - Single")

    @Test func startsWaiting() {
        #expect(MenuState(nowPlaying: .waiting).lines == ["Waiting for the next song"])
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
        #expect(MenuState(nowPlaying: now).lines == ["Closure", "D.O.D & Hayley May", "Paused"])
        now.apply(.state(.playing))
        #expect(MenuState(nowPlaying: now).lines == ["Closure", "D.O.D & Hayley May"])
    }

    @Test func stopsOnAStoppedStateOrSong() {
        var now = NowPlaying.track(song, .playing)
        now.apply(.state(.stopped))
        #expect(now == .notPlaying)
        #expect(MenuState(nowPlaying: now).lines == ["Not playing"])
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
        #expect(MenuState(nowPlaying: .track(stream, .playing)).lines == ["Live stream"])
    }
}

struct MenuStateTests {
    @Test func showsTheListStatus() {
        #expect(MenuState(nowPlaying: .waiting).listDetails == ["Not loaded yet"])
        let date = Date(timeIntervalSince1970: 0)
        var list = ListCache(names: ["a", "b"], etag: nil, checkedAt: date)
        let checked = "Checked \(date.formatted(date: .abbreviated, time: .shortened))"
        #expect(MenuState(nowPlaying: .waiting, list: list).listDetails == ["2 artists", checked])
        list.changedAt = date
        let changed = "Changed \(date.formatted(date: .abbreviated, time: .shortened))"
        #expect(MenuState(nowPlaying: .waiting, list: list).listDetails == ["2 artists", changed, checked])
    }
}
