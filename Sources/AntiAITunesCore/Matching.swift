extension Track {
    private static let separators = [", ", " & ", " x ", " feat. ", " ft. "]

    /// Returns the names to look up: the whole normalized artist, its parts, and featured names from the title.
    ///
    /// The result has no blanks or duplicates.
    func artistParts() -> [String] {
        let featured = Normalizer.normalize(name).matches(of: #/\((?:feat|ft)\. ([^)]+)\)/#).map { String($0.1) }
        var seen = Set<String>()
        return ([Normalizer.normalize(artist)] + featured)
            .flatMap { [$0] + Self.split($0) }
            .filter { !$0.isEmpty && seen.insert($0).inserted }
    }

    private static func split(_ name: String) -> [String] {
        separators.reduce([name]) { pieces, separator in pieces.flatMap { $0.components(separatedBy: separator) } }
            .map(Normalizer.normalize)
    }
}

/// The parts of an artist credit that are on the list and not allowed.
struct Verdict: Equatable, Sendable {
    let matched: [String]

    var isMatch: Bool { !matched.isEmpty }

    init(parts: [String], listed: Set<String>, allowed: Set<String> = []) {
        matched = parts.filter { listed.contains($0) && !allowed.contains($0) }
    }
}
