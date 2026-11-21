import Testing

@testable import AntiAITunesCore

struct MatchingTests {
    func split(artist: String, title: String) -> [String] {
        Track(name: title, artist: artist, album: "").artistParts()
    }

    // Credits as Apple Music shows them.
    @Test func splitsCollaborators() {
        let parts = split(artist: "Prospa, Cloonee & Sybil", title: "Free Your Mind (Extended Mix)")
        #expect(parts == ["prospa, cloonee & sybil", "prospa", "cloonee", "sybil"])
    }

    @Test func splitsOnXFeatAndFt() {
        let tiesto = split(
            artist: "Tiësto, Tears for Fears, NIIKO X SWAE & GUDFELLA", title: "Rule The World (Everybody)")
        #expect(
            tiesto == [
                "tiesto, tears for fears, niiko x swae & gudfella", "tiesto", "tears for fears", "niiko", "swae",
                "gudfella",
            ])
        #expect(
            split(artist: "Simbad ft. Steelo", title: "Soul Fever (Remix)") == [
                "simbad ft. steelo", "simbad", "steelo",
            ])
    }

    @Test func readsFeaturedArtistsFromTheTitle() {
        #expect(split(artist: "ANOTR", title: "Talk To You (feat. 54 Ultra)") == ["anotr", "54 ultra"])
        #expect(split(artist: "Lady Gaga", title: "Telephone (feat. Beyoncé)") == ["lady gaga", "beyonce"])
    }

    @Test func leavesOutBlanksAndDuplicates() {
        #expect(split(artist: "", title: "Live stream").isEmpty)
        let parts = split(artist: "Chamillionaire feat. Lil Wayne", title: "Rock Star (feat. Lil Wayne)")
        #expect(parts == ["chamillionaire feat. lil wayne", "chamillionaire", "lil wayne"])
        #expect(
            split(artist: "ANOTR & 54 Ultra", title: "Talk To You (ft. 54 Ultra)") == [
                "anotr & 54 ultra", "anotr", "54 ultra",
            ])
    }

    @Test func matchesListedParts() {
        let verdict = Verdict(parts: ["the velvet sundown"], listed: ["atomship", "the velvet sundown"])
        #expect(verdict.matched == ["the velvet sundown"])
        #expect(verdict.isMatch)
        #expect(!Verdict(parts: ["system of a down"], listed: ["the velvet sundown"]).isMatch)
    }

    @Test func leavesOutAllowedParts() {
        let listed: Set = ["the velvet sundown"]
        #expect(Verdict(parts: ["the velvet sundown"], listed: listed, allowed: listed).matched.isEmpty)
    }

    @Test func readsBackASkipFromItsNotification() {
        let track = Track(name: "Dust on the Wind", artist: "The Velvet Sundown", album: "Floating on Echoes")
        let skip = Skip(key: track.key, parts: ["the velvet sundown"], artists: "The Velvet Sundown")
        #expect(Skip(action: Skip.notAIAction, userInfo: skip.userInfo) == skip)
        #expect(Skip(action: "other", userInfo: skip.userInfo) == nil)
        #expect(Skip(action: Skip.notAIAction, userInfo: ["key": track.key]) == nil)
    }
}
