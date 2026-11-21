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
}
