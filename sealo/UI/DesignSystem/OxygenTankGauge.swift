import SwiftUI

/// M0 placeholder battery gauge.
///
/// Renders the native iOS battery silhouette (horizontal rounded-rect
/// body + right-side nub) with a solid teal fill. The real gradient
/// (`#2EE6C8 → #1BA89A → #14736B`), low-O₂ opacity pulse, dark-mode
/// tuning, and the label/timer overlays land in M1 per
/// `docs/01-plan.md` Appendix A.
///
/// The view is fully proportional to its frame. The consumer is
/// expected to supply an explicit `.frame(width:height:)` — the gauge
/// is designed to scale from ~20×10 pt (Dynamic Island minimal) up to
/// ~400×180 pt (Lock Screen / dashboard) without layout changes.
public struct OxygenTankGauge: View {
    /// Fill level in `0...1`. Values outside that range are clamped.
    public let fill: Double

    public init(fill: Double) {
        self.fill = fill
    }

    public var body: some View {
        GeometryReader { geo in
            let h = geo.size.height
            let w = geo.size.width

            let gap: CGFloat = max(1, h * 0.04)
            let nubWidth: CGFloat = max(2, h * 0.08)
            let nubHeight: CGFloat = h * 0.38
            let bodyWidth: CGFloat = max(0, w - nubWidth - gap)

            let stroke: CGFloat = max(1, h * 0.05)
            let innerInset: CGFloat = stroke + 1
            let cornerRadius: CGFloat = h * 0.28
            let innerCornerRadius: CGFloat = max(1, cornerRadius - innerInset)

            let innerMaxWidth: CGFloat = max(0, bodyWidth - innerInset * 2)
            let fillWidth: CGFloat = innerMaxWidth * clampedFill

            HStack(spacing: gap) {
                ZStack(alignment: .leading) {
                    // Battery body outline.
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .strokeBorder(
                            Color.primary.opacity(0.9),
                            lineWidth: stroke
                        )

                    // Fill — left-aligned, inset inside the stroke.
                    // M1 will swap this for a LinearGradient and add
                    // the low-O₂ opacity pulse animation.
                    RoundedRectangle(cornerRadius: innerCornerRadius)
                        .fill(placeholderTeal)
                        .frame(width: fillWidth)
                        .padding(innerInset)
                }
                .frame(width: bodyWidth)

                // Nub.
                RoundedRectangle(cornerRadius: nubWidth / 2)
                    .fill(Color.primary.opacity(0.9))
                    .frame(width: nubWidth, height: nubHeight)
            }
        }
    }

    private var clampedFill: Double {
        min(1, max(0, fill))
    }

    /// M0 placeholder. Mid-teal from the Appendix A color token set.
    /// Replaced by a `LinearGradient` in M1.
    private var placeholderTeal: Color {
        Color(red: 27.0 / 255.0, green: 168.0 / 255.0, blue: 154.0 / 255.0)
    }
}

#Preview("default — 67%") {
    OxygenTankGauge(fill: 0.67)
        .frame(width: 240, height: 110)
        .padding()
}

#Preview("edge — empty") {
    OxygenTankGauge(fill: 0.0)
        .frame(width: 240, height: 110)
        .padding()
}

#Preview("edge — full") {
    OxygenTankGauge(fill: 1.0)
        .frame(width: 240, height: 110)
        .padding()
}
