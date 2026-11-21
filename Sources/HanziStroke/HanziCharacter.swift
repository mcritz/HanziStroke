import SwiftUI

/// Stroke data for one character, in a 1024×1024 box with the origin at the top left
/// (SwiftUI's coordinate convention).
public struct HanziCharacter {
    public static let gridSize: CGFloat = 1024

    public let character: String
    /// Filled outline of each stroke, in stroke order.
    public let outlines: [Path]
    /// Centre line of each stroke, from where the brush starts to where it lifts.
    public let medians: [[CGPoint]]
    /// Indices of strokes that belong to the radical (may be empty).
    public let radicalStrokes: Set<Int>

    public var strokeCount: Int { outlines.count }

    public init(character: String, outlines: [Path], medians: [[CGPoint]], radicalStrokes: Set<Int>) {
        precondition(outlines.count == medians.count, "Every stroke needs an outline and a median")
        self.character = character
        self.outlines = outlines
        self.medians = medians
        self.radicalStrokes = radicalStrokes
    }

    /// Decodes a hanzi-writer-data JSON file (`{ strokes, medians, radStrokes }`).
    public init(character: String, jsonData: Data) throws {
        let raw = try JSONDecoder().decode(Raw.self, from: jsonData)
        // Source data is y-up with the top edge at y = 900 and the bottom at y = -124.
        let flip: (Double, Double) -> CGPoint = { x, y in CGPoint(x: x, y: 900 - y) }
        let outlines = try raw.strokes.map { try SVGPathParser.parse($0, transform: flip) }
        let medians = raw.medians.map { stroke in
            stroke.compactMap { pair in pair.count == 2 ? flip(pair[0], pair[1]) : nil }
        }
        self.init(character: character,
                  outlines: outlines,
                  medians: medians,
                  radicalStrokes: Set(raw.radStrokes ?? []))
    }

    /// Returns a copy with strokes rearranged, e.g. to match Taiwan (MOE) order where it
    /// differs from the PRC order in the source data. `order[i]` is the source index of
    /// the stroke to draw i-th. This fixes ordering only, not stroke shape or direction.
    public func reordered(_ order: [Int]) -> HanziCharacter {
        precondition(order.sorted() == Array(0..<strokeCount), "order must be a permutation of all strokes")
        let newRadicals = Set(order.enumerated().compactMap { radicalStrokes.contains($0.element) ? $0.offset : nil })
        return HanziCharacter(character: character,
                              outlines: order.map { outlines[$0] },
                              medians: order.map { medians[$0] },
                              radicalStrokes: newRadicals)
    }

    /// The median as a path, for trimming during animation.
    func medianPath(_ index: Int) -> Path {
        var path = Path()
        path.addLines(medians[index])
        return path
    }

    /// Length of a stroke's median, used to pace the animation.
    func medianLength(_ index: Int) -> CGFloat {
        zip(medians[index], medians[index].dropFirst()).reduce(0) { total, pair in
            total + hypot(pair.1.x - pair.0.x, pair.1.y - pair.0.y)
        }
    }

    private struct Raw: Decodable {
        let strokes: [String]
        let medians: [[[Double]]]
        let radStrokes: [Int]?
    }
}

/// Loads character data either from your app bundle or from the jsDelivr CDN.
public enum HanziDataLoader {
    public enum LoadError: Error {
        case notFound(String)
    }

    /// Looks for `<character>.json` in the bundle, e.g. a folder reference named
    /// `hanzi-data` containing the JSON files from the `hanzi-writer-data` npm package.
    public static func fromBundle(_ character: String,
                                  bundle: Bundle = .main,
                                  subdirectory: String? = "hanzi-data") throws -> HanziCharacter {
        guard let url = bundle.url(forResource: character, withExtension: "json", subdirectory: subdirectory) else {
            throw LoadError.notFound(character)
        }
        return try HanziCharacter(character: character, jsonData: Data(contentsOf: url))
    }

    /// Fetches `<character>.json` from jsDelivr. Fine for prototyping; bundle the data to work offline.
    public static func fromCDN(_ character: String,
                               version: String = "2.0.1",
                               session: URLSession = .shared) async throws -> HanziCharacter {
        guard let encoded = character.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "https://cdn.jsdelivr.net/npm/hanzi-writer-data@\(version)/\(encoded).json")
        else { throw LoadError.notFound(character) }

        let (data, response) = try await session.data(from: url)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw LoadError.notFound(character)
        }
        return try HanziCharacter(character: character, jsonData: data)
    }
}
