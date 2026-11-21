import SwiftUI

/// Static stroke-order chart: one panel per stroke. The new stroke in each panel is drawn
/// in the highlight colour *and* thicker, with a dot where the brush starts, so it doesn't
/// rely on colour alone. Panels grow with Dynamic Type.
public struct StrokeStepsView: View {
    public let character: HanziCharacter
    public var panelSize: CGFloat
    public var strokeColor: Color
    public var highlightColor: Color
    public var gridColor: Color?
    public var showsNumbers: Bool

    @ScaledMetric(relativeTo: .body) private var typeScale: CGFloat = 1

    public init(character: HanziCharacter,
                panelSize: CGFloat = 64,
                strokeColor: Color = .primary,
                highlightColor: Color = .red,
                gridColor: Color? = .secondary.opacity(0.3),
                showsNumbers: Bool = true) {
        self.character = character
        self.panelSize = panelSize
        self.strokeColor = strokeColor
        self.highlightColor = highlightColor
        self.gridColor = gridColor
        self.showsNumbers = showsNumbers
    }

    public var body: some View {
        let size = panelSize * typeScale
        LazyVGrid(columns: [GridItem(.adaptive(minimum: size, maximum: size * 1.5), spacing: 8)],
                  spacing: 8) {
            ForEach(0..<character.strokeCount, id: \.self) { step in
                panel(step)
            }
        }
    }

    private func panel(_ step: Int) -> some View {
        Canvas { ctx, size in
            HanziRenderer.draw(character, in: ctx, size: size,
                               ghostColor: .secondary.opacity(0.12),
                               gridColor: gridColor,
                               progress: { $0 <= step ? 1 : 0 },
                               color: { $0 == step ? highlightColor : strokeColor },
                               emphasized: step)

            // Start-of-stroke marker.
            if let start = character.medians[step].first {
                let scale = min(size.width, size.height) / HanziCharacter.gridSize
                let offset = CGPoint(x: (size.width - min(size.width, size.height)) / 2,
                                     y: (size.height - min(size.width, size.height)) / 2)
                let center = CGPoint(x: offset.x + start.x * scale, y: offset.y + start.y * scale)
                let r = max(2.5, 30 * scale)
                ctx.fill(Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: 2 * r, height: 2 * r)),
                         with: .color(highlightColor.opacity(0.9)))
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .overlay(alignment: .topLeading) {
            if showsNumbers {
                Text("\(step + 1)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .padding(3)
            }
        }
        .accessibilityElement()
        .accessibilityLabel(Text("Stroke \(step + 1) of \(character.strokeCount)", bundle: .module))
    }
}
