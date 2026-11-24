import Foundation

/// Converts a kana reading to Latin letters (Hepburn-style, long vowels written out:
/// とうふ → "toufu"), so a reading can be said aloud without knowing kana.
enum Romaji {
    static func convert(_ kana: String) -> String {
        let chars = Array(kana).map(hiragana)
        var out = ""
        var doubleNext = false
        var index = 0

        func emit(_ syllable: String) {
            if doubleNext, let first = syllable.first, !"aiueon".contains(first) {
                out += syllable.hasPrefix("ch") ? "t" : String(first)
            }
            doubleNext = false
            out += syllable
        }

        while index < chars.count {
            let char = chars[index]
            let next: Character? = index + 1 < chars.count ? chars[index + 1] : nil

            if char == "っ" {
                doubleNext = true
            } else if char == "ー" {
                if let last = out.last, "aiueo".contains(last) { out.append(last) }
            } else if let next, let combined = digraph(char, next) {
                emit(combined)
                index += 1
            } else if let syllable = table[char] {
                emit(syllable)
            } else {
                doubleNext = false
                out.append(char)
            }
            index += 1
        }
        return out
    }

    /// Katakana → hiragana; everything else unchanged.
    private static func hiragana(_ char: Character) -> Character {
        guard let scalar = char.unicodeScalars.first, char.unicodeScalars.count == 1,
            (0x30A1...0x30F6).contains(scalar.value),
            let shifted = Unicode.Scalar(scalar.value - 0x60)
        else { return char }
        return Character(shifted)
    }

    /// Two-kana syllables: きゃ → kya, しゅ → shu, ふぁ → fa, てぃ → ti …
    private static func digraph(_ first: Character, _ second: Character) -> String? {
        if let glide = ["ゃ": "a", "ゅ": "u", "ょ": "o"][second], let base = table[first], base.hasSuffix("i") {
            let stem = String(base.dropLast())
            // shi/chi/ji drop the y: sha, chu, jo.
            return ["sh", "ch", "j"].contains(stem) ? stem + glide : stem + "y" + glide
        }
        if let vowel = ["ぁ": "a", "ぃ": "i", "ぅ": "u", "ぇ": "e", "ぉ": "o"][second] {
            switch first {
            case "ふ": return "f" + vowel
            case "て": return "t" + vowel
            case "で": return "d" + vowel
            case "う": return "w" + vowel
            case "ゔ": return "v" + vowel
            case "し": return "sh" + vowel
            case "ち": return "ch" + vowel
            case "じ": return "j" + vowel
            default: return nil
            }
        }
        return nil
    }

    private static let table: [Character: String] = {
        let rows: [(String, [String])] = [
            ("あいうえお", ["a", "i", "u", "e", "o"]),
            ("かきくけこ", ["ka", "ki", "ku", "ke", "ko"]),
            ("がぎぐげご", ["ga", "gi", "gu", "ge", "go"]),
            ("さしすせそ", ["sa", "shi", "su", "se", "so"]),
            ("ざじずぜぞ", ["za", "ji", "zu", "ze", "zo"]),
            ("たちつてと", ["ta", "chi", "tsu", "te", "to"]),
            ("だぢづでど", ["da", "ji", "zu", "de", "do"]),
            ("なにぬねの", ["na", "ni", "nu", "ne", "no"]),
            ("はひふへほ", ["ha", "hi", "fu", "he", "ho"]),
            ("ばびぶべぼ", ["ba", "bi", "bu", "be", "bo"]),
            ("ぱぴぷぺぽ", ["pa", "pi", "pu", "pe", "po"]),
            ("まみむめも", ["ma", "mi", "mu", "me", "mo"]),
            ("やゆよ", ["ya", "yu", "yo"]),
            ("らりるれろ", ["ra", "ri", "ru", "re", "ro"]),
            ("わをん", ["wa", "o", "n"]),
            ("ぁぃぅぇぉ", ["a", "i", "u", "e", "o"]),
            ("ゃゅょ", ["ya", "yu", "yo"]),
            ("ゔ", ["vu"]),
        ]
        var map: [Character: String] = [:]
        for (kana, romaji) in rows {
            for (char, value) in zip(kana, romaji) { map[char] = value }
        }
        return map
    }()
}
