import SwiftUI

/// Minimal SVG path parser covering what Make Me a Hanzi / hanzi-writer-data uses:
/// absolute M, L, Q, C, Z (with implicit command repetition).
enum SVGPathParser {
    enum ParseError: Error {
        case expectedNumber(at: Int)
        case unsupportedCommand(Character)
    }

    private enum Token {
        case command(Character)
        case number(Double)
    }

    /// Parses `d` into a `Path`, passing every coordinate pair through `transform`.
    static func parse(_ d: String, transform: (Double, Double) -> CGPoint) throws -> Path {
        let tokens = tokenize(d)
        var path = Path()
        var index = 0
        var command: Character = "M"

        func number() throws -> Double {
            guard index < tokens.count, case .number(let value) = tokens[index] else {
                throw ParseError.expectedNumber(at: index)
            }
            index += 1
            return value
        }

        func point() throws -> CGPoint {
            let x = try number()
            let y = try number()
            return transform(x, y)
        }

        while index < tokens.count {
            if case .command(let c) = tokens[index] {
                command = c
                index += 1
                if c == "Z" || c == "z" {
                    path.closeSubpath()
                    continue
                }
            }

            switch command {
            case "M":
                path.move(to: try point())
                command = "L" // subsequent pairs after M are implicit lines
            case "L":
                path.addLine(to: try point())
            case "Q":
                let control = try point()
                let end = try point()
                path.addQuadCurve(to: end, control: control)
            case "C":
                let c1 = try point()
                let c2 = try point()
                let end = try point()
                path.addCurve(to: end, control1: c1, control2: c2)
            default:
                throw ParseError.unsupportedCommand(command)
            }
        }
        return path
    }

    private static func tokenize(_ d: String) -> [Token] {
        var tokens: [Token] = []
        var buffer = ""

        func flush() {
            if !buffer.isEmpty, let value = Double(buffer) {
                tokens.append(.number(value))
            }
            buffer = ""
        }

        for ch in d {
            if ch.isLetter && ch != "e" && ch != "E" {
                flush()
                tokens.append(.command(ch))
            } else if ch == "-" && !buffer.isEmpty && buffer.last != "e" && buffer.last != "E" {
                flush() // "10-5" → 10, -5
                buffer.append(ch)
            } else if ch.isNumber || ch == "." || ch == "-" || ch == "e" || ch == "E" {
                buffer.append(ch)
            } else {
                flush() // whitespace or comma
            }
        }
        flush()
        return tokens
    }
}
