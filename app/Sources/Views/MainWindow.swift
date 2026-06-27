import SwiftUI
import AVKit
import AVFoundation
import KeyboardShortcuts

// "Designed by Apple" Liquid-Glass main window.
// One translucent canvas (behind-window vibrancy shows the desktop). Content-first: the search
// field is the hero when idle and slides up to a pinned bar when results arrive. A seamless
// detail panel (no divider, no boxed fill) shares the same glass canvas.
struct MainWindow: View {
    @EnvironmentObject private var search: SearchCore
    @Environment(\.openWindow) private var openWindow
    @State private var dropTargeted = false

    var body: some View {
        ZStack {
            GlassCanvas()

            if search.isPreparingModel {
                ModelPrepCanvas()
            } else if !search.hasIndex && !search.isIndexing {
                FirstRunCanvas()
            } else {
                SearchStage()
            }
        }
        .frame(minWidth: 960, minHeight: 640)
        .background(WindowConfigurator())
        .tint(.brand)
        .toastOverlay(search.toast)
        .dropDestination(for: URL.self) { urls, _ in
            search.indexURLs(urls); return true
        } isTargeted: { dropTargeted = $0 }
        .overlay { if dropTargeted { DropTargetOverlay() } }
        .onExitCommand {
            if search.isPlayingInline { search.isPlayingInline = false }
            else { search.closeInspector() }
        }
        .onAppear {
            KeyboardShortcuts.onKeyUp(for: .summon) {
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: "launcher")
            }
        }
    }
}

// MARK: - Translucent canvas

// Real behind-window vibrancy + a whisper of depth tint for legibility on any wallpaper.
// No opaque fill — the desktop genuinely shows through (that's the "semi-translucent" feel).
private struct GlassCanvas: View {
    var body: some View {
        ZStack {
            VisualEffectView(material: .underWindowBackground, blending: .behindWindow)
                .ignoresSafeArea()
            LinearGradient(
                colors: [Color.black.opacity(0.10), Color.black.opacity(0.28)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }
}

// MARK: - Minimal top chrome (status + add). No duplicate Scan/Choose. No green checkmark.

private struct TopChrome: View {
    @EnvironmentObject private var search: SearchCore

    var body: some View {
        HStack(spacing: Space.s) {
            WindowDragArea().frame(height: 28)   // draggable region (room for traffic lights)
            StatusBadge()
            TuneMenu()
            AddMenu()
        }
        .padding(.horizontal, Space.l)
        .frame(height: 44)
    }
}

private struct StatusBadge: View {
    @EnvironmentObject private var search: SearchCore

    var body: some View {
        HStack(spacing: 6) {
            if search.isIndexing {
                ProgressView().controlSize(.mini).scaleEffect(0.8)
            } else {
                Circle().fill(Color.white.opacity(0.4)).frame(width: 6, height: 6)
            }
            Text(text)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.textTertiary)
                .monospacedDigit()
        }
        .fixedSize()
    }

    private var text: String {
        if search.isIndexing { return search.statusText.isEmpty ? "Indexing…" : search.statusText }
        return search.hasIndex ? "Ready · \(search.indexedCount) frames" : "Ready"
    }
}

private struct AddMenu: View {
    @EnvironmentObject private var search: SearchCore
    var body: some View {
        Menu {
            Button { search.addFolder() } label: { Label("Choose Folder…", systemImage: "folder") }
            Button { search.indexMacVideos(force: true) } label: { Label("Scan This Mac", systemImage: "macwindow") }
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.textSecondary)
                .frame(width: 26, height: 26)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.10), lineWidth: 1))
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .frame(width: 30)
        .help("Add videos")
    }
}

// Match strictness control — same minimal chip as AddMenu, a 3-way strictness picker.
private struct TuneMenu: View {
    @EnvironmentObject private var search: SearchCore
    var body: some View {
        Menu {
            Picker("Strictness", selection: $search.strictness) {
                Text("Loose").tag(0.10)
                Text("Balanced").tag(0.18)
                Text("Strict").tag(0.26)
            }
        } label: {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.textSecondary)
                .frame(width: 26, height: 26)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.10), lineWidth: 1))
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .frame(width: 30)
        .help("Match strictness")
    }
}

// MARK: - First run (no library yet) — single calm onboarding.

private struct FirstRunCanvas: View {
    @EnvironmentObject private var search: SearchCore
    var body: some View {
        VStack(spacing: 0) {
            TopChrome()
            Spacer()
            VStack(spacing: Space.m) {
                BrandGlyph()
                    .padding(.bottom, Space.s)
                Text("Search inside your videos")
                    .font(.system(size: 26, weight: .semibold))
                    .tracking(-0.3)
                Text("Describe a moment and Tafuta finds it. Everything stays on your Mac.")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.textSecondary)
                    .padding(.bottom, Space.m)
                Button { search.addFolder() } label: {
                    Label("Choose Folder…", systemImage: "folder")
                }
                .buttonStyle(LightCapsuleButtonStyle())
                Button { search.indexMacVideos(force: true) } label: {
                    Text("or scan this Mac automatically")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.textSecondary)
                }
                .buttonStyle(.plain)
                .padding(.top, Space.xs)
            }
            Spacer()
            Spacer()
        }
    }
}

// First-launch model download. The CLIP models are fetched on demand (not bundled), so this
// shows once while ~108MB downloads and compiles on the Neural Engine.
private struct ModelPrepCanvas: View {
    @EnvironmentObject private var search: SearchCore

    var body: some View {
        VStack(spacing: 0) {
            TopChrome()
            Spacer()
            VStack(spacing: Space.m) {
                BrandGlyph()
                    .padding(.bottom, Space.s)
                Text("Setting up Tafuta")
                    .font(.system(size: 26, weight: .semibold))
                    .tracking(-0.3)
                Text("Downloading the on-device search model. This happens once and stays private to your Mac.")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 380)
                    .padding(.bottom, Space.s)

                ProgressView(value: search.modelProgress)
                    .progressViewStyle(.linear)
                    .tint(.white)
                    .frame(width: 280)
                Text(progressLabel)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.textTertiary)
                    .monospacedDigit()
            }
            Spacer()
            Spacer()
        }
    }

    private var progressLabel: String {
        let pct = Int((search.modelProgress * 100).rounded())
        return "\(search.modelStatusText) \(pct)%"
    }
}

// Distinctive brand glyph: a film backdrop with a magnifier, set in a glass square.
private struct BrandGlyph: View {
    var body: some View {
        ZStack {
            Image(systemName: "film")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(.white.opacity(0.22))
            Image(systemName: "magnifyingglass")
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(.white)
        }
        .frame(width: 84, height: 84)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(.white.opacity(0.16), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.35), radius: 18, y: 10)
    }
}

// White pill primary button (monochrome, premium — matches the mockup CTA).
struct LightCapsuleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14.5, weight: .semibold))
            .foregroundStyle(Color(white: 0.07))
            .padding(.horizontal, 22)
            .frame(height: 42)
            .background(
                LinearGradient(colors: [.white, Color(white: 0.93)], startPoint: .top, endPoint: .bottom),
                in: RoundedRectangle(cornerRadius: 11, style: .continuous)
            )
            .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous)
                .strokeBorder(.white.opacity(0.5), lineWidth: 1))
            .opacity(configuration.isPressed ? 0.85 : 1)
            .shadow(color: .black.opacity(0.35), radius: 12, y: 6)
    }
}

// MARK: - Search stage (hero ↔ results) with ONE search field that slides up.

private struct SearchStage: View {
    @EnvironmentObject private var search: SearchCore

    private var hero: Bool { !search.hasResults }

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                TopChrome()

                SearchField(
                    placeholder: "Describe a moment…",
                    large: hero,
                    autoFocus: true,
                    autoIndexMacWhenNeeded: true
                )
                .frame(maxWidth: hero ? 560 : 520)
                // Mascot perches just above the search field in the idle hero state.
                .overlay(alignment: .top) {
                    if hero && !search.hasQuery {
                        PuppySprite(size: 96)
                            .offset(y: -94)
                            .transition(.scale(scale: 0.7, anchor: .bottom).combined(with: .opacity))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, Space.xl)
                .padding(.top, hero ? max(96, geo.size.height * 0.24) : 6)
                .padding(.bottom, hero ? 0 : 10)

                belowField
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .animation(Motion.standard, value: search.hasResults)
            .animation(Motion.standard, value: search.hasQuery)
        }
    }

    @ViewBuilder private var belowField: some View {
        if search.hasResults {
            ResultsSplit()
                .transition(.opacity)
        } else {
            VStack(spacing: 0) {
                if search.isIndexing {
                    IndexingHint().padding(.top, Space.xl)
                } else if search.hasQuery {
                    LowConfidence().padding(.top, Space.xl)
                } else {
                    TryChips().padding(.top, Space.xl)
                }
                Spacer(minLength: 0)
            }
            .transition(.opacity)
        }
    }
}

// Quiet suggestion chips under the hero search.
private struct TryChips: View {
    @EnvironmentObject private var search: SearchCore
    var body: some View {
        VStack(spacing: Space.m) {
            Text("TRY")
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(Color.textTertiary)
            HStack(spacing: Space.s) {
                ForEach(suggestions, id: \.self) { q in
                    Button { search.runExample(q) } label: {
                        Text(q)
                            .font(.system(size: 13))
                            .foregroundStyle(Color.textSecondary)
                            .padding(.horizontal, 14)
                            .frame(height: 32)
                            .background(.ultraThinMaterial, in: Capsule())
                            .overlay(Capsule().strokeBorder(.white.opacity(0.08), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    private var suggestions: [String] {
        let recents = Array(search.recentSearches.prefix(3))
        return recents.isEmpty ? Array(search.examples.prefix(3)) : recents
    }
}

private struct IndexingHint: View {
    @EnvironmentObject private var search: SearchCore
    var body: some View {
        Text(search.indexedCount > 0
             ? "Indexing… you can search the \(search.indexedCount) frames ready so far."
             : "Indexing your videos… search will light up as frames come in.")
            .font(.system(size: 13))
            .foregroundStyle(Color.textTertiary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: 420)
    }
}

// Shown when there's a query but nothing cleared the strictness bar. Explains *why* and
// offers a way out (relax strictness, clear filters, or reveal the closest near-miss).
private struct LowConfidence: View {
    @EnvironmentObject private var search: SearchCore

    // Mirror SearchResult.normalizedScore (cosine / 0.4, clamped) for the "how close" percent.
    private var closestPercent: Int {
        Int((min(max(search.bestCosine / 0.4, 0), 1) * 100).rounded())
    }

    var body: some View {
        VStack(spacing: Space.xs) {
            Text(search.bestCosine > 0 ? "No strong match" : "No matches")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.textSecondary)
            Text(hint)
                .font(.system(size: 13))
                .foregroundStyle(Color.textTertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
            if search.bestCosine > 0 {
                Button { search.revealClosest() } label: {
                    Text("Show closest anyway")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.brand)
                }
                .buttonStyle(.plain)
                .padding(.top, Space.xxs)
            }
        }
    }

    private var hint: String {
        if search.filters.isActive {
            return "Filters may be hiding results. Try clearing them or lowering strictness."
        } else if search.bestCosine > 0 {
            return "Closest was \(closestPercent)% — lower strictness or rephrase."
        } else {
            return "Try a broader description."
        }
    }
}

// MARK: - Results + seamless detail

private struct ResultsSplit: View {
    @EnvironmentObject private var search: SearchCore
    var body: some View {
        HStack(spacing: 0) {
            ResultsGrid()
                .frame(maxWidth: .infinity)
            if let moment = search.inspectorMoment {
                DetailPanel(moment: moment)
                    .frame(width: 392)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(Motion.standard, value: search.inspectorMoment?.id)
    }
}

private struct ResultsGrid: View {
    @EnvironmentObject private var search: SearchCore
    @State private var showFilters = false
    private let columns = [GridItem(.adaptive(minimum: 220, maximum: 300), spacing: Space.l)]

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: Space.l) {
                    header
                    if search.filters.isActive { activeChips }
                    if search.grouping == .grouped { grouped } else { flat }
                }
                .padding(.horizontal, Space.xl)
                .padding(.top, Space.s)
                .padding(.bottom, Space.xxl)
            }
            .onMoveCommand { direction in
                switch direction {
                case .left:  search.moveSelection(-1)
                case .right: search.moveSelection(1)
                case .up:    search.moveSelection(-3)
                case .down:  search.moveSelection(3)
                @unknown default: break
                }
                if let id = search.selectedID {
                    withAnimation(Motion.quick) { proxy.scrollTo(id, anchor: .center) }
                    if let r = search.navigationOrder.first(where: { $0.id == id }) { search.inspect(r) }
                }
            }
            .onKeyPress(.return) { search.playSelected(); return .handled }
        }
    }

    private var header: some View {
        HStack(spacing: Space.s) {
            if let label = search.similarLabel {
                Pill(text: label, systemImage: "square.on.square")
            }
            Text("\(search.results.count) result\(search.results.count == 1 ? "" : "s")")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.textSecondary)
            Spacer()
            Button { showFilters.toggle() } label: {
                Image(systemName: search.filters.isActive
                      ? "line.3.horizontal.decrease.circle.fill"
                      : "line.3.horizontal.decrease.circle")
                    .font(.system(size: 15))
                    .foregroundStyle(search.filters.isActive ? Color.brand : Color.textSecondary)
            }
            .buttonStyle(.plain)
            .help("Filter results")
            .popover(isPresented: $showFilters, arrowEdge: .bottom) { FilterPopover() }
            Picker("Layout", selection: $search.grouping) {
                Image(systemName: "rectangle.grid.1x2").tag(Grouping.grouped)
                Image(systemName: "square.grid.2x2").tag(Grouping.flat)
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .frame(width: 96)
        }
        .padding(.top, Space.xs)
    }

    // Removable summary chips for every active facet, ending with a "Clear all".
    private var activeChips: some View {
        let f = search.filters
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Space.s) {
                if f.dateRange != .any {
                    RemovableChip(label: f.dateRange.label) { search.filters.dateRange = .any }
                }
                ForEach(Array(f.durations), id: \.self) { bucket in
                    RemovableChip(label: bucket.label) { search.filters.durations.remove(bucket) }
                }
                if !f.folders.isEmpty {
                    let label = f.folders.count == 1
                        ? (URL(fileURLWithPath: f.folders.first!).lastPathComponent)
                        : "\(f.folders.count) folders"
                    RemovableChip(label: label) { search.filters.folders.removeAll() }
                }
                ForEach(Array(f.fileTypes), id: \.self) { ext in
                    RemovableChip(label: ext.uppercased()) { search.filters.fileTypes.remove(ext) }
                }
                RemovableChip(label: "Clear all", emphasized: true) { search.filters = SearchFilters() }
            }
            .padding(.vertical, 2)
        }
    }

    private var flat: some View {
        LazyVGrid(columns: columns, spacing: Space.l) {
            ForEach(Array(search.results.enumerated()), id: \.element.id) { i, r in
                MomentTile(result: r, selected: r.id == search.selectedID)
                    .id(r.id)
                    .modifier(StaggeredAppear(index: i))
            }
        }
    }

    private var grouped: some View {
        LazyVStack(alignment: .leading, spacing: Space.xl) {
            ForEach(search.groupedResults) { group in
                VStack(alignment: .leading, spacing: Space.s) {
                    HStack(spacing: Space.s) {
                        Text(group.name)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.textPrimary)
                            .lineLimit(1).truncationMode(.middle)
                        Text("\(group.items.count)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.textTertiary)
                            .monospacedDigit()
                        Spacer()
                    }
                    LazyVGrid(columns: columns, spacing: Space.l) {
                        ForEach(Array(group.items.enumerated()), id: \.element.id) { i, r in
                            MomentTile(result: r, selected: r.id == search.selectedID)
                                .id(r.id)
                                .modifier(StaggeredAppear(index: i))
                        }
                    }
                }
            }
        }
    }
}

// A Pill-styled chip with a trailing xmark that clears one facet (or all).
private struct RemovableChip: View {
    let label: String
    var emphasized: Bool = false
    let onRemove: () -> Void
    var body: some View {
        Button(action: onRemove) {
            HStack(spacing: Space.xs) {
                Text(label).font(.system(size: 11, weight: .semibold))
                Image(systemName: "xmark").font(.system(size: 8, weight: .bold))
            }
            .foregroundStyle(emphasized ? Color.brand : Color.textSecondary)
            .padding(.horizontal, Space.s)
            .padding(.vertical, 3)
            .background(emphasized ? Color.brand.opacity(0.14) : Color.bgInset, in: Capsule())
            .overlay(Capsule().strokeBorder(emphasized ? Color.brand.opacity(0.22) : Color.borderSubtle, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

// A multi-select capsule toggle matching the Pill look (selected → accent tint).
private struct TogglePill: View {
    let label: String
    let isOn: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(isOn ? Color.brand : Color.textSecondary)
                .padding(.horizontal, Space.s)
                .padding(.vertical, 4)
                .background(isOn ? Color.brand.opacity(0.14) : Color.bgInset, in: Capsule())
                .overlay(Capsule().strokeBorder(isOn ? Color.brand.opacity(0.22) : Color.borderSubtle, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

// Simple wrapping layout so filter pills flow onto multiple rows instead of overflowing.
private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxW = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x > 0 && x + s.width > maxW { x = 0; y += rowH + spacing; rowH = 0 }
            x += s.width + spacing
            rowH = max(rowH, s.height)
        }
        return CGSize(width: maxW.isFinite ? maxW : x, height: y + rowH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowH: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x > bounds.minX && x + s.width > bounds.maxX { x = bounds.minX; y += rowH + spacing; rowH = 0 }
            v.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(s))
            x += s.width + spacing
            rowH = max(rowH, s.height)
        }
    }
}

// Filter popover: Date / Duration / Folder / File type facets + Clear all.
private struct FilterPopover: View {
    @EnvironmentObject private var search: SearchCore

    var body: some View {
        VStack(alignment: .leading, spacing: Space.l) {
            section("DATE") {
                Picker("Date", selection: $search.filters.dateRange) {
                    ForEach(SearchFilters.DateRange.allCases, id: \.self) { r in
                        Text(r.label).tag(r)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .leading)
                if search.filters.dateRange == .custom {
                    VStack(spacing: Space.s) {
                        DatePicker("Start", selection: customStart, displayedComponents: .date)
                        DatePicker("End", selection: customEnd, displayedComponents: .date)
                    }
                    .datePickerStyle(.compact)
                    .font(.system(size: 12))
                }
            }

            section("DURATION") {
                FlowLayout(spacing: Space.s) {
                    ForEach(SearchFilters.DurationBucket.allCases, id: \.self) { bucket in
                        TogglePill(label: bucket.label,
                                   isOn: search.filters.durations.contains(bucket)) {
                            toggle(bucket, in: \.durations)
                        }
                    }
                }
            }

            if !search.availableFolders.isEmpty {
                section("FOLDER") {
                    ScrollView {
                        VStack(alignment: .leading, spacing: Space.xs) {
                            ForEach(search.availableFolders, id: \.self) { folder in
                                let path = folder.standardizedFileURL.path
                                Button { toggleString(path, in: \.folders) } label: {
                                    HStack(spacing: Space.s) {
                                        Image(systemName: search.filters.folders.contains(path)
                                              ? "checkmark.square.fill" : "square")
                                            .font(.system(size: 12))
                                            .foregroundStyle(search.filters.folders.contains(path)
                                                             ? Color.brand : Color.textTertiary)
                                        Text(folder.lastPathComponent)
                                            .font(.system(size: 12))
                                            .foregroundStyle(Color.textSecondary)
                                            .lineLimit(1).truncationMode(.middle)
                                        Spacer(minLength: 0)
                                    }
                                    .help(folder.path)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .frame(maxHeight: 140)
                }
            }

            if !search.availableTypes.isEmpty {
                section("FILE TYPE") {
                    FlowLayout(spacing: Space.s) {
                        ForEach(search.availableTypes, id: \.self) { ext in
                            TogglePill(label: ext.uppercased(),
                                       isOn: search.filters.fileTypes.contains(ext)) {
                                toggleString(ext, in: \.fileTypes)
                            }
                        }
                    }
                }
            }

            Divider().overlay(Color.white.opacity(0.06))
            HStack {
                Spacer()
                Button("Clear all") { search.filters = SearchFilters() }
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(search.filters.isActive ? Color.brand : Color.textTertiary)
                    .disabled(!search.filters.isActive)
            }
        }
        .padding(Space.l)
        .frame(width: 320)
        // Use the popover's native chrome — adding our own material over it made it murky/mangled.
    }

    @ViewBuilder private func section<Content: View>(_ title: String,
                                                     @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Space.s) {
            Text(title)
                .font(.system(size: 10.5, weight: .bold))
                .tracking(0.9)
                .foregroundStyle(Color.textTertiary)
            content()
        }
    }

    // Non-optional bridges for the custom DatePickers (default to now when unset).
    private var customStart: Binding<Date> {
        Binding(get: { search.filters.customStart ?? .now },
                set: { search.filters.customStart = $0 })
    }
    private var customEnd: Binding<Date> {
        Binding(get: { search.filters.customEnd ?? .now },
                set: { search.filters.customEnd = $0 })
    }

    private func toggle(_ bucket: SearchFilters.DurationBucket,
                        in keyPath: WritableKeyPath<SearchFilters, Set<SearchFilters.DurationBucket>>) {
        if search.filters[keyPath: keyPath].contains(bucket) {
            search.filters[keyPath: keyPath].remove(bucket)
        } else {
            search.filters[keyPath: keyPath].insert(bucket)
        }
    }
    private func toggleString(_ value: String,
                              in keyPath: WritableKeyPath<SearchFilters, Set<String>>) {
        if search.filters[keyPath: keyPath].contains(value) {
            search.filters[keyPath: keyPath].remove(value)
        } else {
            search.filters[keyPath: keyPath].insert(value)
        }
    }
}

// Result card: thumbnail + timecode pill; filename + match% below. Hover lifts, selection glows.
private struct MomentTile: View {
    @EnvironmentObject private var search: SearchCore
    let result: SearchResult
    let selected: Bool
    @State private var hovering = false

    var body: some View {
        Button { search.inspect(result) } label: {
            VStack(alignment: .leading, spacing: Space.s) {
                ZStack(alignment: .bottomLeading) {
                    Image(nsImage: result.thumbnail)
                        .resizable()
                        .aspectRatio(16.0 / 10.0, contentMode: .fill)
                        .frame(maxWidth: .infinity)
                        .clipped()
                    Text(result.timecode)
                        .font(.system(size: 11, weight: .semibold).monospacedDigit())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(.black.opacity(0.5), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .padding(8)
                }
                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .strokeBorder(selected ? Color.brand.opacity(0.9) : .white.opacity(hovering ? 0.14 : 0.06),
                                      lineWidth: selected ? 2 : 1)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .stroke(Color.brand.opacity(selected ? 0.28 : 0), lineWidth: 4)
                        .blur(radius: 2)
                )

                HStack(spacing: Space.s) {
                    Text(result.videoName)
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(selected ? Color.textPrimary : Color.textSecondary)
                        .lineLimit(1).truncationMode(.middle)
                    Spacer(minLength: Space.xs)
                    Text("\(Int(result.normalizedScore * 100))%")
                        .font(.system(size: 11, weight: .semibold).monospacedDigit())
                        .foregroundStyle(Color.textTertiary)
                }
                .padding(.horizontal, 2)
            }
            .offset(y: hovering ? -4 : 0)
            .shadow(color: .black.opacity(hovering ? 0.4 : 0), radius: 16, y: 10)
            .animation(Motion.quick, value: hovering)
            .animation(Motion.quick, value: selected)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .contextMenu {
            ForEach(MomentActions.all(result, search)) { action in
                Button(role: action.isDestructive ? .destructive : nil, action: action.perform) {
                    Label(action.title, systemImage: action.systemImage)
                }
            }
        }
        .accessibilityLabel("\(result.videoName), \(result.timecode), \(Int(result.normalizedScore * 100)) percent match")
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}

// MARK: - Seamless detail panel (no divider, no boxed fill — shares the glass canvas)

private struct DetailPanel: View {
    let moment: SearchResult
    @EnvironmentObject private var search: SearchCore
    @State private var player = AVPlayer()
    @State private var related: [SearchResult] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.l) {
                hero
                VStack(alignment: .leading, spacing: 3) {
                    Text(moment.videoName)
                        .font(.system(size: 17, weight: .semibold))
                        .tracking(-0.2)
                        .foregroundStyle(Color.textPrimary)
                        .lineLimit(2)
                    Text(moment.prettyPath)
                        .font(.system(size: 12.5))
                        .foregroundStyle(Color.textTertiary)
                        .lineLimit(1).truncationMode(.middle)
                }
                metadata
                actions
                if !related.isEmpty { relatedRail }
            }
            .padding(.horizontal, 28)
            .padding(.top, Space.m)
            .padding(.bottom, Space.xl)
        }
        // Whisper of edge-light toward the trailing edge → depth without a divider.
        .background(
            LinearGradient(colors: [.white.opacity(0), .white.opacity(0.022), .white.opacity(0.04)],
                           startPoint: .leading, endPoint: .trailing)
                .allowsHitTesting(false)
        )
        .task(id: moment.id) {
            let (same, _) = await search.relatedMoments(to: moment)
            related = same
        }
    }

    private var hero: some View {
        ZStack {
            if search.isPlayingInline {
                PlayerSurface(player: player)
            } else {
                Image(nsImage: moment.thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .clipped()
                    .overlay {
                        Button { search.playInline() } label: {
                            Image(systemName: "play.fill")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 54, height: 54)
                                .background(.black.opacity(0.4), in: Circle())
                                .overlay(Circle().strokeBorder(.white.opacity(0.4), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
            }
        }
        .aspectRatio(16.0 / 10.0, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(.white.opacity(0.12), lineWidth: 1))
        .shadow(color: .black.opacity(0.4), radius: 18, y: 10)
        .onAppear { loadMoment(); if search.isPlayingInline { player.play() } }
        .onChange(of: moment.id) { _, _ in loadMoment() }
        .onChange(of: search.isPlayingInline) { _, playing in playing ? player.play() : player.pause() }
        .onDisappear { player.pause() }
    }

    private var metadata: some View {
        VStack(spacing: 0) {
            row("Timestamp", moment.timecode)
            Divider().overlay(Color.white.opacity(0.06))
            row("Duration", moment.durationLabel.isEmpty ? "—" : moment.durationLabel)
            Divider().overlay(Color.white.opacity(0.06))
            row("Match", "\(Int(moment.normalizedScore * 100))%")
        }
    }

    private func row(_ k: String, _ v: String) -> some View {
        HStack {
            Text(k).font(.system(size: 13)).foregroundStyle(Color.textTertiary)
            Spacer()
            Text(v).font(.system(size: 13, weight: .medium).monospacedDigit()).foregroundStyle(Color.textSecondary)
        }
        .padding(.vertical, 8)
    }

    private var actions: some View {
        HStack(spacing: Space.s) {
            Button { search.select(moment); search.playInline() } label: {
                Label("Play", systemImage: "play.fill")
                    .font(.system(size: 13.5, weight: .semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(LightCapsuleButtonStyle())
            .frame(maxWidth: .infinity)

            iconButton("square.on.square", "Find similar") { search.findSimilar(to: moment) }
            iconButton("square.and.arrow.up", "Export clip") { search.exportClip(moment) }
            iconButton("folder", "Reveal in Finder") { search.reveal(moment) }
        }
    }

    private func iconButton(_ symbol: String, _ help: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.textSecondary)
                .frame(width: 38, height: 38)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(.white.opacity(0.10), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .help(help)
    }

    private var relatedRail: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            Text("MORE FROM THIS VIDEO")
                .font(.system(size: 10.5, weight: .bold))
                .tracking(0.9)
                .foregroundStyle(Color.textTertiary)
            HStack(spacing: Space.s) {
                ForEach(related.prefix(3)) { item in
                    Button { search.inspect(item) } label: {
                        Image(nsImage: item.thumbnail)
                            .resizable()
                            .aspectRatio(16.0 / 10.0, contentMode: .fill)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(.white.opacity(0.08), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func loadMoment() {
        player.replaceCurrentItem(with: AVPlayerItem(url: moment.videoURL))
        player.seek(to: CMTime(seconds: moment.timestamp, preferredTimescale: 600),
                    toleranceBefore: .zero, toleranceAfter: .zero)
        if search.isPlayingInline { player.play() }
    }
}

// MARK: - Drop overlay

private struct DropTargetOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.12).ignoresSafeArea()
            VStack(spacing: Space.m) {
                Image(systemName: "tray.and.arrow.down")
                    .font(.system(size: 36, weight: .light))
                    .foregroundStyle(.white)
                Text("Drop videos or folders")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .padding(40)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(.white.opacity(0.15), lineWidth: 1))
        }
        .transition(.opacity)
        .allowsHitTesting(false)
    }
}
