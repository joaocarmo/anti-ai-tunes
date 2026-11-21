import Foundation

/// Turns names into a form that compares equal across case, accents and spacing.
enum Normalizer {
    /// Returns `text` case-folded, without diacritics, and with whitespace trimmed and collapsed.
    ///
    /// Keeps punctuation such as dots.
    static func normalize(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }
}
