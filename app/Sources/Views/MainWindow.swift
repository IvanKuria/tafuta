import SwiftUI
import KeyboardShortcuts

// Sidebar-less, content-first window: custom TopBar + full-width results,
// with a native Inspector slide-out preview, a toast overlay, and first-run onboarding.
struct MainWindow: View {
    @EnvironmentObject var search: SearchCore
    @Environment(\.openWindow) private var openWindow

    private var selectedResult: SearchResult? {
        search.results.first { $0.id == search.selectedID }
    }

    // Inspector presentation derives from the selected moment.
    private var inspectorShown: Binding<Bool> {
        Binding(get: { search.inspectorMoment != nil },
                set: { if !$0 { search.closeInspector() } })
    }

    var body: some View {
        VStack(spacing: 0) {
            TopBar()
            ResultsView()
                .inspector(isPresented: inspectorShown) {
                    if let moment = search.inspectorMoment {
                        MomentInspector(moment: moment)
                            .inspectorColumnWidth(min: 320, ideal: 380, max: 560)
                    }
                }
            if let r = selectedResult {
                ActionBar(appGlyph: "film",
                          contextTitle: r.videoName,
                          primary: MomentActions.primary(r, search),
                          actions: MomentActions.all(r, search))
            }
        }
        .frame(minWidth: 720, minHeight: 480)
        .background(Color.bgCanvas)
        .tint(Color.brand)
        .toastOverlay(search.toast)
        .overlay { OnboardingModal() }
        .onExitCommand { if search.inspectorMoment != nil { search.closeInspector() } }
        .onAppear {
            KeyboardShortcuts.onKeyUp(for: .summon) {
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: "launcher")
            }
        }
    }
}
