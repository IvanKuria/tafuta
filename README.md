# Tafuta

**Find the moment, not just the file.**

Tafuta (Kiswahili for *"find"*) is an open-source macOS app that lets you search **inside**
your own videos with plain language. Describe a moment — *"woman wearing a white blouse in a
green meadow"* — and Tafuta jumps straight to that second of the clip, even if the file is
named `IMG_0423.mov`.

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

## Roadmap (short)

- **v1** — local semantic video search: folder indexing, exact-moment results, hover-scrub
  preview, in-app playback, export/drag clips, "find similar moments."
- **Later** — search by spoken words (on-device Whisper), image-query mode, saved smart
  folders, and an optional paid cloud tier for power users / older Macs.

## Building

Requires macOS on Apple Silicon and Xcode. Build instructions will land as the project
takes shape.

## License

[GPLv3](LICENSE). The core app is free and open source, forever.
