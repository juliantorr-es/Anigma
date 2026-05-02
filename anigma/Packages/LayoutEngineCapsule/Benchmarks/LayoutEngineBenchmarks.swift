import BenchmarkHarness
import Foundation
import CoreGraphics
import CoreText
import LayoutEngineCapsule

public final class LayoutEngineAnalysisBenchmark: BenchmarkCase {
    public let name = "layout_engine_analysis"
    public let iterations: Int
    private let sampleData: Data
    private let config: LayoutEngineConfig

    public init(iterations: Int = 10) throws {
        self.iterations = iterations
        self.sampleData = try loadSamplePDF()
        self.config = LayoutEngineConfig(determinismTier: 1, flags: LayoutEngineConfig.detectTables)
    }

    public func run() async throws {
        let capsule = try LayoutEngineCapsule(config: config)
        let layouts = try capsule.analyzePDF(sampleData)
        BenchmarkBlackhole.consume(layouts.count)
    }

    public var metricHints: BenchmarkMetricHints {
        BenchmarkMetricHints(bytesCopiedPerIteration: Int64(sampleData.count))
    }
}

private func loadSamplePDF() throws -> Data {
    if let sampleURL = findSamplePDFURL() {
        return try Data(contentsOf: sampleURL)
    }

    return try makeFallbackPDFData()
}

private func findSamplePDFURL() -> URL? {
    let fileManager = FileManager.default
    let candidatePaths = [
        ".build-refactor-check/checkouts/GRDB.swift/Documentation/DemoApps/GRDBAsyncDemo/GRDBAsyncDemo/Resources/Assets.xcassets/LaunchIcon.imageset/LaunchIcon.pdf",
        ".build-check/checkouts/GRDB.swift/Documentation/DemoApps/GRDBAsyncDemo/GRDBAsyncDemo/Resources/Assets.xcassets/LaunchIcon.imageset/LaunchIcon.pdf",
        ".build-contextpin/checkouts/GRDB.swift/Documentation/DemoApps/GRDBAsyncDemo/GRDBAsyncDemo/Resources/Assets.xcassets/LaunchIcon.imageset/LaunchIcon.pdf"
    ]

    var directory = URL(fileURLWithPath: fileManager.currentDirectoryPath)
    for _ in 0..<6 {
        for relativePath in candidatePaths {
            let candidateURL = directory.appendingPathComponent(relativePath)
            if fileManager.fileExists(atPath: candidateURL.path) {
                return candidateURL
            }
        }

        let parent = directory.deletingLastPathComponent()
        if parent.path == directory.path {
            break
        }
        directory = parent
    }

    return nil
}

private enum SamplePDFError: Error {
    case unavailable
}

private func makeFallbackPDFData() throws -> Data {
    let data = NSMutableData()
    guard let consumer = CGDataConsumer(data: data as CFMutableData) else {
        throw SamplePDFError.unavailable
    }

    var mediaBox = CGRect(x: 0, y: 0, width: 612, height: 792)
    guard let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
        throw SamplePDFError.unavailable
    }

    let metadata = [
        "Title" as CFString: "Anigma benchmark PDF" as CFString,
        "Author" as CFString: "Anigma" as CFString,
        "CreationDate" as CFString: CFDateCreate(nil, 0)!,
        "ModDate" as CFString: CFDateCreate(nil, 0)!
    ] as CFDictionary

    context.beginPDFPage(metadata)
    context.saveGState()

    let text = "Anigma benchmark PDF"
    let textRect = CGRect(x: 72, y: 72, width: mediaBox.width - 144, height: mediaBox.height - 144)
    context.translateBy(x: 0, y: mediaBox.height)
    context.scaleBy(x: 1, y: -1)

    let font = CTFontCreateWithName("Helvetica" as CFString, 12, nil)
    let attributes: [CFString: Any] = [
        kCTFontAttributeName: font,
        kCTForegroundColorAttributeName: CGColor(gray: 0, alpha: 1)
    ]
    guard let attributedString = CFAttributedStringCreate(kCFAllocatorDefault, text as CFString, attributes as CFDictionary) else {
        throw SamplePDFError.unavailable
    }
    let framesetter = CTFramesetterCreateWithAttributedString(attributedString)
    let path = CGMutablePath()
    path.addRect(textRect)
    let frame = CTFramesetterCreateFrame(
        framesetter,
        CFRange(location: 0, length: CFAttributedStringGetLength(attributedString)),
        path,
        nil
    )
    CTFrameDraw(frame, context)

    context.restoreGState()
    context.endPDFPage()
    context.closePDF()
    return data as Data
}
