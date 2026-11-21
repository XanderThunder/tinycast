import SwiftUI

struct MessageHUDView: View {
    private static let glowOpacity = 0.14
    private static let glowRadius: CGFloat = 150
    private static let rimOpacity = 0.25

    let message: String
    let tone: DialogTone
    @Environment(\.metrics) private var metrics

    var body: some View {
        HStack(spacing: metrics.spacing.md) {
            Image(systemName: tone.hudSymbol)
                .foregroundStyle(tone.tint)
                .font(metrics.typography.menuIcon)
                .frame(width: metrics.size.menuIcon, height: metrics.size.menuIcon)
            Text(message)
                .font(metrics.typography.bar)
                .foregroundStyle(Color.primary)
                .lineLimit(1)
        }
        .padding(.horizontal, metrics.spacing.xl)
        .padding(.vertical, metrics.spacing.lg)
        .frame(maxWidth: metrics.size.hudMaxWidth, alignment: .leading)
        .fixedSize()
        .background { glow }
        .background(Theme.Colors.panelScrim)
        .background(GlassEffectView())
        .clipShape(Capsule())
        .overlay { rim }
    }

    private var glow: some View {
        GeometryReader { proxy in
            Capsule().fill(
                RadialGradient(
                    colors: [tone.tint.opacity(Self.glowOpacity), tone.tint.opacity(0.03), .clear],
                    center: UnitPoint(
                        x: (metrics.spacing.xl + metrics.size.menuIcon / 2) / proxy.size.width,
                        y: 0.5),
                    startRadius: 0, endRadius: Self.glowRadius))
        }
    }

    private var rim: some View {
        Capsule().strokeBorder(
            LinearGradient(
                colors: [tone.tint.opacity(Self.rimOpacity), tone.tint.opacity(0.06), .clear],
                startPoint: .leading, endPoint: .trailing),
            lineWidth: Theme.Size.hairline)
    }
}

/// File-scoped on purpose, so nothing can reach for it when building a dialog.
extension DialogTone {
    fileprivate var hudSymbol: String {
        switch self {
        case .neutral: return "info"
        case .success: return "checkmark"
        case .danger: return "exclamationmark"
        }
    }
}
