import SwiftUI
import HanziStroke

struct CharacterDetailView: View {
    let sample: Sample

    @State private var character: HanziCharacter?
    @State private var loadError: HanziDataLoader.LoadError?

    @AppStorage("speed") private var speed = 1.0
    @AppStorage("loops") private var loops = false
    @AppStorage("highlightRadical") private var highlightRadical = true
    @AppStorage("showGrid") private var showGrid = true
    @State private var replayToken = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if let character {
                    loaded(character)
                } else if let loadError {
                    failure(loadError)
                } else {
                    ProgressView("Loading \(sample.character)…")
                        .padding(.top, 120)
                }
            }
            .padding()
        }
        .navigationTitle(Text(verbatim: sample.character))
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    @ViewBuilder
    private func loaded(_ character: HanziCharacter) -> some View {
        VStack(spacing: 4) {
            if !sample.pinyin.isEmpty {
                Text(verbatim: sample.pinyin).font(.title2.weight(.semibold))
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

        if reduceMotion {
            Text("Reduce Motion is on, so the finished character is shown. The steps below show the order.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        } else {
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
                        Image(systemName: "tortoise").accessibilityHidden(true)
                        Slider(value: $speed, in: 0.25...3, step: 0.25) {
                            Text("Speed")
                        }
                        .accessibilityValue(Text("\(speed, format: .number.precision(.fractionLength(2)))×"))
                        Image(systemName: "hare").accessibilityHidden(true)
                    }
                    Text("Speed \(speed, format: .number.precision(.fractionLength(2)))×")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                    Toggle("Loop", isOn: $loops)
                    Toggle("Highlight radical", isOn: $highlightRadical)
                        .disabled(character.radicalStrokes.isEmpty)
                    Toggle("Practice grid", isOn: $showGrid)
                }
            }
            .onChange(of: loops) { replayToken += 1 }
            .onChange(of: speed) { replayToken += 1 }
        }

        VStack(alignment: .leading, spacing: 8) {
            Text("Step by step").font(.headline)
            StrokeStepsView(character: character, panelSize: 60,
                            gridColor: showGrid ? .secondary.opacity(0.3) : nil)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func failure(_ error: HanziDataLoader.LoadError) -> some View {
        switch error {
        case .network, .server:
            ContentUnavailableView {
                Label("Can't connect", systemImage: "wifi.exclamationmark")
            } description: {
                Text("Stroke data for “\(sample.character)” isn't on this device yet. Check your connection and try again.")
            } actions: {
                Button("Try Again") { Task { await load() } }
            }
            .padding(.top, 60)
        case .notFound, .invalidCharacter, .badData:
            ContentUnavailableView {
                Label("No stroke data", systemImage: "character.magnify")
            } description: {
                Text("The stroke data set doesn't include “\(sample.character)”. Try a different character.")
            }
            .padding(.top, 60)
        }
    }

    private func load() async {
        loadError = nil
        do {
            character = try await HanziDataLoader.load(sample.character, subdirectory: "HanziData.bundle")
        } catch let error as HanziDataLoader.LoadError {
            loadError = error
        } catch {
            loadError = .network(.unknown)
        }
    }
}

#Preview {
    NavigationStack {
        CharacterDetailView(sample: Sample(character: "愛", pinyin: "ài", meaning: "love"))
    }
}
