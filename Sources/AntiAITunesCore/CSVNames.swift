/// Reads artist names from a CSV list (RFC 4180).
enum CSVNames {
    /// Returns the normalized names in `column`, without names that have fewer than 2 letters or digits.
    ///
    /// Returns nil when the header has no such column.
    static func parse(_ text: String, column: String) -> [String]? {
        let rows = records(text)
        guard let index = rows.first?.firstIndex(of: column) else { return nil }
        return rows.dropFirst()
            .compactMap { index < $0.count ? Normalizer.normalize($0[index]) : nil }
            .filter { $0.filter { $0.isLetter || $0.isNumber }.count >= 2 }
    }

    static func records(_ text: String) -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = String.UnicodeScalarView()
        var quoted = false
        var scalars = text.unicodeScalars.drop { $0 == "\u{FEFF}" }.makeIterator()
        var next = scalars.next()
        while let scalar = next {
            next = scalars.next()
            switch scalar {
            case "\"" where quoted:
                if next == "\"" {
                    field.append(scalar)
                    next = scalars.next()
                } else {
                    quoted = false
                }
            case _ where quoted: field.append(scalar)
            // A quote opens quoting only at the start of a field. Elsewhere it is a literal character.
            case "\"" where field.isEmpty: quoted = true
            case ",":
                row.append(String(field))
                field = .init()
            case "\n":
                rows.append(row + [String(field)])
                row = []
                field = .init()
            case "\r": break
            default: field.append(scalar)
            }
        }
        if !row.isEmpty || !field.isEmpty { rows.append(row + [String(field)]) }
        return rows
    }
}
