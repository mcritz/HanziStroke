import SwiftUI

/// Animates a character stroke by stroke. Tap to replay.
public struct StrokeOrderView: View {
    public let character: HanziCharacter
    public var speed: Double
    public var delayBetweenStrokes: TimeInterval
    public var loops: Bool
    public var strokeColor: Color
    public var radicalColor: Color?
    public var ghostColor: Color
    public var gridColor: Color?

    @State private var startDate = Date()
    @State private var isFinished = false

    public init(character: HanziCharacter,
                speed: Double = 1,
                delayBetweenStrokes: TimeInterval = 0.3,
                loops: Bool = false,
                strokeColor: Color = .primary,
                radicalColor: Color? = nil,
                ghostColor: Color = .secondary.opacity(0.15),
                gridColor: Color? = .red.opacity(0.35)) {
        self.character = character
        self.speed = speed
        self.delayBetweenStrokes = delayBetweenStrokes
        self.loops = loops
        self.strokeColor = strokeColor
        self.radicalColor = radicalColor
        self.ghostColor = ghostColor
        self.gridColor = gridColor
    }

    public var body: some View {
        let schedule = makeSchedule()
        let total = schedule.last.map { $0.start + $0.duration } ?? 0

        TimelineView(.animation(minimumInterval: nil, paused: isFinished)) { timeline in
            let elapsed = timeline.date.timeIntervalSince(startDate)
            let t: TimeInterval = isFinished ? .infinity
                : loops ? elapsed.truncatingRemainder(dividingBy: total + 1.0)
                : elapsed

            Canvas { ctx, size in
                HanziRenderer.draw(character, in: ctx, size: size,
                                   ghostColor: ghostColor,
                                   gridColor: gridColor,
                                   progress: { i in
                                       let slot = schedule[i]
                                       return min(max((t - slot.start) / slot.duration, 0), 1)
                                   },
                                   color: color(for:))
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .contentShape(Rectangle())
        .onTapGesture { startDate = Date() }
        .onChange(of: character.character) { startDate = Date() }
        .task(id: startDate) {
            isFinished = false
            guard !loops else { return }
            try? await Task.sleep(for: .seconds(total))
            if !Task.isCancelled { isFinished = true }
        }
        .accessibilityElement()
        .accessibilityLabel("Stroke order for \(character.character), \(character.strokeCount) strokes")
        .accessibilityAddTraits(.startsMediaSession)
    }

    private func color(for index: Int) -> Color {
        if let radicalColor, character.radicalStrokes.contains(index) { return radicalColor }
        return strokeColor
    }

    /// Same pacing as Hanzi Writer: duration grows with median length.
    private func makeSchedule() -> [(start: TimeInterval, duration: TimeInterval)] {
        var schedule: [(start: TimeInterval, duration: TimeInterval)] = []
        var cursor: TimeInterval = 0
        for index in 0..<character.strokeCount {
            let duration = (Double(character.medianLength(index)) + 600) / (3000 * max(speed, 0.01))
            schedule.append((cursor, duration))
            cursor += duration + delayBetweenStrokes
        }
        return schedule
    }
}
