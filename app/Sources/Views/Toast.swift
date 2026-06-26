import SwiftUI

// A transient, non-modal status message. Dismissal is owned by the caller —
// this file deliberately adds no auto-dismiss timer.
struct Toast: Identifiable, Equatable {
    let id = UUID()
    var text: String
    var systemImage: String
    var style: Style = .info
    enum Style { case info, success, destructive }
}

// Compact capsule: SF Symbol + text on `.regularMaterial`, hairline border, floating shadow.
struct ToastView: View {
    let toast: Toast

    init(_ toast: Toast) {
        self.toast = toast
    }

    private var iconTint: Color {
        switch toast.style {
        case .success:     return .brand
        case .destructive: return .red
        case .info:        return .textSecondary
        }
    }

    var body: some View {
        HStack(spacing: Space.s) {
            Image(systemName: toast.systemImage)
                .font(Typo.caption)
                .foregroundStyle(iconTint)
            Text(toast.text)
                .font(Typo.callout)
                .foregroundStyle(Color.textPrimary)
                .lineLimit(1)
        }
        .padding(.horizontal, Space.l)
        .padding(.vertical, Space.s)
        .background(.regularMaterial, in: Capsule())
        .overlay(
            Capsule()
                .strokeBorder(Color.borderSubtle, lineWidth: 1)
        )
        .floatingShadow()
    }
}

extension View {
    // Pins a toast to the bottom-center of the receiver, animating it in/out by id.
    func toastOverlay(_ toast: Toast?) -> some View {
        overlay(alignment: .bottom) {
            if let toast {
                ToastView(toast)
                    .padding(.bottom, Space.xl)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(Motion.spring, value: toast?.id)
    }
}
