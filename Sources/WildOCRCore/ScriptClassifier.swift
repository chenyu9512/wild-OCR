import Foundation

/// Character-set routing only. It does NOT pretend that Han text is uniquely
/// Chinese or Japanese, or that Latin script alone identifies English.
public enum ScriptClassifier {
    public static func classify(_ text: String) -> OCRScript {
        var counts: [OCRScript: Int] = [:]
        for scalar in text.unicodeScalars {
            if let script = script(of: scalar) {
                counts[script, default: 0] += 1
            }
        }
        guard let most = counts.max(by: { $0.value < $1.value }) else { return .unknown }
        let total = counts.values.reduce(0, +)
        // Latin words within a predominantly Japanese/Korean sentence should
        // not force the entire block into a multilingual model.
        // Kana and Han together normally indicate Japanese, not a mixed
        // script failure. Keep Latin/etc truly distinct.
        if counts[.kana, default: 0] > 0 && counts[.han, default: 0] > 0 &&
           counts.filter({ $0.key != .kana && $0.key != .han }).values.reduce(0, +) < 3 {
            return .kana
        }
        let competing = counts.filter { $0.key != most.key && $0.value >= 3 }
            .values.reduce(0, +)
        if competing >= 3 && Double(competing) / Double(total) >= 0.25 {
            return .mixed
        }
        if counts[.kana, default: 0] > 0 && counts[.han, default: 0] > 0
            && counts[.latin, default: 0] < 3 { return .kana }
        return most.key
    }

    public static func strongLanguageHint(_ text: String) -> String? {
        let scalars = text.unicodeScalars
        if scalars.contains(where: { (0x3040...0x30FF).contains($0.value) }) { return "ja" }
        if scalars.contains(where: { (0xAC00...0xD7AF).contains($0.value) }) { return "ko" }
        return nil
    }

    private static func script(of scalar: Unicode.Scalar) -> OCRScript? {
        let n = scalar.value
        // Kana and Hangul checked ahead of broader Asian ranges.
        if (0x3040...0x30FF).contains(n) || (0x31F0...0x31FF).contains(n) { return .kana }
        if (0xAC00...0xD7AF).contains(n) || (0x1100...0x11FF).contains(n)
            || (0x3130...0x318F).contains(n) { return .hangul }
        if (0x3400...0x9FFF).contains(n) || (0xF900...0xFAFF).contains(n)
            || (0x20000...0x2FA1F).contains(n) { return .han }
        if (0x0400...0x052F).contains(n) || (0x2DE0...0x2DFF).contains(n) { return .cyrillic }
        if (0x0600...0x06FF).contains(n) || (0x0750...0x077F).contains(n)
            || (0x08A0...0x08FF).contains(n) { return .arabic }
        if (0x0900...0x097F).contains(n) { return .devanagari }
        if (0x0E00...0x0E7F).contains(n) { return .thai }
        if (0x0370...0x03FF).contains(n) { return .greek }
        if (0x0590...0x05FF).contains(n) { return .hebrew }
        if (0x0041...0x007A).contains(n) && CharacterSet.letters.contains(scalar)
            || (0x00C0...0x024F).contains(n) && CharacterSet.letters.contains(scalar)
            || (0x1E00...0x1EFF).contains(n) && CharacterSet.letters.contains(scalar) {
            return .latin
        }
        return nil
    }
}
