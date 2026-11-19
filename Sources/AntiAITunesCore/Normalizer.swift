import Foundation

/// Turns names into a form that compares equal across case, accents and spacing.
public enum Normalizer {
    /// Case-folds, removes diacritics, trims and collapses whitespace. Keeps punctuation such as dots.
    public static func normalize(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }
}
