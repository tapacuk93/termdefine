import Foundation

/// A triple-click in Terminal.app selects the whole *line*, not a word, so we have to
/// pick the interesting token out of e.g. `taras@mac ~ % git commit --amend`.
enum Tokenizer {

    /// Characters commonly glued to a token by a shell prompt or punctuation.
    private static let trimSet = CharacterSet(charactersIn: " \t\n\r\"'`(),;:|&<>[]{}“”‘’…")

    static func tokens(in line: String) -> [String] {
        let raw = line.split(whereSeparator: { $0 == " " || $0 == "\t" || $0 == "\n" || $0 == "\r" })
        var out: [String] = []
        var seen = Set<String>()
        for piece in raw {
            let token = String(piece).trimmingCharacters(in: trimSet)
            guard !token.isEmpty, token.count <= 60 else { continue }
            guard !seen.contains(token) else { continue }
            seen.insert(token)
            out.append(token)
        }
        return out
    }

    /// The token most likely to be what the user wanted explained.
    static func primary(from tokens: [String]) -> String? {
        let candidates = tokens.filter { !isPromptNoise($0) }
        // Prefer something we can actually explain from the built-in glossary.
        if let known = candidates.first(where: { Glossary.entry(for: $0) != nil }) { return known }
        // Otherwise the first real word (skip flags and paths — they're rarely the question).
        if let word = candidates.first(where: { !$0.hasPrefix("-") && !$0.contains("/") }) { return word }
        return candidates.first ?? tokens.first
    }

    /// Prompt decoration: `user@host`, `~`, `%`, `$`, `#`, `>`, timestamps, path segments.
    private static func isPromptNoise(_ token: String) -> Bool {
        if token.count == 1, "%$#>~❯➜✗✓•|".contains(token) { return true }
        if token.contains("@") { return true }
        if token == "~" || token.hasPrefix("~/") { return true }
        if token.allSatisfy({ $0.isNumber || $0 == ":" || $0 == "-" || $0 == "." }) { return true }
        return false
    }

    /// Strip leading dashes so `--verbose` can still be recognised as `verbose`.
    static func normalizedFlag(_ token: String) -> String? {
        guard token.hasPrefix("-"), token.count > 1 else { return nil }
        return String(token.drop(while: { $0 == "-" }))
    }
}
