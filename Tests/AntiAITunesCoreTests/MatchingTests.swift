import Testing

@testable import AntiAITunesCore

struct MatchingTests {
    func split(artist: String, title: String) -> [String] {
        Track(name: title, artist: artist, album: "").artistParts()
    }

    @Test func splitsCollaborators() {
        let parts = split(artist: "Prospa, Cloonee & Sybil", title: "Free Your Mind")
        #expect(parts == ["prospa, cloonee & sybil", "prospa", "cloonee", "sybil"])
    }

    @Test func splitsOnXFeatAndFt() {
        #expect(split(artist: "A X B", title: "") == ["a x b", "a", "b"])
        #expect(split(artist: "A feat. B ft. C", title: "") == ["a feat. b ft. c", "a", "b", "c"])
    }

    @Test func readsFeaturedArtistsFromTheTitle() {
        let parts = split(artist: "ANOTR", title: "Talk To You (feat. 54 Ultra & Él)")
        #expect(parts == ["anotr", "54 ultra & el", "54 ultra", "el"])
        #expect(split(artist: "A", title: "Song (Ft. B)") == ["a", "b"])
    }

    @Test func leavesOutBlanksAndDuplicates() {
        #expect(split(artist: "", title: "Live stream").isEmpty)
        #expect(split(artist: "A & A", title: "Song (feat. A)") == ["a & a", "a"])
    }

    @Test func matchesListedParts() {
        let verdict = Verdict(parts: ["a & b", "a", "b"], listed: ["b", "c"])
        #expect(verdict.matched == ["b"])
        #expect(verdict.isMatch)
        #expect(!Verdict(parts: ["a"], listed: ["b"]).isMatch)
    }

    @Test func leavesOutAllowedParts() {
        #expect(Verdict(parts: ["a & b", "a", "b"], listed: ["a", "b"], allowed: ["b"]).matched == ["a"])
    }

    @Test func readsBackASkipFromItsNotification() {
        let skip = Skip(key: "k", parts: ["a", "b"], artists: "A, B")
        #expect(Skip(action: Skip.notAIAction, userInfo: skip.userInfo) == skip)
        #expect(Skip(action: "other", userInfo: skip.userInfo) == nil)
        #expect(Skip(action: Skip.notAIAction, userInfo: ["key": "k"]) == nil)
    }
}
