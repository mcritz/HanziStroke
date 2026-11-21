import XCTest
import SwiftUI
@testable import HanziStroke

final class HanziStrokeTests: XCTestCase {
    // 一 from hanzi-writer-data 2.0.1
    let yi = #"{"strokes": ["M 518 382 Q 572 385 623 389 Q 758 399 900 383 Q 928 379 935 390 Q 944 405 930 419 Q 896 452 845 475 Q 829 482 798 473 Q 723 460 480 434 Q 180 409 137 408 Q 130 408 124 408 Q 108 408 106 395 Q 105 380 127 363 Q 146 348 183 334 Q 195 330 216 338 Q 232 344 306 354 Q 400 373 518 382 Z"], "medians": [[[121, 393], [193, 372], [417, 402], [827, 434], [920, 401]]]}"#

    func testDecodesAndFlipsY() throws {
        let c = try HanziCharacter(character: "一", jsonData: Data(yi.utf8))
        XCTAssertEqual(c.strokeCount, 1)
        XCTAssertEqual(c.medians[0].first, CGPoint(x: 121, y: 900 - 393))
        let box = c.outlines[0].boundingRect
        XCTAssertEqual(box.minX, 105, accuracy: 10)
        XCTAssertEqual(box.maxX, 944, accuracy: 10)
        XCTAssertTrue(box.midY > 400 && box.midY < 600, "horizontal stroke should sit mid-box")
    }

    func testParsesCubicsAndCompactNumbers() throws {
        let path = try SVGPathParser.parse("M0,0L10-5C1 2 3 4 5 6Z") { CGPoint(x: $0, y: $1) }
        XCTAssertFalse(path.isEmpty)
        XCTAssertEqual(path.boundingRect.minY, -5, accuracy: 0.001)
    }

    func testRejectsRelativeCommands() {
        XCTAssertThrowsError(try SVGPathParser.parse("m 0 0 l 1 1") { CGPoint(x: $0, y: $1) })
    }

    func testReorderKeepsRadicals() {
        let p = Path(CGRect(x: 0, y: 0, width: 1, height: 1))
        let c = HanziCharacter(character: "x", outlines: [p, p, p],
                               medians: [[.zero], [CGPoint(x: 1, y: 1)], [CGPoint(x: 2, y: 2)]],
                               radicalStrokes: [0])
        let r = c.reordered([2, 0, 1])
        XCTAssertEqual(r.medians[0].first, CGPoint(x: 2, y: 2))
        XCTAssertEqual(r.radicalStrokes, [1])
    }

    // MARK: Malformed data throws instead of crashing

    func testMismatchedCountsThrow() {
        let json = #"{"strokes": ["M 0 0 L 1 1 Z", "M 0 0 L 2 2 Z"], "medians": [[[0, 0], [1, 1]]]}"#
        XCTAssertThrowsError(try HanziCharacter(character: "x", jsonData: Data(json.utf8))) {
            XCTAssertEqual($0 as? HanziCharacter.DataError, .strokeCountMismatch(outlines: 2, medians: 1))
        }
    }

    func testEmptyDataThrows() {
        let json = #"{"strokes": [], "medians": []}"#
        XCTAssertThrowsError(try HanziCharacter(character: "x", jsonData: Data(json.utf8)))
    }

    func testTruncatedDataThrows() {
        XCTAssertThrowsError(try HanziCharacter(character: "一", jsonData: Data(yi.utf8.prefix(120))))
    }

    func testDegenerateMedianThrows() {
        let json = #"{"strokes": ["M 0 0 L 1 1 Z"], "medians": [[[0, 0]]]}"#
        XCTAssertThrowsError(try HanziCharacter(character: "x", jsonData: Data(json.utf8))) {
            XCTAssertEqual($0 as? HanziCharacter.DataError, .degenerateMedian(stroke: 0))
        }
    }

    func testRadicalOutOfRangeThrows() {
        let json = #"{"strokes": ["M 0 0 L 1 1 Z"], "medians": [[[0, 0], [1, 1]]], "radStrokes": [3]}"#
        XCTAssertThrowsError(try HanziCharacter(character: "x", jsonData: Data(json.utf8))) {
            XCTAssertEqual($0 as? HanziCharacter.DataError, .radicalOutOfRange(3))
        }
    }

    // MARK: Input normalization

    func testNormalizeKeepsLastIdeograph() {
        XCTAssertEqual(HanziCharacter.normalize("我愛你!"), "你")
        XCTAssertEqual(HanziCharacter.normalize(" 書 "), "書")
    }

    func testNormalizeStripsVariationSelectors() {
        XCTAssertEqual(HanziCharacter.normalize("愛\u{FE00}"), "愛")
        XCTAssertEqual(HanziCharacter.normalize("葛\u{E0100}"), "葛")
    }

    func testNormalizeRejectsNonIdeographs() {
        XCTAssertNil(HanziCharacter.normalize(""))
        XCTAssertNil(HanziCharacter.normalize("abc"))
        XCTAssertNil(HanziCharacter.normalize("🐉"))
        XCTAssertNil(HanziCharacter.normalize("../etc"))
        XCTAssertNil(HanziCharacter.normalize("ㄅ"), "Zhuyin is not an ideograph")
    }

    func testNormalizeAcceptsExtensionB() {
        XCTAssertEqual(HanziCharacter.normalize("𠀀"), "𠀀")
    }

    // MARK: Loader

    func testBundleLoadUsesFixtures() throws {
        let c = try HanziDataLoader.fromBundle("體", bundle: .module, subdirectory: "Fixtures")
        XCTAssertEqual(c.strokeCount, 23)
    }

    func testBundleMissIsNotFound() {
        XCTAssertThrowsError(try HanziDataLoader.fromBundle("木", bundle: .module, subdirectory: "Fixtures")) {
            XCTAssertEqual($0 as? HanziDataLoader.LoadError, .notFound("木"))
        }
    }

    func testInvalidInputDoesNotHitNetwork() async {
        StubProtocol.handler = { _ in XCTFail("should not request"); throw URLError(.badURL) }
        do {
            _ = try await HanziDataLoader.load("abc", cache: nil, session: .stubbed)
            XCTFail("expected error")
        } catch {
            XCTAssertEqual(error as? HanziDataLoader.LoadError, .invalidCharacter("abc"))
        }
    }

    func testErrorsAreDistinguished() async {
        let cases: [(StubProtocol.Handler, HanziDataLoader.LoadError)] = [
            ({ _ in throw URLError(.notConnectedToInternet) }, .network(.notConnectedToInternet)),
            ({ _ in throw URLError(.timedOut) }, .network(.timedOut)),
            ({ ($0.response(404), Data()) }, .notFound("𠀀")),
            ({ ($0.response(503), Data()) }, .server(statusCode: 503)),
            ({ ($0.response(200), Data("{".utf8)) }, .badData("𠀀")),
        ]
        for (handler, expected) in cases {
            StubProtocol.handler = handler
            do {
                _ = try await HanziDataLoader.load("𠀀", cache: nil, session: .stubbed)
                XCTFail("expected \(expected)")
            } catch {
                XCTAssertEqual(error as? HanziDataLoader.LoadError, expected)
            }
        }
        XCTAssertTrue(HanziDataLoader.LoadError.network(.timedOut).isRetryable)
        XCTAssertFalse(HanziDataLoader.LoadError.notFound("x").isRetryable)
    }

    func testDownloadIsCachedForOffline() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let cache = HanziDiskCache(directory: dir)
        let fixture = try Data(contentsOf: XCTUnwrap(Bundle.module.url(forResource: "了", withExtension: "json",
                                                                       subdirectory: "Fixtures")))

        StubProtocol.handler = { ($0.response(200), fixture) }
        let online = try await HanziDataLoader.load("了", cache: cache, session: .stubbed)

        StubProtocol.handler = { _ in throw URLError(.notConnectedToInternet) }
        let offline = try await HanziDataLoader.load("了", cache: cache, session: .stubbed)
        XCTAssertEqual(offline.strokeCount, online.strokeCount)
    }

    // MARK: Localization

    func testStrokeCountPluralization() {
        XCTAssertEqual(Strings.strokeCount(1), "1 stroke")
        XCTAssertEqual(Strings.strokeCount(13), "13 strokes")
    }

    func testTraditionalChineseLocalizationShips() throws {
        let path = try XCTUnwrap(Strings.bundle.path(forResource: "zh-Hant", ofType: "lproj"))
        let zh = try XCTUnwrap(Bundle(path: path))
        XCTAssertEqual(zh.localizedString(forKey: "Replay", value: nil, table: nil), "重播")
        XCTAssertEqual(String(format: zh.localizedString(forKey: "%lld strokes", value: nil, table: nil), 13), "13 畫")
    }
}

// MARK: - Network stub

final class StubProtocol: URLProtocol {
    typealias Handler = @Sendable (URLRequest) throws -> (HTTPURLResponse, Data)
    nonisolated(unsafe) static var handler: Handler = { _ in throw URLError(.unknown) }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}
    override func startLoading() {
        do {
            let (response, data) = try Self.handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }
}

extension URLSession {
    static let stubbed: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubProtocol.self]
        return URLSession(configuration: config)
    }()
}

extension URLRequest {
    func response(_ status: Int) -> HTTPURLResponse {
        HTTPURLResponse(url: url!, statusCode: status, httpVersion: nil, headerFields: nil)!
    }
}
