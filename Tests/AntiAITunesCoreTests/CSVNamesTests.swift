import Testing

@testable import AntiAITunesCore

struct CSVNamesTests {
    @Test func readsTheNamedColumn() {
        let csv = "artist,id\nAtomship,4PbK\nSmokey September,32Pc\n"
        #expect(CSVNames.parse(csv, column: "artist") == ["atomship", "smokey september"])
        #expect(CSVNames.parse(csv, column: "id") == ["4pbk", "32pc"])
    }

    @Test func handlesQuotesEscapedQuotesAndLineBreaks() {
        let csv = "\u{FEFF}id,artist\r\n1,\"Doe, Jane\"\r\n2,\"The \"\"Band\"\"\"\r\n3,\"Two\nLines\""
        #expect(CSVNames.parse(csv, column: "artist") == ["doe, jane", "the \"band\"", "two lines"])
    }

    @Test func dropsBlankAndShortNamesAndShortRows() {
        let csv = "id,artist\n1,\n2,-\n3,...\n4,d\n5,  Ai \n6\n\n7,Ada"
        #expect(CSVNames.parse(csv, column: "artist") == ["ai", "ada"])
    }

    @Test func rejectsAMissingColumn() {
        #expect(CSVNames.parse("name,id\nA,1", column: "artist") == nil)
        #expect(CSVNames.parse("", column: "artist") == nil)
    }
}
