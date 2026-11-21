import SwiftUI

/// Stroke data for one character, in a 1024×1024 box with the origin at the top left
/// (SwiftUI's coordinate convention).
public struct HanziCharacter: Sendable {
    public static let gridSize: CGFloat = 1024

    public let character: String
    /// Filled outline of each stroke, in stroke order.
    public let outlines: [Path]
    /// Centre line of each stroke, from where the brush starts to where it lifts.
    public let medians: [[CGPoint]]
    /// Indices of strokes that belong to the radical (may be empty).
    public let radicalStrokes: Set<Int>

    public var strokeCount: Int { outlines.count }

    public enum DataError: Error, Equatable, Sendable {
        /// The file has a different number of outlines and medians, or no strokes at all.
        case strokeCountMismatch(outlines: Int, medians: Int)
        /// A median has fewer than two points, so it can't be animated.
        case degenerateMedian(stroke: Int)
        /// A radical index points past the last stroke.
        case radicalOutOfRange(Int)
    }

    /// Builds a character from already-validated parts. Traps if the counts disagree;
    /// use ``init(character:jsonData:)`` for untrusted data.
    public init(character: String, outlines: [Path], medians: [[CGPoint]], radicalStrokes: Set<Int>) {
        precondition(outlines.count == medians.count, "Every stroke needs an outline and a median")
        self.character = character
        self.outlines = outlines
        self.medians = medians
        self.radicalStrokes = radicalStrokes
    }

    /// Decodes a hanzi-writer-data JSON file (`{ strokes, medians, radStrokes }`).
    /// Throws instead of trapping on malformed or truncated data.
    public init(character: String, jsonData: Data) throws {
        let raw = try JSONDecoder().decode(Raw.self, from: jsonData)
        guard !raw.strokes.isEmpty, raw.strokes.count == raw.medians.count else {
            throw DataError.strokeCountMismatch(outlines: raw.strokes.count, medians: raw.medians.count)
        }
        // Source data is y-up with the top edge at y = 900 and the bottom at y = -124.
        let flip: (Double, Double) -> CGPoint = { x, y in CGPoint(x: x, y: 900 - y) }
        let outlines = try raw.strokes.map { try SVGPathParser.parse($0, transform: flip) }
        let medians = raw.medians.map { stroke in
            stroke.compactMap { pair in pair.count == 2 ? flip(pair[0], pair[1]) : nil }
        }
        if let bad = medians.firstIndex(where: { $0.count < 2 }) {
            throw DataError.degenerateMedian(stroke: bad)
        }
        let radicals = Set(raw.radStrokes ?? [])
        if let bad = radicals.first(where: { $0 < 0 || $0 >= outlines.count }) {
            throw DataError.radicalOutOfRange(bad)
        }
        self.init(character: character, outlines: outlines, medians: medians, radicalStrokes: radicals)
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

    /// Picks the last CJK ideograph out of user input, dropping variation selectors and
    /// anything else (letters, punctuation, emoji). Returns nil if there is none.
    public static func normalize(_ input: String) -> String? {
        let ideographs = input.unicodeScalars.filter { $0.properties.isIdeographic && !isVariationSelector($0) }
        return ideographs.last.map { String(Character($0)) }
    }

    private static func isVariationSelector(_ s: Unicode.Scalar) -> Bool {
        (0xFE00...0xFE0F).contains(s.value) || (0xE0100...0xE01EF).contains(s.value)
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

/// Loads character data from your app bundle, an on-disk cache, or the jsDelivr CDN.
///
/// Privacy: a CDN request sends the looked-up character and the user's IP address to
/// jsDelivr. Bundle the characters you need (or self-host) to avoid that.
public enum HanziDataLoader {
    public enum LoadError: Error, Equatable, Sendable {
        /// The input contained no CJK ideograph.
        case invalidCharacter(String)
        /// The data set has no entry for this character (HTTP 404 or missing file).
        case notFound(String)
        /// The network failed (offline, timeout, …). Worth retrying.
        case network(URLError.Code)
        /// The server answered with an unexpected status. Possibly worth retrying.
        case server(statusCode: Int)
        /// The file was found but couldn't be decoded.
        case badData(String)

        /// Whether trying again later could succeed.
        public var isRetryable: Bool {
            switch self {
            case .network, .server: true
            case .invalidCharacter, .notFound, .badData: false
            }
        }
    }

    /// Looks in the bundle, then the disk cache, then the CDN (caching what it downloads).
    /// `input` is normalized with ``HanziCharacter/normalize(_:)`` first.
    public static func load(_ input: String,
                            bundle: Bundle = .main,
                            subdirectory: String? = "hanzi-data",
                            cache: HanziDiskCache? = .shared,
                            session: URLSession = .shared) async throws -> HanziCharacter {
        guard let character = HanziCharacter.normalize(input) else {
            throw LoadError.invalidCharacter(input)
        }
        if let c = try? fromBundle(character, bundle: bundle, subdirectory: subdirectory) {
            return c
        }
        if let data = cache?.data(for: character),
           let c = try? HanziCharacter(character: character, jsonData: data) {
            return c
        }
        let data = try await fetch(character, session: session)
        let c = try decode(character, data)
        cache?.store(data, for: character)
        return c
    }

    /// Looks for `<character>.json` in the bundle, e.g. a folder reference named
    /// `hanzi-data` containing the JSON files from the `hanzi-writer-data` npm package.
    /// Also checks the bundle root, where Xcode's synchronized folders put resources.
    public static func fromBundle(_ input: String,
                                  bundle: Bundle = .main,
                                  subdirectory: String? = "hanzi-data") throws -> HanziCharacter {
        guard let character = HanziCharacter.normalize(input) else {
            throw LoadError.invalidCharacter(input)
        }
        guard let url = bundle.url(forResource: character, withExtension: "json", subdirectory: subdirectory)
                ?? bundle.url(forResource: character, withExtension: "json") else {
            throw LoadError.notFound(character)
        }
        guard let data = try? Data(contentsOf: url) else { throw LoadError.notFound(character) }
        return try decode(character, data)
    }

    /// Fetches `<character>.json` from jsDelivr, skipping bundle and disk cache.
    public static func fromCDN(_ input: String,
                               version: String = "2.0.1",
                               session: URLSession = .shared) async throws -> HanziCharacter {
        guard let character = HanziCharacter.normalize(input) else {
            throw LoadError.invalidCharacter(input)
        }
        return try decode(character, try await fetch(character, version: version, session: session))
    }

    private static func fetch(_ character: String,
                              version: String = "2.0.1",
                              session: URLSession) async throws -> Data {
        guard let encoded = character.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "https://cdn.jsdelivr.net/npm/hanzi-writer-data@\(version)/\(encoded).json")
        else { throw LoadError.invalidCharacter(character) }

        let data: Data, response: URLResponse
        do {
            (data, response) = try await session.data(from: url)
        } catch let error as URLError {
            throw LoadError.network(error.code)
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        switch status {
        case 200: return data
        case 404: throw LoadError.notFound(character)
        default: throw LoadError.server(statusCode: status)
        }
    }

    private static func decode(_ character: String, _ data: Data) throws -> HanziCharacter {
        do {
            return try HanziCharacter(character: character, jsonData: data)
        } catch {
            throw LoadError.badData(character)
        }
    }
}

/// Stores downloaded character files in the Caches directory so they work offline
/// after the first fetch. The system may purge it under storage pressure.
public struct HanziDiskCache: Sendable {
    public static let shared: HanziDiskCache? = {
        guard let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else { return nil }
        return HanziDiskCache(directory: caches.appendingPathComponent("hanzi-data", isDirectory: true))
    }()

    public let directory: URL

    public init(directory: URL) {
        self.directory = directory
    }

    public func data(for character: String) -> Data? {
        try? Data(contentsOf: fileURL(for: character))
    }

    public func store(_ data: Data, for character: String) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? data.write(to: fileURL(for: character), options: .atomic)
    }

    /// Named by code point (e.g. `611B.json`) so file names stay ASCII.
    private func fileURL(for character: String) -> URL {
        let name = character.unicodeScalars.map { String($0.value, radix: 16, uppercase: true) }.joined(separator: "-")
        return directory.appendingPathComponent(name).appendingPathExtension("json")
    }
}
