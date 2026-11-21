import SwiftUI

/// Credits the character data and shows the Arphic Public License that must ship with it.
struct AcknowledgementsView: View {
    @Environment(\.dismiss) private var dismiss

    private let licenseText: String = {
        guard let url = Bundle.main.url(forResource: "ARPHICPL", withExtension: "TXT", subdirectory: "HanziData.bundle"),
              let text = try? String(contentsOf: url, encoding: .utf8) else { return "" }
        return text
    }()

    var body: some View {
        NavigationStack {
            List {
                Section("Character data") {
                    Text("Stroke data comes from hanzi-writer-data, which is based on Make Me a Hanzi and fonts by Arphic Technology. It is used under the Arphic Public License.")
                    Link("hanzi-writer-data on GitHub", destination: URL(string: "https://github.com/chanind/hanzi-writer-data")!)
                    Link("Make Me a Hanzi on GitHub", destination: URL(string: "https://github.com/skishore/makemeahanzi")!)
                }
                Section("Privacy") {
                    Text("About 3,900 common characters (roughly a sixth-grade reading level, in Traditional and Simplified forms) are built into the app and work offline. When you look up any other character for the first time, the app downloads its stroke data from the jsDelivr CDN, which receives the character and your IP address. After that, the data is stored on this device.")
                }
                Section("Arphic Public License") {
                    Text(verbatim: licenseText)
                        .font(.footnote.monospaced())
                        .textSelection(.enabled)
                }
            }
            .navigationTitle("Acknowledgements")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    AcknowledgementsView()
}
