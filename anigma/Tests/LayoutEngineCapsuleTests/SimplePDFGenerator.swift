import Foundation

enum SimplePDFGenerator {
    
    static func generateSimpleText() -> Data {
        var pdfData = Data()
        
        // PDF header
        let header = "%PDF-1.4\n"
        pdfData.append(header.data(using: .utf8)!)
        
        // PDF binary comment
        let binaryComment = "%\u{E2}\u{E3}\u{CF}\u{D3}\n"
        pdfData.append(binaryComment.data(using: .utf8)!)
        
        // Object 1: Catalog
        let catalogObj = """
        1 0 obj
        << /Type /Catalog /Pages 2 0 R >>
        endobj
        """
        pdfData.append((catalogObj + "\n").data(using: .utf8)!)
        
        // Object 2: Pages
        let pagesObj = """
        2 0 obj
        << /Type /Pages /Kids [3 0 R] /Count 1 >>
        endobj
        """
        pdfData.append((pagesObj + "\n").data(using: .utf8)!)
        
        // Create content stream
        let contentStream = """
        BT
        /F1 24 Tf
        100 700 Td
        (Hello World) Tj
        ET
        """
        let streamLength = contentStream.count
        
        // Object 3: Page
        let pageObj = """
        3 0 obj
        << /Type /Page /Parent 2 0 R /Resources << /Font << /F1 4 0 R >> >> /MediaBox [0 0 612 792] /Contents 5 0 R >>
        endobj
        """
        pdfData.append((pageObj + "\n").data(using: .utf8)!)
        
        // Object 4: Font
        let fontObj = """
        4 0 obj
        << /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>
        endobj
        """
        pdfData.append((fontObj + "\n").data(using: .utf8)!)
        
        // Object 5: Content stream
        let contentObj = """
        5 0 obj
        << /Length \(streamLength) >>
        stream
        \(contentStream)
        endstream
        endobj
        """
        pdfData.append((contentObj + "\n").data(using: .utf8)!)
        
        // Cross-reference table
        let xrefOffset = pdfData.count
        let xrefTable = """
        xref
        0 6
        0000000000 65535 f
        0000000009 00000 n
        0000000058 00000 n
        0000000115 00000 n
        0000000214 00000 n
        0000000287 00000 n
        """
        pdfData.append(xrefTable.data(using: .utf8)!)
        
        // Trailer
        let trailer = """
        trailer
        << /Size 6 /Root 1 0 R >>
        startxref
        \(xrefOffset)
        %%EOF
        """
        pdfData.append((trailer + "\n").data(using: .utf8)!)
        
        return pdfData
    }
    
    static func generateTable() -> Data {
        var pdfData = Data()
        
        let header = "%PDF-1.4\n"
        pdfData.append(header.data(using: .utf8)!)
        
        let binaryComment = "%\u{E2}\u{E3}\u{CF}\u{D3}\n"
        pdfData.append(binaryComment.data(using: .utf8)!)
        
        // Catalog
        pdfData.append("""
        1 0 obj
        << /Type /Catalog /Pages 2 0 R >>
        endobj
        """.data(using: .utf8)!)
        
        // Pages
        pdfData.append("""
        2 0 obj
        << /Type /Pages /Kids [3 0 R] /Count 1 >>
        endobj
        """.data(using: .utf8)!)
        
        // Content stream with table drawing commands
        let contentStream = """
        BT
        /F1 10 Tf
        50 750 Td
        (Sample Table) Tj
        ET
        q
        1 w
        50 730 m
        300 730 l
        300 600 l
        50 600 l
        50 730 l
        s
        Q
        BT
        55 710 Td
        (Header 1) Tj
        120 710 Td
        (Header 2) Tj
        185 710 Td
        (Header 3) Tj
        ET
        """
        let streamLength = contentStream.count
        
        // Page
        pdfData.append("""
        3 0 obj
        << /Type /Page /Parent 2 0 R /Resources << /Font << /F1 4 0 R >> >> /MediaBox [0 0 612 792] /Contents 5 0 R >>
        endobj
        """.data(using: .utf8)!)
        
        // Font
        pdfData.append("""
        4 0 obj
        << /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>
        endobj
        """.data(using: .utf8)!)
        
        // Content stream object
        pdfData.append("""
        5 0 obj
        << /Length \(streamLength) >>
        stream
        \(contentStream)
        endstream
        endobj
        """.data(using: .utf8)!)
        
        // Xref
        let xrefOffset = pdfData.count
        let xrefTable = """
        xref
        0 6
        0000000000 65535 f
        0000000009 00000 n
        0000000058 00000 n
        0000000115 00000 n
        0000000214 00000 n
        0000000287 00000 n
        """
        pdfData.append(xrefTable.data(using: .utf8)!)
        
        // Trailer
        let trailer = """
        trailer
        << /Size 6 /Root 1 0 R >>
        startxref
        \(xrefOffset)
        %%EOF
        """
        pdfData.append((trailer + "\n").data(using: .utf8)!)
        
        return pdfData
    }
    
    static func generateInferredTable() -> Data {
        var pdfData = Data()
        
        let header = "%PDF-1.4\n"
        pdfData.append(header.data(using: .utf8)!)
        
        let binaryComment = "%\u{E2}\u{E3}\u{CF}\u{D3}\n"
        pdfData.append(binaryComment.data(using: .utf8)!)
        
        // Catalog
        pdfData.append("""
        1 0 obj
        << /Type /Catalog /Pages 2 0 R >>
        endobj
        """.data(using: .utf8)!)
        
        // Pages
        pdfData.append("""
        2 0 obj
        << /Type /Pages /Kids [3 0 R] /Count 1 >>
        endobj
        """.data(using: .utf8)!)
        
        // Content stream with text arranged like a table (no borders)
        let contentStream = """
        BT
        /F1 10 Tf
        100 750 Td
        (Product    Price    Quantity) Tj
        0 -15 Td
        (Apple      $1.99    10) Tj
        0 -15 Td
        (Banana     $0.99    15) Tj
        0 -15 Td
        (Orange     $2.49    8) Tj
        ET
        """
        let streamLength = contentStream.count
        
        // Page
        pdfData.append("""
        3 0 obj
        << /Type /Page /Parent 2 0 R /Resources << /Font << /F1 4 0 R >> >> /MediaBox [0 0 612 792] /Contents 5 0 R >>
        endobj
        """.data(using: .utf8)!)
        
        // Font
        pdfData.append("""
        4 0 obj
        << /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>
        endobj
        """.data(using: .utf8)!)
        
        // Content stream object
        pdfData.append("""
        5 0 obj
        << /Length \(streamLength) >>
        stream
        \(contentStream)
        endstream
        endobj
        """.data(using: .utf8)!)
        
        // Xref
        let xrefOffset = pdfData.count
        let xrefTable = """
        xref
        0 6
        0000000000 65535 f
        0000000009 00000 n
        0000000058 00000 n
        0000000115 00000 n
        0000000214 00000 n
        0000000287 00000 n
        """
        pdfData.append(xrefTable.data(using: .utf8)!)
        
        // Trailer
        let trailer = """
        trailer
        << /Size 6 /Root 1 0 R >>
        startxref
        \(xrefOffset)
        %%EOF
        """
        pdfData.append((trailer + "\n").data(using: .utf8)!)
        
        return pdfData
    }
    
    static func generateMergedCellsTable() -> Data {
        var pdfData = Data()
        
        let header = "%PDF-1.4\n"
        pdfData.append(header.data(using: .utf8)!)
        
        let binaryComment = "%\u{E2}\u{E3}\u{CF}\u{D3}\n"
        pdfData.append(binaryComment.data(using: .utf8)!)
        
        // Catalog
        pdfData.append("""
        1 0 obj
        << /Type /Catalog /Pages 2 0 R >>
        endobj
        """.data(using: .utf8)!)
        
        // Pages
        pdfData.append("""
        2 0 obj
        << /Type /Pages /Kids [3 0 R] /Count 1 >>
        endobj
        """.data(using: .utf8)!)
        
        // Content stream with merged cells (draw borders and text)
        let contentStream = """
        BT
        /F1 10 Tf
        50 750 Td
        (Merged Table) Tj
        ET
        q
        1 w
        50 730 m 250 730 l s
        50 680 m 250 680 l s
        50 630 m 250 630 l s
        50 730 m 50 630 l s
        100 730 m 100 630 l s
        150 730 m 150 630 l s
        200 730 m 200 630 l s
        250 730 m 250 630 l s
        Q
        BT
        55 710 Td
        (Header (merged)) Tj
        155 710 Td
        (Col A) Tj
        205 710 Td
        (Col B) Tj
        55 660 Td
        (Row 1) Tj
        105 660 Td
        (A1) Tj
        155 660 Td
        (B1) Tj
        205 660 Td
        (C1) Tj
        ET
        """
        let streamLength = contentStream.count
        
        // Page
        pdfData.append("""
        3 0 obj
        << /Type /Page /Parent 2 0 R /Resources << /Font << /F1 4 0 R >> >> /MediaBox [0 0 612 792] /Contents 5 0 R >>
        endobj
        """.data(using: .utf8)!)
        
        // Font
        pdfData.append("""
        4 0 obj
        << /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>
        endobj
        """.data(using: .utf8)!)
        
        // Content stream object
        pdfData.append("""
        5 0 obj
        << /Length \(streamLength) >>
        stream
        \(contentStream)
        endstream
        endobj
        """.data(using: .utf8)!)
        
        // Xref
        let xrefOffset = pdfData.count
        let xrefTable = """
        xref
        0 6
        0000000000 65535 f
        0000000009 00000 n
        0000000058 00000 n
        0000000115 00000 n
        0000000214 00000 n
        0000000287 00000 n
        """
        pdfData.append(xrefTable.data(using: .utf8)!)
        
        // Trailer
        let trailer = """
        trailer
        << /Size 6 /Root 1 0 R >>
        startxref
        \(xrefOffset)
        %%EOF
        """
        pdfData.append((trailer + "\n").data(using: .utf8)!)
        
        return pdfData
    }
    
    static func generateImagePDF() -> Data {
        var pdfData = Data()
        
        let header = "%PDF-1.4\n"
        pdfData.append(header.data(using: .utf8)!)
        
        let binaryComment = "%\u{E2}\u{E3}\u{CF}\u{D3}\n"
        pdfData.append(binaryComment.data(using: .utf8)!)
        
        // Catalog
        pdfData.append("""
        1 0 obj
        << /Type /Catalog /Pages 2 0 R >>
        endobj
        """.data(using: .utf8)!)
        
        // Pages
        pdfData.append("""
        2 0 obj
        << /Type /Pages /Kids [3 0 R] /Count 1 >>
        endobj
        """.data(using: .utf8)!)
        
        // Content stream with rectangle (placeholder for image)
        let contentStream = """
        q
        1 w
        0 0 1 RG
        100 600 200 150 re
        s
        Q
        BT
        /F1 12 Tf
        110 620 Td
        (Image Placeholder) Tj
        ET
        """
        let streamLength = contentStream.count
        
        // Page
        pdfData.append("""
        3 0 obj
        << /Type /Page /Parent 2 0 R /Resources << /Font << /F1 4 0 R >> >> /MediaBox [0 0 612 792] /Contents 5 0 R >>
        endobj
        """.data(using: .utf8)!)
        
        // Font
        pdfData.append("""
        4 0 obj
        << /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>
        endobj
        """.data(using: .utf8)!)
        
        // Content stream object
        pdfData.append("""
        5 0 obj
        << /Length \(streamLength) >>
        stream
        \(contentStream)
        endstream
        endobj
        """.data(using: .utf8)!)
        
        // Xref
        let xrefOffset = pdfData.count
        let xrefTable = """
        xref
        0 6
        0000000000 65535 f
        0000000009 00000 n
        0000000058 00000 n
        0000000115 00000 n
        0000000214 00000 n
        0000000287 00000 n
        """
        pdfData.append(xrefTable.data(using: .utf8)!)
        
        // Trailer
        let trailer = """
        trailer
        << /Size 6 /Root 1 0 R >>
        startxref
        \(xrefOffset)
        %%EOF
        """
        pdfData.append((trailer + "\n").data(using: .utf8)!)
        
        return pdfData
    }
    
    static func generateMixedContentPDF() -> Data {
        var pdfData = Data()
        
        let header = "%PDF-1.4\n"
        pdfData.append(header.data(using: .utf8)!)
        
        let binaryComment = "%\u{E2}\u{E3}\u{CF}\u{D3}\n"
        pdfData.append(binaryComment.data(using: .utf8)!)
        
        // Catalog
        pdfData.append("""
        1 0 obj
        << /Type /Catalog /Pages 2 0 R >>
        endobj
        """.data(using: .utf8)!)
        
        // Pages
        pdfData.append("""
        2 0 obj
        << /Type /Pages /Kids [3 0 R] /Count 1 >>
        endobj
        """.data(using: .utf8)!)
        
        // Content stream with text, table, and image
        let contentStream = """
        BT
        /F1 16 Tf
        100 750 Td
        (Mixed Content Document) Tj
        ET
        BT
        /F1 10 Tf
        100 720 Td
        (This PDF contains text, a simple table, and an image placeholder.) Tj
        ET
        q
        1 w
        100 680 m 400 680 l 400 620 l 100 620 l 100 680 l s
        Q
        BT
        105 660 Td
        (Header 1) Tj
        205 660 Td
        (Header 2) Tj
        305 660 Td
        (Header 3) Tj
        ET
        q
        1 w
        0 0 1 RG
        100 550 150 100 re
        s
        Q
        BT
        110 570 Td
        (Image) Tj
        ET
        """
        let streamLength = contentStream.count
        
        // Page
        pdfData.append("""
        3 0 obj
        << /Type /Page /Parent 2 0 R /Resources << /Font << /F1 4 0 R >> >> /MediaBox [0 0 612 792] /Contents 5 0 R >>
        endobj
        """.data(using: .utf8)!)
        
        // Font
        pdfData.append("""
        4 0 obj
        << /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>
        endobj
        """.data(using: .utf8)!)
        
        // Content stream object
        pdfData.append("""
        5 0 obj
        << /Length \(streamLength) >>
        stream
        \(contentStream)
        endstream
        endobj
        """.data(using: .utf8)!)
        
        // Xref
        let xrefOffset = pdfData.count
        let xrefTable = """
        xref
        0 6
        0000000000 65535 f
        0000000009 00000 n
        0000000058 00000 n
        0000000115 00000 n
        0000000214 00000 n
        0000000287 00000 n
        """
        pdfData.append(xrefTable.data(using: .utf8)!)
        
        // Trailer
        let trailer = """
        trailer
        << /Size 6 /Root 1 0 R >>
        startxref
        \(xrefOffset)
        %%EOF
        """
        pdfData.append((trailer + "\n").data(using: .utf8)!)
        
        return pdfData
    }
    
    static func generateEmpty() -> Data {
        var pdfData = Data()
        
        let header = "%PDF-1.4\n"
        pdfData.append(header.data(using: .utf8)!)
        
        let binaryComment = "%\u{E2}\u{E3}\u{CF}\u{D3}\n"
        pdfData.append(binaryComment.data(using: .utf8)!)
        
        // Catalog
        pdfData.append("""
        1 0 obj
        << /Type /Catalog /Pages 2 0 R >>
        endobj
        """.data(using: .utf8)!)
        
        // Pages with zero count (empty page list?)
        pdfData.append("""
        2 0 obj
        << /Type /Pages /Kids [] /Count 0 >>
        endobj
        """.data(using: .utf8)!)
        
        // Xref
        let xrefOffset = pdfData.count
        let xrefTable = """
        xref
        0 3
        0000000000 65535 f
        0000000009 00000 n
        0000000058 00000 n
        """
        pdfData.append(xrefTable.data(using: .utf8)!)
        
        // Trailer
        let trailer = """
        trailer
        << /Size 3 /Root 1 0 R >>
        startxref
        \(xrefOffset)
        %%EOF
        """
        pdfData.append((trailer + "\n").data(using: .utf8)!)
        
        return pdfData
    }
}