import SwiftUI

/// Shared drawing code for the animated and step-by-step views.
enum HanziRenderer {
    /// Wide enough to cover any stroke's outline when drawn along its median.
    static let revealWidth: CGFloat = 180
    /// Extra outline drawn around an emphasized stroke, in grid units.
    static let emphasisWidth: CGFloat = 36

    static func draw(_ character: HanziCharacter,
                     in context: GraphicsContext,
                     size: CGSize,
                     ghostColor: Color,
                     gridColor: Color?,
                     progress: (Int) -> Double,
                     color: (Int) -> Color,
                     emphasized: Int? = nil) {
        var ctx = context
        let side = min(size.width, size.height)
        guard side > 0 else { return }
        ctx.translateBy(x: (size.width - side) / 2, y: (size.height - side) / 2)
        ctx.scaleBy(x: side / HanziCharacter.gridSize, y: side / HanziCharacter.gridSize)

        if let gridColor {
            drawGrid(in: ctx, pointsPerUnit: side / HanziCharacter.gridSize, color: gridColor)
        }

        for index in 0..<character.strokeCount {
            let outline = character.outlines[index]
            ctx.fill(outline, with: .color(ghostColor))

            let p = progress(index)
            if p >= 1 {
                ctx.fill(outline, with: .color(color(index)))
                if index == emphasized {
                    // Thicken the stroke so it stands out without relying on colour.
                    ctx.stroke(outline, with: .color(color(index)),
                               style: StrokeStyle(lineWidth: emphasisWidth, lineJoin: .round))
                }
            } else if p > 0 {
                // Reveal the outline by drawing a thick line along the median, clipped to the outline.
                var clipped = ctx
                clipped.clip(to: outline)
                clipped.stroke(character.medianPath(index).trimmedPath(from: 0, to: p),
                               with: .color(color(index)),
                               style: StrokeStyle(lineWidth: revealWidth, lineCap: .round, lineJoin: .round))
            }
        }
    }

    /// 米字格 practice grid: border, centre cross and diagonals.
    private static func drawGrid(in ctx: GraphicsContext, pointsPerUnit: CGFloat, color: Color) {
        let s = HanziCharacter.gridSize
        let hairline = 1 / pointsPerUnit
        ctx.stroke(Path(CGRect(x: 0, y: 0, width: s, height: s)),
                   with: .color(color), lineWidth: hairline * 1.5)

        var guides = Path()
        guides.move(to: CGPoint(x: s / 2, y: 0)); guides.addLine(to: CGPoint(x: s / 2, y: s))
        guides.move(to: CGPoint(x: 0, y: s / 2)); guides.addLine(to: CGPoint(x: s, y: s / 2))
        guides.move(to: .zero); guides.addLine(to: CGPoint(x: s, y: s))
        guides.move(to: CGPoint(x: s, y: 0)); guides.addLine(to: CGPoint(x: 0, y: s))
        ctx.stroke(guides, with: .color(color),
                   style: StrokeStyle(lineWidth: hairline, dash: [6 * hairline, 6 * hairline]))
    }
}
