//
//  EPUBExportSystem.swift
//  DiaplasionModule
//
//  Extracted from DiaplasionSystems.swift
//  System that generates accessible EPUB 3 output.
//

import AnigmaCore
import Foundation
import AnigmaPrimitives

// MARK: - EPUB Export System

/// System that generates accessible EPUB 3 output.
///
/// This system:
/// 1. Queries entities with ChunkedTextComponent and TransformRequestComponent
/// 2. Generates EPUB 3 structure (mimetype, container.xml, content.opf)
/// 3. Converts chunks to semantic XHTML
/// 4. Creates navigation documents (nav.xhtml, toc.ncx for compatibility)
/// 5. Packages as .epub file (ZIP with specific structure)
///
/// **Input**: Entity with `ChunkedTextComponent` and `TransformRequestComponent` targeting .epub
/// **Output**: Updates `AccessibleOutputComponent` with EPUB file reference
public struct EPUBExportSystem: System {
    public var name: String { "EPUBExport" }

    /// Output directory for generated EPUB files.
    /// If nil, uses system temp directory.
    public let outputDirectory: URL?

    /// EPUB metadata defaults
    public let defaultLanguage: String
    public let defaultPublisher: String

    public init(
        outputDirectory: URL? = nil,
        defaultLanguage: String = "en",
        defaultPublisher: String = "Diaplasion"
    ) {
        self.outputDirectory = outputDirectory
        self.defaultLanguage = defaultLanguage
        self.defaultPublisher = defaultPublisher
    }

    public func update(world: World) async {
        // Query for entities with ChunkedTextComponent and TransformRequestComponent
        let candidates = await world.query(ChunkedTextComponent.self, TransformRequestComponent.self)

        for (entity, chunked, request) in candidates {
            // Only process if EPUB is a target format
            guard request.targetFormats.contains(.epub) else { continue }

            // Skip if already has EPUB output
            if let existing = await world.getComponent(entity, AccessibleOutputComponent.self),
               existing.outputs[.epub] != nil {
                continue
            }

            // Get document source for metadata
            let source = await world.getComponent(entity, DocumentSourceComponent.self)

            do {
                let epubPath = try generateEPUB(
                    chunks: chunked.chunks,
                    sourceURI: source?.sourceURI,
                    requestId: request.requestId
                )

                // Update or create AccessibleOutputComponent
                var output = await world.getComponent(entity, AccessibleOutputComponent.self)
                    ?? AccessibleOutputComponent()

                let fileSize = try? FileManager.default.attributesOfItem(atPath: epubPath)[.size] as? Int64

                output.outputs[.epub] = OutputReference(
                    format: .epub,
                    uri: epubPath,
                    fileSize: fileSize,
                    createdAt: Date()
                )
                output.qaStatus = .pending

                await world.addComponent(entity, output)
                await Logger.shared.info("Generated EPUB: \(epubPath)", category: "Diaplasion")

            } catch {
                await Logger.shared.error("EPUB generation failed: \(error)", category: "Diaplasion")
            }
        }
    }

    // MARK: - EPUB Generation

    private func generateEPUB(chunks: [TextChunk], sourceURI: String?, requestId: String) throws -> String {
        // Create output directory
        let baseDir = outputDirectory ?? FileManager.default.temporaryDirectory
        let epubDir = baseDir.appendingPathComponent("epub_\(requestId)")
        let metaInfDir = epubDir.appendingPathComponent("META-INF")
        let oebpsDir = epubDir.appendingPathComponent("OEBPS")

        try FileManager.default.createDirectory(at: metaInfDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: oebpsDir, withIntermediateDirectories: true)

        // Extract title from first heading or use filename
        let title = extractTitle(from: chunks, sourceURI: sourceURI)
        let identifier = "urn:uuid:\(UUID().uuidString)"
        let date = ISO8601DateFormatter().string(from: Date())

        // 1. Write mimetype (must be first, uncompressed)
        let mimetypePath = epubDir.appendingPathComponent("mimetype")
        try "application/epub+zip".write(to: mimetypePath, atomically: true, encoding: .utf8)

        // 2. Write container.xml
        let containerXML = generateContainerXML()
        try containerXML.write(to: metaInfDir.appendingPathComponent("container.xml"), atomically: true, encoding: .utf8)

        // 3. Generate content files and collect manifest entries
        var manifestItems: [(id: String, href: String, mediaType: String)] = []
        var spineItems: [String] = []
        var navPoints: [(id: String, label: String, src: String)] = []

        // Split chunks into chapters (each heading starts a new chapter)
        let chapters = splitIntoChapters(chunks)

        for (index, chapter) in chapters.enumerated() {
            let chapterId = "chapter\(index + 1)"
            let chapterFile = "\(chapterId).xhtml"
            let chapterPath = oebpsDir.appendingPathComponent(chapterFile)

            let xhtml = generateChapterXHTML(chapter: chapter, chapterNumber: index + 1, title: title)
            try xhtml.write(to: chapterPath, atomically: true, encoding: .utf8)

            manifestItems.append((id: chapterId, href: chapterFile, mediaType: "application/xhtml+xml"))
            spineItems.append(chapterId)

            // Navigation point
            let chapterTitle = chapter.first { $0.chunkType == .heading }?.text ?? "Chapter \(index + 1)"
            navPoints.append((id: chapterId, label: chapterTitle, src: chapterFile))
        }

        // 4. Generate nav.xhtml (EPUB 3 navigation)
        let navXHTML = generateNavXHTML(navPoints: navPoints, title: title)
        try navXHTML.write(to: oebpsDir.appendingPathComponent("nav.xhtml"), atomically: true, encoding: .utf8)
        manifestItems.append((id: "nav", href: "nav.xhtml", mediaType: "application/xhtml+xml"))

        // 5. Generate toc.ncx (EPUB 2 compatibility)
        let tocNCX = generateTocNCX(navPoints: navPoints, title: title, identifier: identifier)
        try tocNCX.write(to: oebpsDir.appendingPathComponent("toc.ncx"), atomically: true, encoding: .utf8)
        manifestItems.append((id: "ncx", href: "toc.ncx", mediaType: "application/x-dtbncx+xml"))

        // 6. Generate content.opf (package document)
        let contentOPF = generateContentOPF(
            title: title,
            identifier: identifier,
            date: date,
            manifestItems: manifestItems,
            spineItems: spineItems
        )
        try contentOPF.write(to: oebpsDir.appendingPathComponent("content.opf"), atomically: true, encoding: .utf8)

        // 7. Package as ZIP with .epub extension
        let epubPath = baseDir.appendingPathComponent("\(requestId).epub").path
        try packageAsEPUB(directory: epubDir, outputPath: epubPath)

        // Cleanup temp directory
        try? FileManager.default.removeItem(at: epubDir)

        return epubPath
    }

    private func extractTitle(from chunks: [TextChunk], sourceURI: String?) -> String {
        // Try to find first heading
        if let heading = chunks.first(where: { $0.chunkType == .heading }) {
            return heading.text
        }

        // Fall back to filename
        if let uri = sourceURI {
            let filename = (uri as NSString).lastPathComponent
            let name = (filename as NSString).deletingPathExtension
            return name
        }

        return "Untitled Document"
    }

    private func splitIntoChapters(_ chunks: [TextChunk]) -> [[TextChunk]] {
        var chapters: [[TextChunk]] = []
        var currentChapter: [TextChunk] = []

        for chunk in chunks {
            if chunk.chunkType == .heading && !currentChapter.isEmpty {
                chapters.append(currentChapter)
                currentChapter = [chunk]
            } else {
                currentChapter.append(chunk)
            }
        }

        if !currentChapter.isEmpty {
            chapters.append(currentChapter)
        }

        // If no chapters were created, make one from all chunks
        if chapters.isEmpty && !chunks.isEmpty {
            chapters.append(chunks)
        }

        return chapters
    }

    // MARK: - XML Generation

    private func generateContainerXML() -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
            <rootfiles>
                <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
            </rootfiles>
        </container>
        """
    }

    private func generateContentOPF(
        title: String,
        identifier: String,
        date: String,
        manifestItems: [(id: String, href: String, mediaType: String)],
        spineItems: [String]
    ) -> String {
        let escapedTitle = escapeXML(title)

        let manifestEntries = manifestItems.map { item in
            let properties = item.id == "nav" ? " properties=\"nav\"" : ""
            return "        <item id=\"\(item.id)\" href=\"\(item.href)\" media-type=\"\(item.mediaType)\"\(properties)/>"
        }.joined(separator: "\n")

        let spineEntries = spineItems.map { id in
            "        <itemref idref=\"\(id)\"/>"
        }.joined(separator: "\n")

        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="uid">
            <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
                <dc:identifier id="uid">\(identifier)</dc:identifier>
                <dc:title>\(escapedTitle)</dc:title>
                <dc:language>\(defaultLanguage)</dc:language>
                <dc:publisher>\(escapeXML(defaultPublisher))</dc:publisher>
                <dc:date>\(date)</dc:date>
                <meta property="dcterms:modified">\(date)</meta>
            </metadata>
            <manifest>
        \(manifestEntries)
            </manifest>
            <spine toc="ncx">
        \(spineEntries)
            </spine>
        </package>
        """
    }

    private func generateNavXHTML(navPoints: [(id: String, label: String, src: String)], title: String) -> String {
        let escapedTitle = escapeXML(title)

        let navItems = navPoints.map { point in
            "                <li><a href=\"\(point.src)\">\(escapeXML(point.label))</a></li>"
        }.joined(separator: "\n")

        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE html>
        <html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops" xml:lang="\(defaultLanguage)">
        <head>
            <meta charset="UTF-8"/>
            <title>\(escapedTitle) - Table of Contents</title>
        </head>
        <body>
            <nav epub:type="toc" id="toc">
                <h1>Table of Contents</h1>
                <ol>
        \(navItems)
                </ol>
            </nav>
        </body>
        </html>
        """
    }

    private func generateTocNCX(navPoints: [(id: String, label: String, src: String)], title: String, identifier: String) -> String {
        let escapedTitle = escapeXML(title)

        let navPointsXML = navPoints.enumerated().map { index, point in
            """
                    <navPoint id="navpoint-\(index + 1)" playOrder="\(index + 1)">
                        <navLabel><text>\(escapeXML(point.label))</text></navLabel>
                        <content src="\(point.src)"/>
                    </navPoint>
            """
        }.joined(separator: "\n")

        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1">
            <head>
                <meta name="dtb:uid" content="\(identifier)"/>
                <meta name="dtb:depth" content="1"/>
                <meta name="dtb:totalPageCount" content="0"/>
                <meta name="dtb:maxPageNumber" content="0"/>
            </head>
            <docTitle><text>\(escapedTitle)</text></docTitle>
            <navMap>
        \(navPointsXML)
            </navMap>
        </ncx>
        """
    }

    private func generateChapterXHTML(chapter: [TextChunk], chapterNumber: Int, title: String) -> String {
        let escapedTitle = escapeXML(title)

        var bodyContent = ""

        for chunk in chapter {
            let escapedText = escapeXML(chunk.text)

            switch chunk.chunkType {
            case .heading:
                bodyContent += "    <h1>\(escapedText)</h1>\n"
            case .paragraph:
                bodyContent += "    <p>\(escapedText)</p>\n"
            case .listItem:
                bodyContent += "    <p class=\"list-item\">• \(escapedText)</p>\n"
            case .quote:
                bodyContent += "    <blockquote>\(escapedText)</blockquote>\n"
            case .caption:
                bodyContent += "    <p class=\"caption\">\(escapedText)</p>\n"
            case .footnote:
                bodyContent += "    <aside epub:type=\"footnote\">\(escapedText)</aside>\n"
            case .code:
                bodyContent += "    <pre><code>\(escapedText)</code></pre>\n"
            case .table, .figure:
                bodyContent += "    <div class=\"\(chunk.chunkType.rawValue)\">\(escapedText)</div>\n"
            }
        }

        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE html>
        <html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops" xml:lang="\(defaultLanguage)">
        <head>
            <meta charset="UTF-8"/>
            <title>\(escapedTitle) - Chapter \(chapterNumber)</title>
            <style type="text/css">
                body { font-family: serif; line-height: 1.6; margin: 1em; }
                h1 { font-size: 1.5em; margin-top: 1em; }
                p { margin: 0.5em 0; text-indent: 1em; }
                p.list-item { text-indent: 0; margin-left: 2em; }
                blockquote { margin: 1em 2em; font-style: italic; }
                .caption { font-size: 0.9em; text-align: center; }
                pre { background: #f4f4f4; padding: 1em; overflow-x: auto; }
            </style>
        </head>
        <body>
        \(bodyContent)
        </body>
        </html>
        """
    }

    private func escapeXML(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }

    // MARK: - ZIP Packaging

    private func packageAsEPUB(directory: URL, outputPath: String) throws {
        // Use /usr/bin/zip for packaging (available on macOS)
        // The mimetype must be stored uncompressed as the first file
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.currentDirectoryURL = directory

        // First add mimetype uncompressed
        process.arguments = ["-X0", outputPath, "mimetype"]
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw DiaplasionError.epubPackagingFailed(reason: "Failed to add mimetype")
        }

        // Then add everything else compressed
        let addProcess = Process()
        addProcess.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        addProcess.currentDirectoryURL = directory
        addProcess.arguments = ["-Xr9", outputPath, "META-INF", "OEBPS"]
        try addProcess.run()
        addProcess.waitUntilExit()

        guard addProcess.terminationStatus == 0 else {
            throw DiaplasionError.epubPackagingFailed(reason: "Failed to add content")
        }
    }
}
