import Testing

@testable import AntiAITunesCore

struct CSVNamesTests {
    @Test func readsTheNamedColumn() {
        // The first rows of the default list.
        let csv = "artist,id\nAtomship,4PbKVheWA7ToOxOrqqzjol\nSmokey September,32PcXsAFr3ArYaHSYr8qGh\n"
        #expect(CSVNames.parse(csv, column: "artist") == ["atomship", "smokey september"])
        #expect(CSVNames.parse(csv, column: "id") == ["4pbkvhewa7tooxorqqzjol", "32pcxsafr3aryahsyr8qgh"])
    }

    @Test func handlesQuotesEscapedQuotesAndLineBreaks() {
        let csv =
            "\u{FEFF}id,artist\r\n1,\"Earth, Wind & Fire\"\r\n2,\"\"\"Weird Al\"\" Yankovic\"\r\n3,\"Crosby, Stills,\nNash & Young\""
        let names = CSVNames.parse(csv, column: "artist")
        #expect(names == ["earth, wind & fire", "\"weird al\" yankovic", "crosby, stills, nash & young"])
    }

    @Test func keepsAQuoteInsideAnUnquotedField() {
        let csv = "artist,id\nNeal \"Big Daddy\" Pattman,1\nAtomship,2\n"
        #expect(CSVNames.parse(csv, column: "artist") == ["neal \"big daddy\" pattman", "atomship"])
    }

    @Test func dropsBlankAndShortNamesAndShortRows() {
        // "D", "ai" and "Ada" are on the default list. "!!!" is a real band that this rule drops.
        let csv =
            "id,artist\n1,\n2,!!!\n3,sunn O)))\n4,D\n5,  ai \n6\n\n7,Ada\n8,...And You Will Know Us By the Trail of Dead"
        #expect(
            CSVNames.parse(csv, column: "artist") == [
                "sunn o)))", "ai", "ada", "...and you will know us by the trail of dead",
            ])
    }

    @Test func rejectsAMissingColumn() {
        #expect(CSVNames.parse("name,id\nAtomship,1", column: "artist") == nil)
        #expect(CSVNames.parse("", column: "artist") == nil)
    }
}
