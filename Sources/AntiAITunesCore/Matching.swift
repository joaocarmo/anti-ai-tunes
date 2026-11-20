/// Splits an artist credit into the names to look up.
public enum ArtistParts {
    static let separators = [", ", " & ", " x ", " feat. ", " ft. "]

    /// The whole normalized artist, its parts, and featured names from the title. No blanks or duplicates.
    public static func parts(artist: String, title: String) -> [String] {
        let featured = Normalizer.normalize(title).matches(of: #/\((?:feat|ft)\. ([^)]+)\)/#).map { String($0.1) }
        var seen = Set<String>()
        return ([Normalizer.normalize(artist)] + featured)
            .flatMap { [$0] + split($0) }
            .filter { !$0.isEmpty && seen.insert($0).inserted }
    }

    static func split(_ name: String) -> [String] {
        separators.reduce([name]) { pieces, separator in pieces.flatMap { $0.components(separatedBy: separator) } }
            .map(Normalizer.normalize)
    }
}

/// The parts of an artist credit that are on the list.
public struct Verdict: Equatable, Sendable {
    public let matched: [String]

    public var isMatch: Bool { !matched.isEmpty }

    public init(parts: [String], listed: Set<String>) {
        matched = parts.filter(listed.contains)
    }
}
