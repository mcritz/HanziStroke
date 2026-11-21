import SwiftUI

/// Drop-in demo screen: type a character, see the animation and the step chart.
public struct HanziStrokeDemo: View {
    @State private var input = "書"
    @State private var character: HanziCharacter?
    @State private var message: Text?

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                TextField(text: $input) { Text(verbatim: "字") }
                    .font(.system(size: 40))
                    .multilineTextAlignment(.center)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 100)

                if let character {
                    StrokeOrderView(character: character, radicalColor: .blue)
                        .frame(width: 260, height: 260)
                    Text("\(Strings.strokeCount(character.strokeCount)) · tap to replay", bundle: .module)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    StrokeStepsView(character: character)
                } else if let message {
                    message.foregroundStyle(.secondary)
                } else {
                    ProgressView()
                }
            }
            .padding()
        }
        .task(id: input) { await load() }
    }

    private func load() async {
        do {
            let loaded = try await HanziDataLoader.load(input)
            guard !Task.isCancelled else { return }
            character = loaded
            message = nil
        } catch {
            guard !Task.isCancelled else { return }
            character = nil
            message = Self.describe(error)
        }
    }

    static func describe(_ error: Error) -> Text {
        switch error as? HanziDataLoader.LoadError {
        case .invalidCharacter?:
            Text("Type a Chinese character", bundle: .module)
        case .notFound(let c)?, .badData(let c)?:
            Text("No stroke data for \(c)", bundle: .module)
        case .network?, .server?, nil:
            Text("Couldn't reach the server. Check your connection and try again.", bundle: .module)
        }
    }
}

#Preview {
    HanziStrokeDemo()
}
