import XCTest
import SwiftUI
@testable import HanziStroke

/// Renders finished characters and compares them with reference PNGs in `__Snapshots__`.
/// A missing reference is recorded and the test fails once; re-run to compare.
/// Delete a reference to re-record it after an intentional rendering change.
@MainActor
final class SnapshotTests: XCTestCase {
    /// 了: a hook stroke (亅).
    func testHookStroke() throws { try assertSnapshot("了", strokes: 2) }

    /// 體: 23 strokes.
    func testManyStrokes() throws { try assertSnapshot("體", strokes: 23) }

    /// 愛: radical strokes in a different colour.
    func testRadicalColour() throws { try assertSnapshot("愛", strokes: 13, radicalColor: .red) }

    /// The step chart's emphasized stroke is thicker, not just a different colour.
    func testEmphasisAddsInk() throws {
        let c = try fixture("了")
        let plain = try XCTUnwrap(render(c, emphasized: nil)), thick = try XCTUnwrap(render(c, emphasized: 1))
        XCTAssertGreaterThan(inkFraction(thick), inkFraction(plain) * 1.1)
    }

    // MARK: Helpers

    private func fixture(_ character: String) throws -> HanziCharacter {
        try HanziDataLoader.fromBundle(character, bundle: .module, subdirectory: "Fixtures")
    }

    private func assertSnapshot(_ character: String, strokes: Int, radicalColor: Color? = nil,
                                file: StaticString = #filePath, line: UInt = #line) throws {
        let c = try fixture(character)
        XCTAssertEqual(c.strokeCount, strokes, file: file, line: line)
        let image = try XCTUnwrap(render(c, radicalColor: radicalColor))
        XCTAssertGreaterThan(inkFraction(image), 0.05, "character should be drawn", file: file, line: line)

        let dir = URL(fileURLWithPath: "\(file)").deletingLastPathComponent().appendingPathComponent("__Snapshots__")
        let name = (character.unicodeScalars.map { String($0.value, radix: 16) }.joined()) + ".png"
        let url = dir.appendingPathComponent(name)

        guard let reference = loadPNG(url) else {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try writePNG(image, to: url)
            XCTFail("Recorded new reference \(name); re-run to compare.", file: file, line: line)
            return
        }
        let diff = difference(image, reference)
        XCTAssertLessThan(diff, 0.01, "\(name) differs from reference by \(diff)", file: file, line: line)
    }

    private func render(_ c: HanziCharacter, radicalColor: Color? = nil, emphasized: Int? = nil) -> CGImage? {
        let view = Canvas { ctx, size in
            HanziRenderer.draw(c, in: ctx, size: size, ghostColor: .clear, gridColor: nil,
                               progress: { _ in 1 },
                               color: { i in radicalColor.flatMap { c.radicalStrokes.contains(i) ? $0 : nil } ?? .black },
                               emphasized: emphasized)
        }
        .frame(width: 128, height: 128)
        .background(.white)
        .environment(\.colorScheme, .light)

        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        return renderer.cgImage
    }

    private func pixels(_ image: CGImage) -> [UInt8] {
        let w = 128, h = 128
        var buffer = [UInt8](repeating: 0, count: w * h * 4)
        buffer.withUnsafeMutableBytes { raw in
            let ctx = CGContext(data: raw.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        }
        return buffer
    }

    /// Fraction of pixels that aren't (nearly) white.
    private func inkFraction(_ image: CGImage) -> Double {
        let p = pixels(image)
        let inked = stride(from: 0, to: p.count, by: 4).filter { Int(p[$0]) + Int(p[$0 + 1]) + Int(p[$0 + 2]) < 600 }
        return Double(inked.count) / Double(p.count / 4)
    }

    /// Fraction of pixels whose colour differs by more than a small antialiasing tolerance.
    private func difference(_ a: CGImage, _ b: CGImage) -> Double {
        let pa = pixels(a), pb = pixels(b)
        var differing = 0
        for i in stride(from: 0, to: pa.count, by: 4) {
            let delta = (0..<3).map { abs(Int(pa[i + $0]) - Int(pb[i + $0])) }.max()!
            if delta > 48 { differing += 1 }
        }
        return Double(differing) / Double(pa.count / 4)
    }

    private func loadPNG(_ url: URL) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }

    private func writePNG(_ image: CGImage, to url: URL) throws {
        let dest = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil))
        CGImageDestinationAddImage(dest, image, nil)
        XCTAssertTrue(CGImageDestinationFinalize(dest))
    }
}
