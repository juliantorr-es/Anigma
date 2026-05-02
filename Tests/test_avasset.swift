import AVFoundation
import CoreMedia

let url = URL(fileURLWithPath: "anigma/Tests/MediaCoreTests/Fixtures/test.mp4")
let asset = AVAsset(url: url)
let track = asset.tracks(withMediaType: .video).first!
let reader = try! AVAssetReader(asset: asset)
let output = AVAssetReaderTrackOutput(track: track, outputSettings: nil)
reader.add(output)
reader.startReading()
let sb = output.copyNextSampleBuffer()!
print(sb)
