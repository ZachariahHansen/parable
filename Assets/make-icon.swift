// Draws Parable's app icon and writes a 1024x1024 PNG.
// Usage: swift Assets/make-icon.swift Assets/AppIcon.png   (make-icon.sh wraps this)
import AppKit

let size: CGFloat = 1024
let space = CGColorSpace(name: CGColorSpace.sRGB)!
let context = CGContext(data: nil, width: Int(size), height: Int(size), bitsPerComponent: 8, bytesPerRow: 0,
                        space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: space, components: [CGFloat((hex >> 16) & 0xFF) / 255, CGFloat((hex >> 8) & 0xFF) / 255,
                                            CGFloat(hex & 0xFF) / 255, alpha])!
}

// The plate: macOS's rounded square, inset the way system icons are, with a soft shadow.
let plate = CGRect(x: 100, y: 100, width: 824, height: 824)
let plateShape = CGPath(roundedRect: plate, cornerWidth: 186, cornerHeight: 186, transform: nil)
context.saveGState()
context.setShadow(offset: CGSize(width: 0, height: -10), blur: 22, color: color(0x000000, 0.28))
context.addPath(plateShape)
context.setFillColor(color(0x3B22A6))
context.fillPath()
context.restoreGState()

// One smooth diagonal blend, violet to indigo. No extra highlights.
context.saveGState()
context.addPath(plateShape)
context.clip()
let fill = CGGradient(colorsSpace: space, colors: [color(0x7F60FF), color(0x3B22A6)] as CFArray, locations: [0, 1])!
context.drawLinearGradient(fill, start: CGPoint(x: plate.minX, y: plate.maxY), end: CGPoint(x: plate.maxX, y: plate.minY), options: [])
context.restoreGState()

// The mark: a letter P whose hollow is a play button. Flat white, no shadow.
// Outer corners share one radius, and the bowl's right side is a true half circle.
let stemLeft: CGFloat = 334, stemWidth: CGFloat = 128, bottom: CGFloat = 244, top: CGFloat = 780
let bowlHeight: CGFloat = 332, bowlRight: CGFloat = 734, corner: CGFloat = 44
let bowlBottom = top - bowlHeight, bowlRadius = bowlHeight / 2

context.saveGState()
context.beginTransparencyLayer(auxiliaryInfo: nil)
context.setFillColor(color(0xFFFFFF))
// One continuous outline, so the stem and bowl meet without bumps or notches.
let stemRight = stemLeft + stemWidth
let mark = CGMutablePath()
mark.move(to: CGPoint(x: stemLeft + corner, y: bottom))
mark.addArc(tangent1End: CGPoint(x: stemRight, y: bottom), tangent2End: CGPoint(x: stemRight, y: bowlBottom), radius: corner)
mark.addArc(tangent1End: CGPoint(x: stemRight, y: bowlBottom), tangent2End: CGPoint(x: bowlRight, y: bowlBottom), radius: 18)
mark.addLine(to: CGPoint(x: bowlRight - bowlRadius, y: bowlBottom))
mark.addArc(center: CGPoint(x: bowlRight - bowlRadius, y: bowlBottom + bowlRadius), radius: bowlRadius,
            startAngle: -.pi / 2, endAngle: .pi / 2, clockwise: false)
mark.addArc(tangent1End: CGPoint(x: stemLeft, y: top), tangent2End: CGPoint(x: stemLeft, y: bottom), radius: corner)
mark.addArc(tangent1End: CGPoint(x: stemLeft, y: bottom), tangent2End: CGPoint(x: stemRight, y: bottom), radius: corner)
mark.closeSubpath()
context.addPath(mark)
context.fillPath(using: .winding)

// Play triangle cut out of the bowl, balanced on the centre of its round end.
// The round stroke softens the corners to match the rest of the mark.
let centre = CGPoint(x: bowlRight - bowlRadius + 6, y: bowlBottom + bowlRadius)
let reach: CGFloat = 88, soften: CGFloat = 22
let triangle = CGMutablePath()
triangle.move(to: CGPoint(x: centre.x - reach / 2, y: centre.y - reach * 0.866))
triangle.addLine(to: CGPoint(x: centre.x - reach / 2, y: centre.y + reach * 0.866))
triangle.addLine(to: CGPoint(x: centre.x + reach, y: centre.y))
triangle.closeSubpath()
context.setBlendMode(.clear)
context.addPath(triangle)
context.setLineJoin(.round)
context.setLineWidth(soften)
context.setStrokeColor(color(0x000000))
context.drawPath(using: .fillStroke)
context.endTransparencyLayer()
context.restoreGState()

let image = NSBitmapImageRep(cgImage: context.makeImage()!)
try! image.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
