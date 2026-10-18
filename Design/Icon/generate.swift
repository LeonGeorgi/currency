import AppKit
import CoreText

// Vector-only source artwork. Icon Composer supplies all lighting and materials.
let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

func svg(_ body: String, named name: String) throws {
    let source = """
    <svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
      \(body)
    </svg>
    """
    try source.write(to: output.appendingPathComponent(name + ".svg"), atomically: true, encoding: .utf8)
}

func symbol(_ character: String, center: CGPoint, height: CGFloat, opticalOffsetX: CGFloat = 0, color: String, named name: String) throws {
    let system = NSFont.systemFont(ofSize: 300, weight: .medium)
    let descriptor = system.fontDescriptor.withDesign(.rounded) ?? system.fontDescriptor
    let font = CTFontCreateWithFontDescriptor(descriptor, 300, nil)
    var scalar = Array(character.utf16)[0]
    var glyph = CGGlyph()
    CTFontGetGlyphsForCharacters(font, &scalar, &glyph, 1)
    let original = CTFontCreatePathForGlyph(font, glyph, nil)!
    let bounds = original.boundingBoxOfPath
    let scale = height / bounds.height
    var transform = CGAffineTransform(a: scale, b: 0, c: 0, d: -scale,
                                     tx: center.x - bounds.midX * scale + opticalOffsetX,
                                     ty: center.y + bounds.midY * scale)
    let path = original.copy(using: &transform)!
    func number(_ n: CGFloat) -> String { String(format: "%.3f", n) }
    func point(_ p: CGPoint) -> String { "\(number(p.x)) \(number(p.y))" }
    var commands = [String]()
    path.applyWithBlock { pointer in
        let element = pointer.pointee
        switch element.type {
        case .moveToPoint: commands.append("M" + point(element.points[0]))
        case .addLineToPoint: commands.append("L" + point(element.points[0]))
        case .addQuadCurveToPoint: commands.append("Q" + point(element.points[0]) + " " + point(element.points[1]))
        case .addCurveToPoint: commands.append("C" + point(element.points[0]) + " " + point(element.points[1]) + " " + point(element.points[2]))
        case .closeSubpath: commands.append("Z")
        @unknown default: break
        }
    }
    try svg("<path fill=\"\(color)\" d=\"\(commands.joined(separator: " "))\"/>", named: name)
}

try svg("<circle cx=\"366\" cy=\"366\" r=\"232\" fill=\"#45DED0\"/>", named: "01-Euro-Coin")
// Align the center of the Euro's rounded bowl with the coin. The leftward bars
// shift the full glyph's bounding box, so it needs a small optical correction.
try symbol("€", center: CGPoint(x: 366, y: 366), height: 240, opticalOffsetX: -20, color: "#F3FFFB", named: "02-Euro")
try svg("<circle cx=\"658\" cy=\"658\" r=\"232\" fill=\"#F3FFFB\"/>", named: "03-Dollar-Coin")
try symbol("$", center: CGPoint(x: 658, y: 658), height: 265, color: "#087F83", named: "04-Dollar")
