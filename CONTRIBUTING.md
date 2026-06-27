# Contributing to Tafuta

Thanks for your interest in contributing. Tafuta is a native macOS app for on-device semantic
video search. This guide explains how to get the project building, how the code is organized,
and what we expect in a pull request.

By contributing you agree that your contributions are licensed under the project's
[GPL-3.0 license](LICENSE).

## Getting Started

### Requirements

- macOS on Apple Silicon (the Neural Engine is used for inference).
- Xcode 16 or later.
- [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`.

The deployment target is macOS 14. Newer system features, such as Liquid Glass, are gated
behind `if #available(macOS 26, *)` so the app still builds and runs on macOS 14 and 15.

### Build and Run

```sh
./tools/fetch_models.sh          # download MobileCLIP S0 Core ML models (gitignored, ~120MB)
cd app && xcodegen generate      # generate Tafuta.xcodeproj from project.yml
xcodebuild -scheme Tafuta -configuration Debug build
open Tafuta.xcodeproj            # or open in Xcode and Run
```

The Xcode project is generated and is not committed. Always run `xcodegen generate` after
adding, moving, or removing source files, since `project.yml` globs the `Sources` and
`Resources` directories.

For a fast inner loop you can set `TAFUTA_INDEX_DIR=/path/to/videos` to auto index a folder on
launch instead of picking one each time.

## Project Structure

```
app/
  project.yml              XcodeGen project definition (settings, target, signing)
  Sources/
    TafutaApp.swift        App entry point, scenes, global hotkey wiring
    Search/                Shared engine state and query model
      SearchCore.swift     ObservableObject that drives both the window and the launcher
      SearchResult.swift   Result and moment value types
      SearchFilters.swift  Date, duration, folder, and file type filters
    Engine/                On-device pipeline (no UI)
      VideoIndexer.swift   Frame sampling and indexing orchestration
      Embedder.swift       MobileCLIP image and text encoders via Core ML
      CLIPTokenizer.swift  Text tokenization for the text encoder
      IndexStore.swift     Local vector and metadata persistence
      FolderBookmarks.swift Security-scoped bookmarks for picked folders
      ClipExporter.swift   Frame and clip export
    Views/                 SwiftUI views (main window, launcher, inspector, mascot)
    Theme/                 Design tokens, materials, fonts, shared components
  Resources/
    Assets.xcassets        Colors and the app icon
    Models/                MobileCLIP Core ML packages (gitignored, fetched on demand)
    Fonts/                 Bundled fonts
docs/                      Architecture, plan, and README assets
tools/                     fetch_models.sh and color generation
```

## Architecture

### High-level overview

A single shared `SearchCore` engine drives both the main window and the global-hotkey
launcher, so search state stays consistent across surfaces. The user interface layer in
`Views` and `Theme` is kept separate from the inference and storage layer in `Engine`.

### Indexing pipeline

When a folder is added, `VideoIndexer` streams frames from each video with `AVAssetReader`
(roughly one frame per second, with scene-change deduplication), `Embedder` encodes each frame
into a 512 dimension vector using MobileCLIP on the Neural Engine, and `IndexStore` persists
the vectors and metadata on the internal disk. Keeping the index local means search keeps
working even when an external drive is unplugged.

### Search

A query is encoded into the same vector space by the MobileCLIP text encoder, then ranked
against the stored frame vectors with a nearest neighbor search. Results are exact moments
(video plus timestamp), not just file names.

## Coding Guidelines

- **Modern SwiftUI.** Prefer current APIs and value types. Keep views small and focused.
- **Swift Concurrency.** Use async and await with structured concurrency. Do embedding and
  other heavy work off the main actor and update published state back on the main actor. Avoid
  blocking the UI.
- **Keep UI and engine separate.** Changes to the look and feel should stay in `Views` and
  `Theme`. Changes to indexing, embedding, or storage should stay in `Engine`. Pull requests
  that mix the two should explain why.
- **Theme tokens, not ad hoc values.** Use the spacing, radius, color, and material tokens in
  `Theme` rather than hardcoding magic numbers.
- **Global shortcuts** go through the `KeyboardShortcuts` package so they remain user
  rebindable.
- **Error handling.** Handle optionals explicitly rather than force unwrapping in code paths
  that can fail at runtime, especially around file access and model loading.
- **Privacy.** Tafuta is fully on device. Do not add network calls, analytics, or telemetry to
  the core app.

## Pull Request Guidelines

- Keep changes small and focused on a single concern.
- The project must build cleanly: `cd app && xcodegen generate && xcodebuild -scheme Tafuta build`.
- Do not commit the generated `Tafuta.xcodeproj`; it is gitignored.
- Match the existing code style and naming in the files you touch.
- Update documentation when you change behavior that the README or docs describe.
- Open an issue to discuss substantial or architectural changes before sending a large pull
  request.

## AI-Assisted Contributions

AI-assisted contributions are welcome. If you used an AI tool to write a meaningful part of a
change, please note that in the pull request description and review the output carefully before
submitting. You are responsible for understanding and standing behind the code you contribute,
regardless of how it was produced. The same quality and review bar applies to all pull
requests.

## Testing

There is no automated test suite yet, so verification is currently manual. Before opening a
pull request, build the app and exercise the paths you changed:

- Add a folder of videos and confirm indexing completes.
- Run several natural language queries and confirm results land on the correct moments.
- Open the inspector, play a result, and confirm playback seeks to the right timestamp.
- Summon the launcher with the global hotkey and confirm search works with the main window
  closed.

Contributions that add a test target and unit tests for the engine are very welcome.
