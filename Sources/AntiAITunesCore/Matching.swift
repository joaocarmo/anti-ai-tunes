extension Track {
    private static let separators = [", ", " & ", " x ", " feat. ", " ft. ", " featuring "]
    private static let markers = ["feat. ", "ft. ", "featuring "]
    private static let closers: [Character: Character] = ["(": ")", "[": "]", "{": "}"]

    /// Returns the names to look up: the whole normalized artist, its parts, and featured names from the title.
    ///
    /// The result has no blanks or duplicates.
    func artistParts() -> [String] {
        let featured = Self.featured(in: Normalizer.normalize(name))
        var seen = Set<String>()
        return ([Normalizer.normalize(artist)] + featured)
            .flatMap { [$0] + Self.split($0) }
            .filter { !$0.isEmpty && seen.insert($0).inserted }
    }

    /// Returns the names after `feat.`, `ft.` or `featuring` in a normalized title.
    ///
    /// A marker counts at the start, after a space, or right after `(`, `[` or `{`. After a bracket, the name runs to
    /// the matching closing bracket, so `x (y)` stays whole. Closing brackets right after that one stay in the name, so
    /// `sunn o)))` stays whole. Without a bracket, the name runs to the end or to the next ` (`, ` [` or ` {`.
    private static func featured(in title: String) -> [String] {
        let text = Array(title)
        var names: [String] = []
        var index = 0
        while index < text.count {
            let before = index > 0 ? text[index - 1] : " "
            guard before == " " || closers[before] != nil,
                let marker = markers.first(where: { text[index...].starts(with: $0) })
            else {
                index += 1
                continue
            }
            let start = index + marker.count
            var end = start
            if let closer = closers[before] {
                var depth = 1
                while end < text.count {
                    if text[end] == before { depth += 1 }
                    if text[end] == closer { depth -= 1 }
                    if depth == 0 { break }
                    end += 1
                }
                while end + 1 < text.count, text[end + 1] == closer { end += 1 }
            } else {
                while end < text.count, !(text[end] == " " && end + 1 < text.count && closers[text[end + 1]] != nil) {
                    end += 1
                }
            }
            names.append(String(text[start..<end]))
            index = end
        }
        return names
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
