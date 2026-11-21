import SwiftUI

/// Animates a character stroke by stroke. Tap to replay.
///
/// With Reduce Motion on, shows the finished character instead of animating.
/// The animation pauses while the view is off screen or the app is in the background.
public struct StrokeOrderView: View {
    public let character: HanziCharacter
    public var speed: Double
    public var delayBetweenStrokes: TimeInterval
    public var loops: Bool
    public var strokeColor: Color
    public var radicalColor: Color?
    public var ghostColor: Color
    public var gridColor: Color?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    @State private var startDate = Date()
    @State private var isFinished = false
    @State private var isVisible = false
    /// Elapsed animation time when it was paused, so it resumes where it left off.
    @State private var pausedElapsed: TimeInterval?

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

    private var isRunning: Bool {
        !reduceMotion && !isFinished && isVisible && scenePhase == .active
    }

    public var body: some View {
        let schedule = makeSchedule()
        let total = schedule.last.map { $0.start + $0.duration } ?? 0

        TimelineView(.animation(minimumInterval: nil, paused: !isRunning)) { timeline in
            let elapsed = pausedElapsed ?? timeline.date.timeIntervalSince(startDate)
            let t: TimeInterval = (reduceMotion || isFinished) ? .infinity
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
        .onTapGesture(perform: replay)
        .onChange(of: character.character) { replay() }
        .onAppear { isVisible = true }
        .onDisappear { isVisible = false }
        .onChange(of: isRunning) { _, running in
            if running {
                // Shift the start so the animation continues from where it paused.
                if let paused = pausedElapsed { startDate = Date().addingTimeInterval(-paused) }
                pausedElapsed = nil
            } else if !isFinished {
                pausedElapsed = Date().timeIntervalSince(startDate)
            }
        }
        .task(id: TaskKey(start: startDate, running: isRunning)) {
            guard isRunning, !loops else { return }
            let remaining = total - Date().timeIntervalSince(startDate)
            try? await Task.sleep(for: .seconds(max(remaining, 0)))
            if !Task.isCancelled { isFinished = true }
        }
        .accessibilityElement()
        .accessibilityLabel(Text("Stroke order for \(character.character)", bundle: .module))
        .accessibilityValue(Text(Strings.strokeCount(character.strokeCount)))
        .accessibilityAddTraits(reduceMotion ? [.isImage] : [.isImage, .isButton])
        .accessibilityHint(reduceMotion ? Text(verbatim: "") : Text("Replays the animation", bundle: .module))
        .accessibilityAction(named: Text("Replay", bundle: .module), replay)
    }

    private func replay() {
        startDate = Date()
        pausedElapsed = nil
        isFinished = false
    }

    private struct TaskKey: Equatable {
        let start: Date
        let running: Bool
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

/// Localized strings shared by the package's views.
enum Strings {
    /// The package's resource bundle (tests can't reach the library's `Bundle.module`).
    static var bundle: Bundle { .module }

    /// "1 stroke" / "13 strokes" / "13 畫".
    static func strokeCount(_ count: Int) -> String {
        String(localized: "\(count) strokes", bundle: .module,
               comment: "Number of strokes in a character; has plural variations")
    }
}
