import Foundation
import Testing

@testable import AntiAITunesCore

struct NowPlayingTests {
    let song = Track(name: "Chop Suey!", artist: "System Of A Down", album: "Toxicity")
    let other = Track(name: "Dust on the Wind", artist: "The Velvet Sundown", album: "Floating on Echoes")

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
        #expect(MenuState(nowPlaying: now).lines == ["Chop Suey!", "System Of A Down", "Paused"])
        now.apply(.state(.playing))
        #expect(MenuState(nowPlaying: now).lines == ["Chop Suey!", "System Of A Down"])
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
        var list = ListCache(names: ["atomship", "smokey september"], etag: nil, checkedAt: date)
        let checked = "Checked \(date.formatted(date: .abbreviated, time: .shortened))"
        #expect(MenuState(nowPlaying: .waiting, list: list).listDetails == ["2 artists", checked])
        list.changedAt = date
        let changed = "Changed \(date.formatted(date: .abbreviated, time: .shortened))"
        #expect(MenuState(nowPlaying: .waiting, list: list).listDetails == ["2 artists", changed, checked])
    }

    @Test func offersNotAIAndWarnsWhenNotSaving() {
        let ai = Track(name: "Dust on the Wind", artist: "The Velvet Sundown", album: "Floating on Echoes")
        let skip = Skip(key: ai.key, parts: ["the velvet sundown"], artists: "The Velvet Sundown")
        let menu = MenuState(nowPlaying: .waiting, lastSkip: skip, failure: "disk I/O error")
        #expect(menu.notAI == "Not AI: The Velvet Sundown")
        #expect(menu.warning == "Changes are not saved: disk I/O error")
        #expect(MenuState(nowPlaying: .waiting).notAI == nil)
    }
}
