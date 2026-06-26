# Tafuta

**Find the moment, not just the file.**

Tafuta (Kiswahili for *"find"*) is a macOS app that lets you search **inside** your own
videos with plain language. Describe a moment — *"woman wearing a white blouse in a green
meadow"* — and Tafuta jumps straight to that second of the clip, even if the file is named
`IMG_0423.mov`.

> **Proprietary — private repository.** Tafuta is a commercial product. This source is
> confidential and all rights are reserved. See [`LICENSE`](LICENSE).

It's built for people with large video libraries (creators, filmmakers, anyone with a
camera roll out of control) where filenames and dates are useless for finding *that one
shot*.

## Why it's different

- **It searches what's on screen, not the filename.** Powered by on-device CLIP-style
  embeddings (Apple's MobileCLIP via Core ML), Tafuta understands the *content* of each frame.
- **100% on your Mac.** All indexing and search run locally on the Apple Neural Engine. No
  uploads, no account, no telemetry. Your video never leaves your device.
- **Jumps to the exact moment.** Results are timestamps inside videos, not just a list of
  files — click and playback starts right there.
- **Fast, minimal, native.** A premium SwiftUI interface with a main window and a
  global-hotkey launcher, in polished light and dark modes.

## Status

🚧 **Early development.** Currently validating the core (Phase 0 spike): MobileCLIP retrieval
quality and indexing throughput on Apple Silicon. See [`docs/PLAN.md`](docs/PLAN.md) for the
full architecture, design system, and roadmap.

## Business model

Freemium with a **Pro subscription** (recurring MRR):

- **Free** — local visual search: folder indexing, exact-moment results, in-app playback.
  Drives the funnel (demoed via the YouTube channel).
- **Pro** — search by spoken words (on-device Whisper), cloud-accelerated indexing for huge
  or older libraries, sync, advanced export, "find similar moments."
- **Enterprise (later)** — shared team indexes, self-host/on-prem, SSO, admin, support.

Distribution: **direct** (Lemon Squeezy / Paddle as merchant of record + Sparkle updates),
with Setapp and the Mac App Store as follow-on channels.

## Roadmap (short)

- **v1** — local semantic video search: folder indexing, exact-moment results, hover-scrub
  preview, in-app playback, export/drag clips, "find similar moments."
- **Later** — Whisper audio search, image-query mode, saved smart folders, cloud tier,
  licensing/billing, enterprise.

## Building

Requires macOS on Apple Silicon, Xcode, and XcodeGen (`brew install xcodegen`).

```sh
./tools/fetch_models.sh          # download MobileCLIP S0 Core ML models (gitignored, ~120MB)
cd app && xcodegen generate
xcodebuild -scheme Tafuta -configuration Debug build
open Tafuta.xcodeproj            # or open in Xcode and Run
```

Then click **Add Folder…** and pick a folder of videos. (Dev shortcut: set
`TAFUTA_INDEX_DIR=/path/to/videos` to auto-index a folder on launch.)

## License

Proprietary. © 2026 Ivan Kuria. All rights reserved. See [`LICENSE`](LICENSE).
