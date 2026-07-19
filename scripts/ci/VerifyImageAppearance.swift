import AppKit
import Foundation

guard CommandLine.arguments.count == 3 else {
    fputs("usage: VerifyImageAppearance <image.png> <dark|no-black-bars>\n", stderr)
    exit(2)
}

let path = CommandLine.arguments[1]
let mode = CommandLine.arguments[2]
guard
    let image = NSImage(contentsOfFile: path),
    let data = image.tiffRepresentation,
    let bitmap = NSBitmapImageRep(data: data)
else {
    fputs("could not decode image: \(path)\n", stderr)
    exit(3)
}

let xStep = max(1, bitmap.pixelsWide / 120)
let yStep = max(1, bitmap.pixelsHigh / 120)
var samples = 0
var brightnessTotal = 0.0
var blackSamples = 0

for y in stride(from: 0, to: bitmap.pixelsHigh, by: yStep) {
    for x in stride(from: 0, to: bitmap.pixelsWide, by: xStep) {
        guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else {
            continue
        }
        let brightness = Double(
            (color.redComponent + color.greenComponent + color.blueComponent) / 3
        )
        brightnessTotal += brightness
        if brightness < 0.02 { blackSamples += 1 }
        samples += 1
    }
}

guard samples > 0 else {
    fputs("image produced no readable pixel samples\n", stderr)
    exit(4)
}

let meanBrightness = brightnessTotal / Double(samples)
let blackFraction = Double(blackSamples) / Double(samples)
print(
    String(
        format: "%@ mode=%@ mean-brightness=%.3f black-fraction=%.3f",
        URL(fileURLWithPath: path).lastPathComponent,
        mode,
        meanBrightness,
        blackFraction
    )
)

switch mode {
case "dark":
    guard meanBrightness < 0.45 else {
        fputs("dark-mode evidence resolved to a light appearance\n", stderr)
        exit(5)
    }
case "no-black-bars":
    guard blackFraction < 0.18 else {
        fputs("image contains a large near-black unused canvas\n", stderr)
        exit(6)
    }
default:
    fputs("unknown appearance verification mode: \(mode)\n", stderr)
    exit(2)
}
