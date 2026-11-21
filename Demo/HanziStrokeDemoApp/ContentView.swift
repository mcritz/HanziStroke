import SwiftUI

struct Sample: Identifiable, Hashable {
    let character: String
    let pinyin: String
    let meaning: String
    var id: String { character }
}

private let samples: [(title: String, items: [Sample])] = [
    ("Basics", [
        Sample(character: "一", pinyin: "yī", meaning: "one"),
        Sample(character: "人", pinyin: "rén", meaning: "person"),
        Sample(character: "大", pinyin: "dà", meaning: "big"),
        Sample(character: "水", pinyin: "shuǐ", meaning: "water"),
        Sample(character: "火", pinyin: "huǒ", meaning: "fire"),
    ]),
    ("Common", [
        Sample(character: "你", pinyin: "nǐ", meaning: "you"),
        Sample(character: "好", pinyin: "hǎo", meaning: "good"),
        Sample(character: "爱", pinyin: "ài", meaning: "love"),
        Sample(character: "我", pinyin: "wǒ", meaning: "I, me"),
        Sample(character: "中", pinyin: "zhōng", meaning: "middle"),
    ]),
    ("Traditional", [
        Sample(character: "書", pinyin: "shū", meaning: "book"),
        Sample(character: "愛", pinyin: "ài", meaning: "love"),
        Sample(character: "龍", pinyin: "lóng", meaning: "dragon"),
        Sample(character: "學", pinyin: "xué", meaning: "study"),
    ]),
]

struct ContentView: View {
    @State private var custom = ""
    @State private var path: [Sample] = []

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section {
                    HStack {
                        TextField("Type any character…", text: $custom)
                            .font(.title3)
                            .submitLabel(.go)
                            .onSubmit(openCustom)
                        Button("Show", action: openCustom)
                            .disabled(custom.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                } header: {
                    Text("Look up")
                }

                ForEach(samples, id: \.title) { group in
                    Section(group.title) {
                        ForEach(group.items) { sample in
                            NavigationLink(value: sample) {
                                HStack(spacing: 16) {
                                    Text(sample.character)
                                        .font(.system(size: 34))
                                        .frame(width: 44)
                                    VStack(alignment: .leading) {
                                        Text(sample.pinyin).font(.headline)
                                        Text(sample.meaning)
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Hanzi Stroke")
            .navigationDestination(for: Sample.self) { sample in
                CharacterDetailView(sample: sample)
            }
        }
    }

    private func openCustom() {
        guard let last = custom.trimmingCharacters(in: .whitespaces).last else { return }
        path.append(Sample(character: String(last), pinyin: "", meaning: ""))
        custom = ""
    }
}

#Preview {
    ContentView()
}
