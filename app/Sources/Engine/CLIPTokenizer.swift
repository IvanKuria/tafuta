import Foundation

// Native CLIP / open_clip byte-pair tokenizer (what MobileCLIP's text encoder expects).
// Swift port of the canonical SimpleTokenizer — verified to match the Python reference.
final class CLIPTokenizer {
    static let contextLength = 77

    private struct Pair: Hashable { let a: String; let b: String }

    private var byteEncoder: [UInt8: String] = [:]
    private var encoder: [String: Int] = [:]
    private var bpeRanks: [Pair: Int] = [:]
    private var cache: [String: String] = ["<|startoftext|>": "<|startoftext|>",
                                            "<|endoftext|>": "<|endoftext|>"]
    private let sot: Int
    private let eot: Int
    private let pattern: NSRegularExpression

    init?(vocabURL: URL) {
        // bytes_to_unicode(): build the byte<->unicode mapping in a fixed order.
        var bs: [Int] = Array(33...126) + Array(161...172) + Array(174...255)
        var cs: [Int] = bs
        var n = 0
        for b in 0..<256 where !bs.contains(b) { bs.append(b); cs.append(256 + n); n += 1 }
        var orderedChars: [String] = []
        for (b, c) in zip(bs, cs) {
            let ch = String(UnicodeScalar(c)!)
            byteEncoder[UInt8(b)] = ch
            orderedChars.append(ch)
        }

        guard let text = try? String(contentsOf: vocabURL, encoding: .utf8) else { return nil }
        let lines = text.components(separatedBy: "\n")
        let upper = min(49152 - 256 - 2 + 1, lines.count)   // matches the reference slice
        var merges: [Pair] = []
        merges.reserveCapacity(upper)
        for i in 1..<upper {
            let parts = lines[i].split(separator: " ")
            if parts.count == 2 { merges.append(Pair(a: String(parts[0]), b: String(parts[1]))) }
        }

        // vocab = base chars + base+"</w>" + merged pairs + specials
        var vocab = orderedChars
        vocab += orderedChars.map { $0 + "</w>" }
        vocab += merges.map { $0.a + $0.b }
        vocab += ["<|startoftext|>", "<|endoftext|>"]
        for (i, tok) in vocab.enumerated() { encoder[tok] = i }
        for (i, m) in merges.enumerated() { bpeRanks[m] = i }
        sot = encoder["<|startoftext|>"]!
        eot = encoder["<|endoftext|>"]!

        let pat = "<\\|startoftext\\|>|<\\|endoftext\\|>|'s|'t|'re|'ve|'m|'ll|'d|" +
                  "[\\p{L}]+|[\\p{N}]|[^\\s\\p{L}\\p{N}]+"
        guard let re = try? NSRegularExpression(pattern: pat, options: [.caseInsensitive]) else { return nil }
        pattern = re
    }

    private func pairs(_ word: [String]) -> Set<Pair> {
        var result = Set<Pair>()
        guard word.count > 1 else { return result }
        for i in 0..<(word.count - 1) { result.insert(Pair(a: word[i], b: word[i + 1])) }
        return result
    }

    private func bpe(_ token: String) -> String {
        if let c = cache[token] { return c }
        var word = token.map { String($0) }
        guard !word.isEmpty else { return token }
        word[word.count - 1] += "</w>"
        var ps = pairs(word)
        if ps.isEmpty { return token + "</w>" }

        while true {
            // bigram with the lowest merge rank
            var best: Pair? = nil
            var bestRank = Int.max
            for p in ps {
                if let r = bpeRanks[p], r < bestRank { bestRank = r; best = p }
            }
            guard let bigram = best else { break }
            let (first, second) = (bigram.a, bigram.b)
            var newWord: [String] = []
            var i = 0
            while i < word.count {
                if let j = word[i...].firstIndex(of: first) {
                    newWord.append(contentsOf: word[i..<j])
                    i = j
                } else {
                    newWord.append(contentsOf: word[i...])
                    break
                }
                if word[i] == first, i < word.count - 1, word[i + 1] == second {
                    newWord.append(first + second); i += 2
                } else {
                    newWord.append(word[i]); i += 1
                }
            }
            word = newWord
            if word.count == 1 { break }
            ps = pairs(word)
        }
        let result = word.joined(separator: " ")
        cache[token] = result
        return result
    }

    private func encode(_ text: String) -> [Int] {
        let cleaned = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        var tokens: [Int] = []
        let ns = cleaned as NSString
        pattern.enumerateMatches(in: cleaned, range: NSRange(location: 0, length: ns.length)) { m, _, _ in
            guard let m = m else { return }
            let piece = ns.substring(with: m.range)
            let mapped = piece.utf8.map { byteEncoder[$0] ?? "" }.joined()
            for t in bpe(mapped).split(separator: " ") {
                if let id = encoder[String(t)] { tokens.append(id) }
            }
        }
        return tokens
    }

    /// Returns a fixed-length (77) array of Int32 token ids: sot … eot, zero-padded.
    func tokenize(_ text: String) -> [Int32] {
        var ids = [sot] + encode(text) + [eot]
        if ids.count > Self.contextLength {
            ids = Array(ids.prefix(Self.contextLength))
            ids[Self.contextLength - 1] = eot
        } else {
            ids += Array(repeating: 0, count: Self.contextLength - ids.count)
        }
        return ids.map(Int32.init)
    }
}
