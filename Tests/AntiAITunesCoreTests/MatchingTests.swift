import Testing

@testable import AntiAITunesCore

struct MatchingTests {
    @Test func splitsCollaborators() {
        let parts = ArtistParts.parts(artist: "Prospa, Cloonee & Sybil", title: "Free Your Mind")
        #expect(parts == ["prospa, cloonee & sybil", "prospa", "cloonee", "sybil"])
    }

    @Test func splitsOnXFeatAndFt() {
        #expect(ArtistParts.parts(artist: "A X B", title: "") == ["a x b", "a", "b"])
        #expect(ArtistParts.parts(artist: "A feat. B ft. C", title: "") == ["a feat. b ft. c", "a", "b", "c"])
    }

    @Test func readsFeaturedArtistsFromTheTitle() {
        let parts = ArtistParts.parts(artist: "ANOTR", title: "Talk To You (feat. 54 Ultra & Él)")
        #expect(parts == ["anotr", "54 ultra & el", "54 ultra", "el"])
        #expect(ArtistParts.parts(artist: "A", title: "Song (Ft. B)") == ["a", "b"])
    }

    @Test func leavesOutBlanksAndDuplicates() {
        #expect(ArtistParts.parts(artist: "", title: "Live stream").isEmpty)
        #expect(ArtistParts.parts(artist: "A & A", title: "Song (feat. A)") == ["a & a", "a"])
    }

    @Test func matchesListedParts() {
        let verdict = Verdict(parts: ["a & b", "a", "b"], listed: ["b", "c"])
        #expect(verdict.matched == ["b"])
        #expect(verdict.isMatch)
        #expect(!Verdict(parts: ["a"], listed: ["b"]).isMatch)
    }
}
