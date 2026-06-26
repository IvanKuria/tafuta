# Tafuta — Semantic Video Search for Mac: Scoping, Architecture & Design Spec

## Context

**Tafuta** ("find" in Kiswahili) is an **open-source (GPL-3.0)** macOS app that finds a specific
*moment* inside your own videos by describing it in plain language — type
*"woman wearing white blouse in green meadow"* and jump straight to that second, even if the
file is named `IMG_0423.mov`.

The problem is real and widespread: people accumulate large video libraries with useless
filenames and no way to search *inside* the footage. Existing tools (Finder, Photos, Drive)
search by filename/date, not visual content. A Windows-only competitor (**ClipCatalog**)
validates demand; Tafuta's edge is **native macOS polish + fully on-device privacy +
open source**. Promotion is via the user's YouTube channel about Mac apps/tools.

The user originally framed it as a "Google Drive/iCloud replacement," but that bundles two
different products: (a) a **semantic search engine over local video** — the unique,
shippable differentiator — and (b) **cloud storage/sync** — capital-intensive commodity
infrastructure. **v1 = (a) only.**

**Decisions locked with the user:**
- **Scope:** Local search over videos already on disk. No cloud storage/sync in v1.
- **Granularity:** Return the *exact moment/timestamp*, not just the file.
- **Modality:** Visual only for v1 (audio transcription deferred).
- **Inference:** **On-device** (research-backed below).
- **Licensing/business:** **Open source (GPL-3.0), public repo.** Core app free + open;
  room to add a paid Pro/cloud tier later (open-core) — Whisper audio search,
  cloud-accelerated indexing, sync. Distribution: **direct** (notarized + Sparkle); YouTube funnel.
- **App shape:** **Both** — a full main window AND a Raycast/Spotlight-style global-hotkey
  floating launcher, sharing one search engine.
- **Design north star:** **Linear** — minimal, premium, near-monochrome, no gradients.
  Polished dark mode **and** light mode.

---

## Feasibility verdict: Yes, comfortably on-device

The core is **CLIP-style embedding search**: images and text encode into the *same* vector
space, so matching a sentence to a frame is a nearest-neighbor lookup (same class of tech as
Apple/Google Photos search).

| Question | Finding |
|---|---|
| Best on-device model | **Apple MobileCLIP** (S0 ~20MB / S2 ~70MB image encoder), Core ML exports published. S0 ≈ OpenAI ViT-B/16 accuracy at ~5× speed. 512-dim embeddings. |
| Runs on weak Macs? | Yes. S0 ≈1.5ms/frame on an *iPhone* ANE; any M1+ Mac is fine, 8GB M2 sufficient. Tier model by hardware (S0 default / S2 on stronger Macs). |
| Indexing speed | Inference-bound at 1 fps: ~1h video ≈ 3,600 encodes ≈ seconds-to-a-minute. HW decode (VideoToolbox) runs 1000s fps — not the bottleneck. |
| Index storage | int8-quantized 512-dim vectors: **~184MB / 100h**. Negligible. |
| Vector search | `sqlite-vec` (ship-easy) or `usearch` (HNSW). Brute force via Accelerate fine to ~1M vectors (~60–100ms); HNSW/binary quant beyond ~1–2M. |
| **Critical caveat** | Apple's **Vision framework does NOT do text→image** (image-to-image only; Photos' semantic search is private). **Must ship our own CLIP model** — no Apple shortcut. Models bundled or downloaded on first run (~100–300MB). |

**Uncertainty to retire in Phase 0:** no published CLIP throughput benchmark for the M2
specifically (numbers interpolated from iPhone). **Measure real throughput/latency/accuracy
on the 8GB M2 before the full build.**

---

## System architecture (v1, fully on-device)

Native **SwiftUI** app. A shared **`SearchCore`** engine drives both the main window and the
floating launcher. Independently testable components:

1. **Library manager** — user picks folders via `NSOpenPanel`; persist access with
   **security-scoped bookmarks** (survive relaunch/move); `FSEvents` watches for
   added/changed/deleted videos; catalog (path, duration, mod-date, index status) in SQLite.
2. **Frame sampler** — `AVAssetReader` *streaming* decode (NOT `AVAssetImageGenerator`,
   which seeks per-frame and is slow for bulk) + automatic VideoToolbox HW decode. Samples
   ~1 fps with **scene-change dedup** (perceptual-hash delta) to skip near-identical frames
   (cuts work 10–100×). Also emits a **low-res sprite sheet per video** for hover-scrubbing.
3. **Embedder** — MobileCLIP **image encoder** via **Core ML on the ANE** → 512-dim vectors.
   Model size tiered by detected hardware.
4. **Index store** — `sqlite-vec` table: int8 vectors + metadata (`video_id`, `timestamp`,
   thumbnail ref), co-located with the catalog in one SQLite DB.
5. **`SearchCore` query engine** — MobileCLIP **text encoder** (Core ML/MLX) encodes the
   query → nearest-neighbor search → ranked `(video, timestamp, score)`. Shared by both UIs.
6. **Background indexer** — throttled, resumable, recent-first queue on background QoS;
   pauses on battery / under thermal pressure; reports progress to the menu-bar status item.
7. **Main window (SwiftUI)** — `NavigationSplitView`: sidebar (library, saved searches),
   results grid, in-app `AVPlayer`, settings.
8. **Global launcher** — floating, borderless, focused search panel summoned by a
   user-customizable global hotkey (via **`KeyboardShortcuts`**, sandbox/App-Store-safe).
9. **Menu-bar status item** — indexing state ("Indexing 412/1,030" → "Ready"), quick toggle.

**Data flow:** pick folder → enumerate → per new video: decode→sample→embed + sprite →
store. Query → encode text → ANN search → ranked moments → hover-scrub → seek & play.

---

## UI/UX design system (Linear-inspired)

**Principle: copy Linear's *system*, not its skin.** Derive everything from a small token
set; depth = **1px hairline borders + native `Material` blur**, never gradients/heavy shadows.

**Implementation in SwiftUI:**
- **Tokens in an Asset Catalog** color set with Any/Dark appearances → automatic light/dark.
  Two tiers: primitive ramps (internal) → semantic roles (referenced by UI).
- Semantic roles: `bg/canvas`, `bg/surface`, `bg/surface-elevated`, `bg/inset`,
  `border/subtle|default|strong`, `text/primary|secondary|tertiary`,
  `accent`, `accent/fg`, `accent/muted`.
- **Materials** (`.ultraThinMaterial`/`.regularMaterial`) for genuinely-floating layers
  (launcher, popovers, pill cards over content); **solid** semantic colors for the canvas.
- **`.continuous` (squircle) radii** on an **8px grid**: tags `4`, controls/inputs `6`,
  cards/pill-cards `8`, sheets `12`, status pills/avatars `full`.
- **Typography:** SF Pro, **`.medium`/`.semibold`** weights (mirrors Linear's Inter
  510/590), slight negative tracking on large titles. Mono for timestamps/counts. (Optional:
  bundle Inter/Inter Display — OFL — for exact fidelity.)
- **One rationed accent** set as the `AccentColor` asset so native controls inherit it.
  Indigo family: `#5E6AD2` (light) / lighter `#7B89F4` (dark).
- **Motion:** fast, non-bouncy — ~120–200ms ease-out, no overshoot. `.onHover` row/cell
  highlights (Mac-native, not touch).
- **Pitfalls:** no pure-black canvas (use near-black `#08090A`); no shadow stacking in dark
  mode; don't hard-code hex per mode — always go through tokens.

Starter palette (engineered Linear-like; safe to adopt) is captured in the research notes:
dark canvas `#08090A` / surface `#0F1011` / text `#F7F8F8`; light canvas `#FBFBFB` /
surface `#FFFFFF` / text `#16171A`; opacity-based borders (white/black @ 6/10/16%).

Reference apps to study: **Linear** desktop (north star), **Raycast** (launcher + custom
controls), **Notion Calendar** (light/dark parity), **Arc** (materials/motion polish).

---

## Interaction spec

- **Search:** live as-you-type, **~250ms debounce**, cancel in-flight queries, min ~2 chars.
  Keep prior results on screen until new ones arrive (no flash-of-empty); subtle "thinking"
  shimmer rather than a blocking spinner.
- **Results:** relevance-ranked **frame-thumbnail grid**; each shows timestamp + filename +
  a subtle confidence cue. **Hover scrubs** ±a few seconds from the sprite sheet.
  ↑/↓ navigate, **Space = Quick Look-style large preview** (←/→ cycles), **Enter = in-app
  player seeked to the exact second**, **⌘K = per-result actions**.
- **Relevance control:** a **semantic strictness slider** + AND/OR term matching (proven by
  ClipCatalog) to manage fuzzy vector results; sensible default threshold.
- **Onboarding:** value-first screen → folder picker → immediate incremental indexing.
  Lead with **privacy reassurance** ("everything stays on your Mac, no account, no telemetry").
- **Empty state never blank:** show **4–6 tappable example queries** (teaches that you can
  describe visual scenes) + recent searches. Zero-results coaches (loosen strictness / note
  indexing still in progress).
- **Indexing UX:** incremental availability ("420 of 1,030 indexed, more coming"),
  recent-first, **menu-bar status + in-window progress pill**, explicit "one-time, here's
  why" framing, clear "Ready" transition, then ambient upkeep.
- **Accessibility from day one:** labeled thumbnails, `.isButton` traits on tappable frames,
  combined cells, announced indexing status, VoiceOver-tested.

---

## Quality-of-life features (proposed)

**v1 (high value, low marginal cost):**
- **Export/trim clip** + **drag a result thumbnail straight into Finder / other apps**
  (export frame or short clip) — big for the YouTube-creator audience.
- **"Find similar moments"** — click a result → visually similar frames (reuses embeddings /
  Apple Vision image-similarity).
- **Per-result ⌘K actions:** reveal in Finder, copy timestamp link, open in QuickTime at the
  timestamp, export clip.
- **Quick Look preview (Space)**, global hotkey launcher, recent + example queries.

**Later phases:**
- **Saved searches as live smart folders** (auto-update as new video indexes).
- **Combined filters:** semantic query + date/folder/file-type/duration filters.
- **Audio transcription search** (on-device Whisper) — "find by what was said."
- **Image-query mode:** drop in a reference photo → find matching moments.

---

## Cost & business model

**Open source (GPL-3.0), public repo — open-core with room for paid later.**

- **Free tier:** local visual search (folder indexing, exact-moment results, in-app
  playback). The free magic is the marketing — demoed on the YouTube channel.
- **Pro (subscription):** Whisper audio/transcript search, **cloud-accelerated indexing**
  for huge/older libraries, sync, advanced export, "find similar moments." The cloud tier is
  the recurring-cost → recurring-charge anchor that justifies a subscription.
- **Enterprise (later, high-ACV):** shared team indexes, self-host/on-prem, SSO, admin,
  support, SLAs.

**Distribution:** **direct** first — Developer ID + notarization + **Sparkle** updates, with
**Lemon Squeezy/Paddle** as merchant-of-record (handles global tax, license keys, trials,
subscriptions). Avoids App Sandbox friction (the app reads videos across the disk). Then
**Setapp** (instant MRR from its subscriber base) and the **Mac App Store** (discovery, 15%
small-business) as follow-on channels.

**Costs:** Apple Developer Program already owned ($99/yr); on-device runtime ~$0. Cloud
indexing (Pro): self-batched GPU (e.g. Modal L4 ~$0.80/hr, ~1000 img/s) ≈ **sub-cent per
hour of video** — strong margin on a subscription. Index sync (if added): **Cloudflare R2**
(~$15/TB-mo, $0 egress); ~2KB/frame embeddings, not video — near-free. Billing requires a
licensing/auth layer (a later, pre-launch phase).

---

## Scale, edge cases & bottlenecks

**External drives** (core use case — large libraries usually live on externals):
- **Index lives on the Mac's internal disk, never on the external drive** → search keeps
  working when the drive is unplugged; only *playback* needs it reconnected.
- Security-scoped bookmarks track the volume, surviving remounts at different paths
  (`/Volumes/Footage` vs `/Volumes/Footage-1`).
- Disconnect handling: mark those videos "offline" (index retained), pause in-progress
  indexing for that volume, auto-resume on reconnect (FSEvents + volume-mount notifications).
- I/O: at 1 fps we read little data, so even USB HDDs are tolerable; sequential
  `AVAssetReader` (not per-frame seeks) avoids HDD random-seek penalties.

**Hours-long videos** (not a problem):
- **Streaming decode = constant memory regardless of length** (frame-by-frame; never load
  the whole file). A 3h video ≈ 10,800 frames at 1 fps ≈ ~5.5MB int8 + a few minutes compute.
- Scene-change dedup pays off most on long static footage (lectures/security cam collapse to
  few frames). **Checkpoint within a long file** (store last-indexed timestamp) so a crash or
  disconnect doesn't restart a multi-hour file.

**Bottlenecks, ranked:**
1. **Thermal — specific to the dev machine:** the **M2 Air is fanless**, so sustained ANE
   indexing will throttle. #1 practical limiter here. Mitigate: throttle/chunk indexing,
   pause on battery, back off under thermal pressure. (Fan'd Macs won't hit this.)
2. **Embedding inference (ANE)** — dominant compute at 1 fps; sets indexing throughput.
3. **First-index wall-clock for huge libraries** — ~500h with dedup ≈ 2.5–5h one-time;
   thousands of hours = overnight. Mitigate: incremental availability, recent-first, optional
   cloud offload.
4. **External HDD random I/O** — addressed by sequential reads.
5. **Vector search** — only past ~1M frames (~hundreds of hours); switch to HNSW/binary
   quant then. Non-issue for typical libraries.
- Decode, preprocessing, and memory are non-issues at 1 fps sampling.

## Phased roadmap

- **Phase 0 — Spike (de-risk):** Prove MobileCLIP Core ML (image+text) + sqlite-vec on a
  few videos. **Measure on the M2 8GB:** indexing fps, query latency, index size, search
  quality on ~10–20 sample queries. Decide model tier(s). **Build is gated on these numbers.**
- **Phase 1 — Design system + skeleton:** Asset-catalog token system, light/dark, core
  SwiftUI shell (window + launcher + menu-bar), wired to a stub `SearchCore`.
- **Phase 2 — v1 app:** Full pipeline (folder picking + bookmarks, background indexing,
  sprite sheets), search, hover-scrub, Quick Look, in-app player seek, strictness control,
  onboarding/empty states, v1 QoL (export/drag, find-similar, ⌘K actions). **← deliverable.**
- **Phase 3 — Depth:** Whisper audio search, image-query, saved smart folders, combined
  filters.
- **Phase 4 — Optional cloud tier:** paid offload for power/weak machines.

---

## Verification

- **Phase 0 acceptance:** On the M2 8GB, index a known test library; confirm background-
  tolerable indexing throughput, sub-second query latency, correct moment in top results for
  representative queries (incl. the "white blouse / green meadow" type), and index size
  matching the storage math. Include a **multi-hour video** (verify constant memory +
  within-file checkpoint resume) and an **external drive** (verify offline-search works while
  unplugged, indexing pauses/resumes on disconnect/reconnect, and bookmarks survive remount).
- **Phase 1 acceptance:** Visual QA of light + dark against the token spec; launcher summons
  via hotkey; menu-bar status updates.
- **Phase 2 acceptance:** End-to-end on a real library — point at a folder, index in the
  background, run ~20 natural-language queries across people/objects/scenes, hover-scrub to
  confirm, click to land `AVPlayer` on the right second; FSEvents picks up added/removed
  files and re-indexes incrementally; export/drag a clip works; VoiceOver navigates results.
- **Distribution check:** notarized build launches clean on a second Mac (Gatekeeper);
  Sparkle delivers a test update.

---

## Open items (not blocking)

- Confirm exact MobileCLIP `.mlpackage` sizes; whether MobileCLIP2 *text* encoders ship as
  Core ML (some exports lag PyTorch). Decide bundle-vs-download for models on first run.
- Pricing of the eventual cloud tier; whether to also list on the Mac App Store.
- Whether to bundle Inter/Inter Display for exact Linear typographic fidelity vs SF Pro.
