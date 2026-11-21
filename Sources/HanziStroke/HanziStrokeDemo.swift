import SwiftUI

/// Drop-in demo screen: type a character, see the animation and the step chart.
public struct HanziStrokeDemo: View {
    @State private var input = "書"
    @State private var character: HanziCharacter?
    @State private var message: String?

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                TextField("字", text: $input)
                    .font(.system(size: 40))
                    .multilineTextAlignment(.center)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 100)

                if let character {
                    StrokeOrderView(character: character, radicalColor: .blue)
                        .frame(width: 260, height: 260)
                    Text("\(character.strokeCount) strokes · tap to replay")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    StrokeStepsView(character: character)
                } else if let message {
                    Text(message).foregroundStyle(.secondary)
                } else {
                    ProgressView()
                }
            }
            .padding()
        }
        .task(id: input) { await load() }
    }

    private func load() async {
        guard let last = input.last else { return }
        let c = String(last)
        do {
            let loaded = try await HanziDataLoader.fromCDN(c)
            guard !Task.isCancelled else { return }
            character = loaded
            message = nil
        } catch {
            guard !Task.isCancelled else { return }
            character = nil
            message = "No stroke data for \(c)"
        }
    }
}

#Preview {
    HanziStrokeDemo()
}
