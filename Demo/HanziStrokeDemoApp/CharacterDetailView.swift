import SwiftUI
import HanziStroke

struct CharacterDetailView: View {
    let sample: Sample

    @State private var character: HanziCharacter?
    @State private var errorMessage: String?

    @AppStorage("speed") private var speed = 1.0
    @AppStorage("loops") private var loops = false
    @AppStorage("highlightRadical") private var highlightRadical = true
    @AppStorage("showGrid") private var showGrid = true
    @State private var replayToken = 0

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if let character {
                    loaded(character)
                } else if let errorMessage {
                    ContentUnavailableView {
                        Label("No stroke data", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(errorMessage)
                    } actions: {
                        Button("Try again") { Task { await load() } }
                    }
                    .padding(.top, 60)
                } else {
                    ProgressView("Loading \(sample.character)…")
                        .padding(.top, 120)
                }
            }
            .padding()
        }
        .navigationTitle(sample.character)
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    @ViewBuilder
    private func loaded(_ character: HanziCharacter) -> some View {
        VStack(spacing: 4) {
            if !sample.pinyin.isEmpty {
                Text(sample.pinyin).font(.title2.weight(.semibold))
                Text(sample.meaning).foregroundStyle(.secondary)
            }
            Text("\(character.strokeCount) strokes")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }

        StrokeOrderView(character: character,
                        speed: speed,
                        loops: loops,
                        radicalColor: highlightRadical ? .accentColor : nil,
                        gridColor: showGrid ? .red.opacity(0.35) : nil)
            // Changing the id recreates the view, restarting the animation.
            .id(replayToken)
            .frame(maxWidth: 320)
            .background(.background.secondary)

        HStack {
            Button {
                replayToken += 1
            } label: {
                Label("Replay", systemImage: "arrow.counterclockwise")
            }
            .buttonStyle(.borderedProminent)
            Text("or tap the character")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }

        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "tortoise")
                    Slider(value: $speed, in: 0.25...3, step: 0.25)
                    Image(systemName: "hare")
                }
                Text("Speed \(speed, format: .number.precision(.fractionLength(2)))×")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Toggle("Loop", isOn: $loops)
                Toggle("Highlight radical", isOn: $highlightRadical)
                    .disabled(character.radicalStrokes.isEmpty)
                Toggle("Practice grid", isOn: $showGrid)
            }
        }
        .onChange(of: loops) { replayToken += 1 }
        .onChange(of: speed) { replayToken += 1 }

        VStack(alignment: .leading, spacing: 8) {
            Text("Step by step").font(.headline)
            StrokeStepsView(character: character, panelSize: 60,
                            gridColor: showGrid ? .secondary.opacity(0.3) : nil)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func load() async {
        errorMessage = nil
        do {
            character = try await HanziDataLoader.fromCDN(sample.character)
        } catch {
            errorMessage = "Couldn't load stroke data for “\(sample.character)”. Check your connection, or try a different character."
        }
    }
}

#Preview {
    NavigationStack {
        CharacterDetailView(sample: Sample(character: "愛", pinyin: "ài", meaning: "love"))
    }
}
