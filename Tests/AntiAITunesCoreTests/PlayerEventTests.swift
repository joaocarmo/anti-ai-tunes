import Testing

@testable import AntiAITunesCore

/// Payloads recorded from Music on macOS 27.0.1 for streamed songs.
enum Fixture {
    static var freeYourMind: [AnyHashable: Any] {
        [
            "Genre": "Dance",
            "Album": "Free Your Mind - Single",
            "Total Time": 201000,
            "Name": "Free Your Mind",
            "Player State": "Playing",
            "Composer": "Guiorgi Smith, Harvey Blumler, Dave Bissett, Sam Mack & Victor Simonelli",
            "Artist": "Prospa, Cloonee & Sybil",
        ]
    }
    static var stateOnly: [AnyHashable: Any] { ["Player State": "Stopped"] }
}

struct PlayerEventTests {
    @Test func parsesASongMessage() {
        let event = PlayerEvent(userInfo: Fixture.freeYourMind)
        let track = Track(name: "Free Your Mind", artist: "Prospa, Cloonee & Sybil", album: "Free Your Mind - Single")
        #expect(event == .track(track, .playing))
    }

    @Test func parsesAStateOnlyMessage() {
        #expect(PlayerEvent(userInfo: Fixture.stateOnly) == .state(.stopped))
    }

    @Test func rejectsAMessageWithoutSongOrState() {
        #expect(PlayerEvent(userInfo: [:]) == nil)
        #expect(PlayerEvent(userInfo: ["Name": "", "Player State": "Rewinding"]) == nil)
    }

    @Test func keepsASongWithoutArtistOrAlbum() {
        let event = PlayerEvent(userInfo: ["Name": "Live stream"])
        #expect(event == .track(Track(name: "Live stream", artist: "", album: ""), nil))
    }

    @Test func parsesTheLaunchSnapshot() {
        let event = PlayerEvent(snapshot: ["paused", "Closure", "D.O.D & Hayley May", "Closure - Single"])
        #expect(
            event == .track(Track(name: "Closure", artist: "D.O.D & Hayley May", album: "Closure - Single"), .paused))
        #expect(PlayerEvent(snapshot: ["stopped", "", "", ""]) == .state(.stopped))
        #expect(PlayerEvent(snapshot: ["playing"]) == nil)
    }

    @Test func keyIgnoresCaseAccentsSpacingAndTotalTime() {
        var changed = Fixture.freeYourMind
        changed["Total Time"] = 201700
        changed["Artist"] = "  PROSPA,  Clooneé & Sybil "
        let first = PlayerEvent(userInfo: Fixture.freeYourMind)
        let second = PlayerEvent(userInfo: changed)
        guard case .track(let a, _) = first, case .track(let b, _) = second else {
            Issue.record("expected song events")
            return
        }
        #expect(a.key == b.key)
    }

    @Test func normalizerKeepsDots() {
        #expect(Normalizer.normalize(" D.O.D ") == "d.o.d")
    }
}
