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
        #expect(split(artist: "Bruno Mars", title: "Finesse (Remix) [feat. Cardi B]") == ["bruno mars", "cardi b"])
        #expect(
            split(artist: "Alicia Keys", title: "Un-thinkable (I'm Ready) [Remix] {feat. Drake}") == [
                "alicia keys", "drake",
            ])
        #expect(
            split(artist: "Sech, Daddy Yankee & J Balvin", title: "Relación (Remix) [feat. ROSALÍA & Farruko]") == [
                "sech, daddy yankee & j balvin", "sech", "daddy yankee", "j balvin", "rosalia & farruko", "rosalia",
                "farruko",
            ])
    }

    @Test func readsFeaturedArtistsWithoutBrackets() {
        #expect(
            split(artist: "Charli xcx & Billie Eilish", title: "Guess featuring Billie Eilish") == [
                "charli xcx & billie eilish", "charli xcx", "billie eilish",
            ])
        #expect(split(artist: "AI", title: "キラキラ feat. カンナ") == ["ai", "カンナ"])
        #expect(
            split(artist: "Lloyd featuring Lil Wayne", title: "You (feat. Lil Wayne)") == [
                "lloyd featuring lil wayne", "lloyd", "lil wayne",
            ])
        // Fictional titles: no real song has these shapes.
        #expect(split(artist: "Example Band", title: "feat. GrimesAI (Remix)") == ["example band", "grimesai"])
        #expect(split(artist: "Example Band", title: "Example Song (Defeat. Remix)") == ["example band"])
    }

    @Test func keepsBracketsInsideFeaturedNames() {
        let ozuna = split(
            artist: "Ozuna, Daddy Yankee & J Balvin",
            title: "Baila Baila Baila (feat. Daddy Yankee, J Balvin, Farruko & Anuel AA) [Remix]")
        #expect(ozuna.last == "anuel aa")
        // Fictional titles with real listed names: no real song credits them this way.
        #expect(
            split(artist: "Example Band", title: "Example Song (feat. リンネ(Rinne))") == ["example band", "リンネ(rinne)"])
        #expect(
            split(artist: "Example Band", title: "Example Song (feat. 樊宇镈(Coulson Fan) & GrimesAI)") == [
                "example band", "樊宇镈(coulson fan) & grimesai", "樊宇镈(coulson fan)", "grimesai",
            ])
        #expect(
            split(artist: "Example Band", title: "Example Song (feat. sunn O))))") == ["example band", "sunn o)))"])
        #expect(split(artist: "Example Band", title: "Example Song (feat. GrimesAI") == ["example band", "grimesai"])
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
        let disliked = Skip(
            key: track.key, parts: ["the velvet sundown"], artists: "The Velvet Sundown", disliked: true)
        #expect(Skip(action: Skip.notAIAction, userInfo: disliked.userInfo) == disliked)
    }

    @Test func readsANotificationWithoutTheDislike() {
        let userInfo: [AnyHashable: Any] = [
            "key": "k", "parts": ["the velvet sundown"], "artists": "The Velvet Sundown",
        ]
        #expect(Skip(action: Skip.notAIAction, userInfo: userInfo)?.disliked == false)
    }

    @Test func readsTheDislikeResult() {
        #expect(Dislike(readBack: "true") == .accepted)
        #expect(Dislike(readBack: "false") == .ignored)
        #expect(Dislike(readBack: nil) == .failed)
        #expect(Dislike(readBack: "missing value") == .failed)
    }
}
