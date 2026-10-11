// Нютаг: SVG -> PNG (прозрачный фон) или PDF (вектор). swift svg2.swift in.svg out.png|out.pdf <размер>
import AppKit

let args = CommandLine.arguments
guard args.count == 4, let size = Double(args[3]), let image = NSImage(contentsOf: URL(fileURLWithPath: args[1])) else {
    FileHandle.standardError.write("usage: svg2 in.svg out.(png|pdf) size\n".data(using: .utf8)!); exit(1)
}
let out = URL(fileURLWithPath: args[2])
let rect = NSRect(x: 0, y: 0, width: size, height: size)
if out.pathExtension == "pdf" {
    var box = CGRect(origin: .zero, size: CGSize(width: size, height: size))
    guard let context = CGContext(out as CFURL, mediaBox: &box, nil) else { exit(2) }
    context.beginPDFPage(nil)
    NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
    image.draw(in: rect)
    context.endPDFPage()
    context.closePDF()
} else {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size), bitsPerSample: 8, samplesPerPixel: 4,
                               hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    image.draw(in: rect)
    NSGraphicsContext.restoreGraphicsState()
    try! rep.representation(using: .png, properties: [:])!.write(to: out)
}
