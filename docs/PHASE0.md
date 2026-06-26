# Phase 0 Spike — Results

**Goal:** de-risk the two unknowns that gate the whole build — (1) is on-device MobileCLIP
*fast enough* on an entry Apple Silicon Mac, and (2) is retrieval *good enough* to find the
right moment from a natural-language description. **Both: yes, with evidence.**

Hardware: MacBook Air M2, 8GB RAM, **fanless**. Model: Apple MobileCLIP **S0** (Core ML).

## 1. Throughput (image encoder)

Pure inference, static frame, Neural Engine (`spike/bench_image.swift`):

| Compute | Cold start | Sustained | Throughput |
|---|---|---|---|
| Neural Engine | 4.2 ms | **1.12 ms/frame** | **~890 fps** |
| GPU (`all`) | 2.3 ms | 1.14 ms/frame | ~876 fps |
| CPU only | 17.7 ms | 9.19 ms/frame | 109 fps |

~890 fps is ~10× the research estimate. At 1 fps sampling, **embedding is not the
bottleneck** — 1 h of video ≈ 3,600 frames ≈ ~4 s of inference.

## 2. End-to-end retrieval quality

Corpus: 4 videos, **431 frames** at 1 fps (target = an e-reader review; 3 distractors).
Indexed in **13.6 s = 32 fps** — note this used the *slow* per-frame-seek
`AVAssetImageGenerator`; decode/seek dominates, not inference. The shipping app will use
`AVAssetReader` streaming (much faster). Text tokenized with the canonical CLIP BPE
(`spike/clip_tokenize.py`).

Representative results (cosine score, video @ timestamp), all **visually verified**:

| Query | Top hit | Score |
|---|---|---|
| a person holding an e-reader | e-reader video @ 2:53 (hand holding device) ✓ | 0.297 |
| a hand holding an e-ink tablet | e-reader video @ 2:48 ✓ | 0.280 |
| close-up of a device screen showing text | e-reader video @ 2:23 (macro of screen) ✓ | 0.248 |
| a cat | **distractor** video @ 2:12 (cat image on screen) ✓ | 0.217 |
| sunset over the ocean (absent) | weak best match | **0.107** |

**Key findings:**
- Correct video **and** exact moment for content that is present.
- Cross-video discrimination works (the lone "cat" frame was found in the right distractor).
- Absent concepts score ~3× lower (0.107 vs ~0.29) — validates a **strictness threshold**
  to separate real matches from noise.

## Conclusions / decisions

- **MobileCLIP S0 is sufficient** for v1 quality on entry hardware. S2 can be an optional
  upgrade for stronger Macs, but S0 already retrieves confidently.
- **Indexing will be decode/IO-bound**, so invest in `AVAssetReader` streaming + scene-change
  dedup (per the plan) rather than worrying about inference speed.
- Ship a **strictness control** thresholding on cosine score; ~0.10 is noise, ~0.25+ is a
  strong match for S0 (tune in-app).
- Proceed to Phase 1 (design system + app skeleton).

## Reproduce

```sh
# models (gitignored): downloaded from apple/coreml-mobileclip into models/
python3 spike/clip_tokenize.py                 # -> spike/tokens.json
swift spike/bench_image.swift                  # throughput
swift spike/retrieve.swift "<video1>" ...      # retrieval
swift spike/dump_frame.swift "<video>" <secs> out.png   # verify a hit
```
