#!/usr/bin/env swift
// Builds App/Assets.xcassets/AppIcon.appiconset from the source picture.
//
//     swift scripts/make-icon.swift [--source Design/AppleIcon.png] [--threshold 0.68]
//
// The source is a TV body with a dark rounded frame on a plain background with its
// own drop shadow. The body is cut out along the traced outer edge of the frame
// (Vision's subject mask leaves a wavy edge and a light fringe), scaled into an
// 824 px square centered on a 1024 px transparent canvas (Apple's macOS icon grid)
// and given a soft shadow. All 10 icon sizes and Contents.json are written.
import AppKit

var sourcePath = "Design/AppleIcon.png"
var threshold = 0.68
var arguments = Array(CommandLine.arguments.dropFirst())
while !arguments.isEmpty {
    let flag = arguments.removeFirst()
    guard let value = arguments.first else { fatalError("missing value for \(flag)") }
    arguments.removeFirst()
    switch flag {
    case "--source": sourcePath = value
    case "--threshold": threshold = Double(value) ?? threshold
    default: fatalError("unknown argument \(flag)")
    }
}
let root = URL(filePath: FileManager.default.currentDirectoryPath)
let output = root.appending(path: "App/Assets.xcassets/AppIcon.appiconset")

guard let data = try? Data(contentsOf: root.appending(path: sourcePath)), let source = NSBitmapImageRep(data: data) else {
    fatalError("cannot read \(sourcePath)")
}
let w = source.pixelsWide, h = source.pixelsHigh

// Luminance, y = 0 at the top (bitmap order).
var luminance = [Double](repeating: 0, count: w * h)
for y in 0..<h {
    for x in 0..<w {
        let c = source.colorAt(x: x, y: y)!.usingColorSpace(.deviceRGB)!
        luminance[y * w + x] = 0.299 * c.redComponent + 0.587 * c.greenComponent + 0.114 * c.blueComponent
    }
}
func sample(_ x: Double, _ y: Double) -> Double {
    let x0 = Int(x), y0 = Int(y)
    guard x0 >= 0, y0 >= 0, x0 + 1 < w, y0 + 1 < h else { return 1 }
    let fx = x - Double(x0), fy = y - Double(y0)
    let a = luminance[y0 * w + x0], b = luminance[y0 * w + x0 + 1]
    let c = luminance[(y0 + 1) * w + x0], d = luminance[(y0 + 1) * w + x0 + 1]
    return (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy
}

// Bounds of the dark frame and its center.
var minX = w, maxX = 0, minY = h, maxY = 0
for y in 0..<h {
    for x in 0..<w where luminance[y * w + x] < threshold - 0.13 {
        minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y)
    }
}
guard maxX > minX, maxY > minY else { fatalError("no dark frame found; try another --threshold") }
let cx = Double(minX + maxX) / 2, cy = Double(minY + maxY) / 2

// Outer edge along rays from the center: walk inward until the luminance crosses the threshold.
let steps = 3600
let quarter = steps / 4
var radius = [Double](repeating: 0, count: steps)
let farthest = Double(max(w, h))
for i in 0..<steps {
    let angle = Double(i) / Double(steps) * 2 * .pi
    let dx = cos(angle), dy = sin(angle)
    var r = farthest * 0.6, previous = sample(cx + r * dx, cy + r * dy)
    while r > 1 {
        let next = r - 0.25
        let value = sample(cx + next * dx, cy + next * dy)
        if previous >= threshold && value < threshold {
            r = next + 0.25 * (previous - threshold) / (previous - value)
            break
        }
        previous = value
        r = next
    }
    radius[i] = r
}
// The body is mirror-symmetric: average the four mirrored angles, smooth lightly
// and move the edge 1 px inward so no background fringe remains.
var symmetric = radius
for i in 0..<steps {
    let mirrors = [i, (2 * quarter - i + steps) % steps, (steps - i) % steps, (2 * quarter + i) % steps]
    symmetric[i] = mirrors.map { radius[$0] }.reduce(0, +) / 4
}
var edge = symmetric
for i in 0..<steps {
    edge[i] = (-3...3).map { symmetric[(i + $0 + steps) % steps] }.reduce(0, +) / 7 - 1
}

let outline = CGMutablePath()
for i in 0..<steps {
    let angle = Double(i) / Double(steps) * 2 * .pi
    let point = CGPoint(x: cx + edge[i] * cos(angle), y: Double(h) - (cy + edge[i] * sin(angle)))
    i == 0 ? outline.move(to: point) : outline.addLine(to: point)
}
outline.closeSubpath()

let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
func canvas(_ size: Int) -> CGContext {
    let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.interpolationQuality = .high
    return context
}

// The body cut out of the background.
let cut = canvas(max(w, h))
cut.addPath(outline)
cut.clip()
cut.draw(source.cgImage!, in: CGRect(x: 0, y: 0, width: w, height: h))
let body = cut.makeImage()!.cropping(to: CGRect(x: minX - 2, y: minY - 2, width: maxX - minX + 5, height: maxY - minY + 5))!

// The 1024 px master on Apple's grid.
let master = canvas(1024)
let scale = 824.0 / Double(max(body.width, body.height))
let size = CGSize(width: Double(body.width) * scale, height: Double(body.height) * scale)
master.setShadow(offset: CGSize(width: 0, height: -10), blur: 22, color: CGColor(gray: 0, alpha: 0.32))
master.draw(body, in: CGRect(origin: CGPoint(x: (1024 - size.width) / 2, y: (1024 - size.height) / 2), size: size))
let masterImage = master.makeImage()!

// All sizes and the asset catalog files.
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
var images: [[String: String]] = []
for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = points * scale
        let name = "icon_\(points)x\(points)\(scale == 2 ? "@2x" : "").png"
        let context = canvas(pixels)
        context.draw(masterImage, in: CGRect(x: 0, y: 0, width: pixels, height: pixels))
        let rep = NSBitmapImageRep(cgImage: context.makeImage()!)
        try rep.representation(using: .png, properties: [:])!.write(to: output.appending(path: name))
        images.append(["filename": name, "idiom": "mac", "scale": "\(scale)x", "size": "\(points)x\(points)"])
    }
}
func writeJSON(_ object: Any, to url: URL) throws {
    let data = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
    try data.write(to: url)
}
let info = ["author": "xcode", "version": 1] as [String: Any]
try writeJSON(["images": images, "info": info], to: output.appending(path: "Contents.json"))
try writeJSON(["info": info], to: output.deletingLastPathComponent().appending(path: "Contents.json"))
print("wrote \(images.count) icon sizes to \(output.path)")
