import AVFoundation
import AppKit
import Foundation

guard CommandLine.arguments.count == 3 else {
    fputs("usage: ExtractVideoFrames <video.mp4> <output-directory>\n", stderr)
    exit(2)
}

let videoURL = URL(fileURLWithPath: CommandLine.arguments[1])
let outputURL = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
try FileManager.default.createDirectory(
    at: outputURL,
    withIntermediateDirectories: true
)

let asset = AVURLAsset(url: videoURL)
guard let videoTrack = asset.tracks(withMediaType: .video).first else {
    fputs("video has no video track\n", stderr)
    exit(3)
}
let duration = CMTimeGetSeconds(videoTrack.timeRange.duration)
guard duration.isFinite, duration > 0 else {
    fputs("video has no readable duration\n", stderr)
    exit(3)
}

let generator = AVAssetImageGenerator(asset: asset)
generator.appliesPreferredTrackTransform = true
generator.requestedTimeToleranceBefore = .zero
generator.requestedTimeToleranceAfter = CMTime(seconds: 0.08, preferredTimescale: 600)

for (index, fraction) in [0.08, 0.22, 0.36, 0.50, 0.64, 0.78, 0.92].enumerated() {
    let requested = CMTime(seconds: duration * fraction, preferredTimescale: 600)
    var actual = CMTime.zero
    let image = try generator.copyCGImage(at: requested, actualTime: &actual)
    let bitmap = NSBitmapImageRep(cgImage: image)
    guard let data = bitmap.representation(using: .png, properties: [:]) else {
        throw CocoaError(.fileWriteUnknown)
    }
    let frameURL = outputURL.appendingPathComponent(
        String(format: "frame-%02d-%05.2fs.png", index + 1, CMTimeGetSeconds(actual))
    )
    try data.write(to: frameURL, options: .atomic)
    print(frameURL.path)
}

print(String(format: "duration=%.2fs frames=7", duration))
