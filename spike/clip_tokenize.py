#!/usr/bin/env python3
"""Canonical CLIP/open_clip SimpleTokenizer (what MobileCLIP expects).
Reads queries (one per line from a file arg, or the default demo set) and writes
spike/tokens.json mapping each query -> 77 int32 token ids (sot ... eot, zero-padded).
Only dependency: regex (already installed). No torch/transformers.
"""
import gzip, json, sys, os
from functools import lru_cache
import regex as re

ASSETS = os.path.join(os.path.dirname(__file__), "assets", "bpe_simple_vocab_16e6.txt.gz")
CONTEXT = 77

@lru_cache()
def bytes_to_unicode():
    bs = list(range(ord("!"), ord("~")+1)) + list(range(ord("¡"), ord("¬")+1)) + list(range(ord("®"), ord("ÿ")+1))
    cs = bs[:]; n = 0
    for b in range(2**8):
        if b not in bs:
            bs.append(b); cs.append(2**8+n); n += 1
    return dict(zip(bs, [chr(c) for c in cs]))

def get_pairs(word):
    pairs = set(); prev = word[0]
    for ch in word[1:]:
        pairs.add((prev, ch)); prev = ch
    return pairs

def whitespace_clean(text):
    return re.sub(r"\s+", " ", text).strip()

class SimpleTokenizer:
    def __init__(self, bpe_path=ASSETS):
        self.byte_encoder = bytes_to_unicode()
        merges = gzip.open(bpe_path).read().decode("utf-8").split("\n")
        merges = merges[1:49152-256-2+1]
        merges = [tuple(m.split()) for m in merges]
        vocab = list(bytes_to_unicode().values())
        vocab = vocab + [v+"</w>" for v in vocab]
        for m in merges:
            vocab.append("".join(m))
        vocab.extend(["<|startoftext|>", "<|endoftext|>"])
        self.encoder = dict(zip(vocab, range(len(vocab))))
        self.bpe_ranks = dict(zip(merges, range(len(merges))))
        self.cache = {"<|startoftext|>": "<|startoftext|>", "<|endoftext|>": "<|endoftext|>"}
        self.pat = re.compile(
            r"""<\|startoftext\|>|<\|endoftext\|>|'s|'t|'re|'ve|'m|'ll|'d|[\p{L}]+|[\p{N}]|[^\s\p{L}\p{N}]+""",
            re.IGNORECASE)
        self.sot = self.encoder["<|startoftext|>"]; self.eot = self.encoder["<|endoftext|>"]

    def bpe(self, token):
        if token in self.cache: return self.cache[token]
        word = tuple(token[:-1]) + (token[-1]+"</w>",)
        pairs = get_pairs(word)
        if not pairs: return token+"</w>"
        while True:
            bigram = min(pairs, key=lambda p: self.bpe_ranks.get(p, float("inf")))
            if bigram not in self.bpe_ranks: break
            first, second = bigram; new_word = []; i = 0
            while i < len(word):
                try:
                    j = word.index(first, i); new_word.extend(word[i:j]); i = j
                except ValueError:
                    new_word.extend(word[i:]); break
                if word[i] == first and i < len(word)-1 and word[i+1] == second:
                    new_word.append(first+second); i += 2
                else:
                    new_word.append(word[i]); i += 1
            word = tuple(new_word)
            if len(word) == 1: break
            pairs = get_pairs(word)
        word = " ".join(word); self.cache[token] = word
        return word

    def encode(self, text):
        out = []
        for token in re.findall(self.pat, whitespace_clean(text).lower()):
            token = "".join(self.byte_encoder[b] for b in token.encode("utf-8"))
            out.extend(self.encoder[t] for t in self.bpe(token).split(" "))
        return out

    def tokenize(self, text):
        ids = [self.sot] + self.encode(text) + [self.eot]
        ids = ids[:CONTEXT]
        if len(ids) < CONTEXT: ids += [0]*(CONTEXT-len(ids))
        else: ids[-1] = self.eot
        return ids

DEMO = [
    "a person holding an e-reader",
    "a hand holding an e-ink tablet",
    "close-up of a device screen showing text",
    "a person reading a book",
    "a desk with a laptop and monitor",
    "a cozy bedroom",
    "a cup of coffee",
    "person talking to the camera",
    "a cat",
    "sunset over the ocean",
]

def main():
    queries = DEMO
    if len(sys.argv) > 1:
        with open(sys.argv[1]) as f:
            queries = [l.strip() for l in f if l.strip()]
    tok = SimpleTokenizer()
    out = {q: tok.tokenize(q) for q in queries}
    path = os.path.join(os.path.dirname(__file__), "tokens.json")
    with open(path, "w") as f:
        json.dump(out, f, indent=0)
    print(f"wrote {len(out)} queries -> {path}")
    print("sample:", queries[0], "->", out[queries[0]][:12], "...")

if __name__ == "__main__":
    main()
