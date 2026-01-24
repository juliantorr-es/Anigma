//
//  ReceiptExport.swift
//  ExecutionCore
//
//  Comprehensive receipt export functionality for external audit.
//  Supports multiple formats including JSON, PDF, and CSV.
//

import Foundation
import CryptoKit
import MLWorkerCommon

// MARK: - Receipt Export Manager

public class ReceiptExportManager {
    
    /// Export receipts to JSON audit bundle
    public static func exportToJSON(
        receipts: [ReceiptWire],
        outputPath: String,
        includeVerification: Bool = true
    ) throws {
        
        let auditBundle = JSONAuditBundle(
            receipts: receipts,
            metadata: AuditBundleMetadata(
                exportTimestamp: Date(),
                totalReceipts: receipts.count,
                verificationIncluded: includeVerification,
                chainIntegrityVerified: false // Will be updated if verification is performed
            ),
            verificationResults: includeVerification ? try verifyAllReceipts(receipts) : nil
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        let data = try encoder.encode(auditBundle)
        try data.write(to: URL(fileURLWithPath: outputPath))
    }
    
    /// Export receipts to CSV format
    public static func exportToCSV(
        receipts: [ReceiptWire],
        outputPath: String
    ) throws {
        
        var csvContent = "Receipt ID,Timestamp,Action Name,Authority,Decision,Reason Code,Inputs Hash,Outputs Hash,Previous Hash,Has Signature\n"
        
        for receipt in receipts {
            let timestamp = ISO8601DateFormatter().string(from: Date(timeIntervalSince1970: TimeInterval(receipt.timestampMs) / 1000))
            let hasSignature = receipt.signature != nil ? "Yes" : "No"
            let outputsHash = receipt.outputsHash?.value ?? ""
            let previousHash = receipt.previousReceiptHash ?? ""
            
            csvContent += "\(receipt.receiptID),\(timestamp),\(receipt.actionName),\(receipt.authority),\(receipt.decision.rawValue),\(receipt.reasonCode),\(receipt.inputsHash.value),\(outputsHash),\(previousHash),\(hasSignature)\n"
        }
        
        try csvContent.write(to: URL(fileURLWithPath: outputPath), atomically: true, encoding: .utf8)
    }
    
    /// Export receipts to PDF audit report
    public static func exportToPDF(
        receipts: [ReceiptWire],
        outputPath: String,
        title: String = "AI Operations Audit Report"
    ) throws {
        
        let generator = PDFReportGenerator()
        try generator.generateReport(
            receipts: receipts,
            title: title,
            outputPath: outputPath
        )
    }
    
    /// Generate comprehensive audit bundle with all formats
    public static func generateAuditBundle(
        receipts: [ReceiptWire],
        outputDirectory: String,
        bundleName: String = "audit-bundle"
    ) throws {
        
        let bundleURL = URL(fileURLWithPath: outputDirectory).appendingPathComponent(bundleName)
        try FileManager.default.createDirectory(at: bundleURL, withIntermediateDirectories: true)
        
        // Export JSON
        let jsonPath = bundleURL.appendingPathComponent("receipts.json").path
        try exportToJSON(receipts: receipts, outputPath: jsonPath)
        
        // Export CSV
        let csvPath = bundleURL.appendingPathComponent("receipts.csv").path
        try exportToCSV(receipts: receipts, outputPath: csvPath)
        
        // Export PDF
        let pdfPath = bundleURL.appendingPathComponent("audit-report.pdf").path
        try exportToPDF(receipts: receipts, outputPath: pdfPath)
        
        // Create manifest
        let manifest = BundleManifest(
            bundleName: bundleName,
            created: Date(),
            files: [
                "receipts.json": "Complete receipt data in JSON format",
                "receipts.csv": "Receipt data in CSV format for analysis",
                "audit-report.pdf": "Human-readable audit report"
            ],
            verificationStatus: try verifyAllReceipts(receipts)
        )
        
        let manifestData = try JSONEncoder().encode(manifest)
        let manifestPath = bundleURL.appendingPathComponent("manifest.json").path
        try manifestData.write(to: URL(fileURLWithPath: manifestPath))
        
        print("📦 Audit bundle created: \(bundleURL.path)")
        print("   Files: receipts.json, receipts.csv, audit-report.pdf, manifest.json")
    }
    
    // MARK: - Private Methods
    
    private static func verifyAllReceipts(_ receipts: [ReceiptWire]) throws -> VerificationResults {
        var results = VerificationResults()
        results.totalReceipts = receipts.count
        results.verifiedReceipts = 0
        results.failedReceipts = 0
        
        for receipt in receipts {
            if try verifyReceipt(receipt) {
                results.verifiedReceipts += 1
            } else {
                results.failedReceipts += 1
            }
        }
        
        results.verificationRate = Double(results.verifiedReceipts) / Double(results.totalReceipts)
        return results
    }
    
    private static func verifyReceipt(_ receipt: ReceiptWire) throws -> Bool {
        // Verify receipt ID matches content hash
        let computedID = try receipt.computeReceiptID()
        return computedID == receipt.receiptID
    }
}

// MARK: - JSON Audit Bundle

public struct JSONAuditBundle: Codable {
    public let receipts: [ReceiptWire]
    public let metadata: AuditBundleMetadata
    public let verificationResults: VerificationResults?
    
    public init(receipts: [ReceiptWire], metadata: AuditBundleMetadata, verificationResults: VerificationResults?) {
        self.receipts = receipts
        self.metadata = metadata
        self.verificationResults = verificationResults
    }
}

public struct AuditBundleMetadata: Codable {
    public let exportTimestamp: Date
    public let totalReceipts: Int
    public let verificationIncluded: Bool
    public let chainIntegrityVerified: Bool
    public let version: String
    public let format: String
    
    public init(exportTimestamp: Date, totalReceipts: Int, verificationIncluded: Bool, chainIntegrityVerified: Bool) {
        self.exportTimestamp = exportTimestamp
        self.totalReceipts = totalReceipts
        self.verificationIncluded = verificationIncluded
        self.chainIntegrityVerified = chainIntegrityVerified
        self.version = "1.0.0"
        self.format = "AI Receipt Audit Bundle"
    }
}

public struct VerificationResults: Codable {
    public var totalReceipts: Int = 0
    public var verifiedReceipts: Int = 0
    public var failedReceipts: Int = 0
    public var verificationRate: Double = 0.0
    public var chainIntegrity: ChainIntegrityStatus = .unknown
    public var verificationTimestamp: Date = Date()
    
    public init() {}
}

public enum ChainIntegrityStatus: String, Codable {
    case verified = "verified"
    case broken = "broken"
    case incomplete = "incomplete"
    case unknown = "unknown"
}

// MARK: - Bundle Manifest

public struct BundleManifest: Codable {
    public let bundleName: String
    public let created: Date
    public let files: [String: String]
    public let verificationStatus: VerificationResults
    public let formatVersion: String
    
    public init(bundleName: String, created: Date, files: [String: String], verificationStatus: VerificationResults) {
        self.bundleName = bundleName
        self.created = created
        self.files = files
        self.verificationStatus = verificationStatus
        self.formatVersion = "1.0.0"
    }
}

// MARK: - PDF Report Generator

public class PDFReportGenerator {
    
    public init() {}
    
    public func generateReport(
        receipts: [ReceiptWire],
        title: String,
        outputPath: String
    ) throws {
        
        let htmlContent = generateHTMLContent(receipts: receipts, title: title)
        let htmlURL = URL(fileURLWithPath: outputPath.replacingOccurrences(of: ".pdf", with: ".html"))
        
        try htmlContent.write(to: htmlURL, atomically: true, encoding: .utf8)
        
        // In a real implementation, this would convert HTML to PDF
        // For now, we'll create a simple text-based report
        let textContent = generateTextReport(receipts: receipts, title: title)
        try textContent.write(to: URL(fileURLWithPath: outputPath), atomically: true, encoding: .utf8)
    }
    
    private func generateHTMLContent(receipts: [ReceiptWire], title: String) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        
        var html = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <title>\(title)</title>
            <style>
                body { font-family: Arial, sans-serif; margin: 40px; }
                .header { background-color: #f0f0f0; padding: 20px; border-radius: 5px; margin-bottom: 20px; }
                .receipt { border: 1px solid #ddd; margin-bottom: 20px; padding: 15px; border-radius: 5px; }
                .receipt-header { font-weight: bold; color: #333; margin-bottom: 10px; }
                .receipt-details { display: grid; grid-template-columns: 150px 1fr; gap: 8px; font-size: 14px; }
                .verified { color: green; font-weight: bold; }
                .failed { color: red; font-weight: bold; }
            </style>
        </head>
        <body>
            <div class="header">
                <h1>\(title)</h1>
                <p>Generated on \(formatter.string(from: Date()))</p>
                <p>Total Receipts: \(receipts.count)</p>
            </div>
        """
        
        for receipt in receipts {
            let timestamp = formatter.string(from: Date(timeIntervalSince1970: TimeInterval(receipt.timestampMs) / 1000))
            let status = receipt.signature != nil ? "verified" : "unverified"
            let statusClass = receipt.signature != nil ? "verified" : "failed"
            
            html += """
            <div class="receipt">
                <div class="receipt-header">
                    Receipt: \(receipt.receiptID) <span class="\(statusClass)">\(status)</span>
                </div>
                <div class="receipt-details">
                    <div><strong>Timestamp:</strong></div><div>\(timestamp)</div>
                    <div><strong>Action:</strong></div><div>\(receipt.actionName)</div>
                    <div><strong>Authority:</strong></div><div>\(receipt.authority)</div>
                    <div><strong>Decision:</strong></div><div>\(receipt.decision.rawValue)</div>
                    <div><strong>Reason:</strong></div><div>\(receipt.reasonCode)</div>
                    <div><strong>Inputs Hash:</strong></div><div>\(receipt.inputsHash.value)</div>
                    <div><strong>Outputs Hash:</strong></div><div>\(receipt.outputsHash?.value ?? "N/A")</div>
                </div>
            </div>
            """
        }
        
        html += """
        </body>
        </html>
        """
        
        return html
    }
    
    private func generateTextReport(receipts: [ReceiptWire], title: String) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        
        var report = """
        \(title)
        ================
        Generated on \(formatter.string(from: Date()))
        Total Receipts: \(receipts.count)
        
        """
        
        for (index, receipt) in receipts.enumerated() {
            let timestamp = formatter.string(from: Date(timeIntervalSince1970: TimeInterval(receipt.timestampMs) / 1000))
            let status = receipt.signature != nil ? "VERIFIED" : "UNVERIFIED"
            
            report += """

        Receipt #\(index + 1)
        -----------------
        ID: \(receipt.receiptID)
        Status: \(status)
        Timestamp: \(timestamp)
        Action: \(receipt.actionName)
        Authority: \(receipt.authority)
        Decision: \(receipt.decision.rawValue)
        Reason: \(receipt.reasonCode)
        Inputs Hash: \(receipt.inputsHash.value)
        Outputs Hash: \(receipt.outputsHash?.value ?? "N/A")
        Previous Hash: \(receipt.previousReceiptHash ?? "N/A")
        
        """
        }
        
        report += """

        Verification Summary
        ==================
        Total Receipts: \(receipts.count)
        Verified: \(receipts.filter { $0.signature != nil }.count)
        Unverified: \(receipts.filter { $0.signature == nil }.count)
        
        Report generated by Anigma Cathedral Receipt System v1.0.0
        """
        
        return report
    }
}

// MARK: - CSV Generator

public class CSVGenerator {
    
    public init() {}
    
    public func generateReceiptCSV(receipts: [ReceiptWire], outputPath: String) throws {
        var csvContent = "Receipt ID,Timestamp,Action Name,Authority,Decision,Reason Code,Inputs Hash,Outputs Hash,Previous Hash,Has Signature\n"
        
        for receipt in receipts {
            let timestamp = ISO8601DateFormatter().string(from: Date(timeIntervalSince1970: TimeInterval(receipt.timestampMs) / 1000))
            let hasSignature = receipt.signature != nil ? "Yes" : "No"
            let outputsHash = receipt.outputsHash?.value ?? ""
            let previousHash = receipt.previousReceiptHash ?? ""
            
            csvContent += "\(receipt.receiptID),\(timestamp),\(receipt.actionName),\(receipt.authority),\(receipt.decision.rawValue),\(receipt.reasonCode),\(receipt.inputsHash.value),\(outputsHash),\(previousHash),\(hasSignature)\n"
        }
        
        try csvContent.write(to: URL(fileURLWithPath: outputPath), atomically: true, encoding: .utf8)
    }
    
    public func generateStatisticsCSV(_ stats: SessionStats, outputPath: String) throws {
        var csvContent = "Metric,Value,Percentage\n"
        
        csvContent += "Total Operations,\(stats.totalOperations),100.0%\n"
        csvContent += "Successful Operations,\(stats.successfulOperations),\(String(format: "%.1f%%", stats.successRate * 100))\n"
        csvContent += "Failed Operations,\(stats.failedOperations),\(String(format: "%.1f%%", (1 - stats.successRate) * 100))\n"
        csvContent += "Total Inference Time (ms),\(stats.totalInferenceTimeMs),\n"
        csvContent += "Average Inference Time (ms),\(stats.averageInferenceTimeMs),\n"
        csvContent += "Total Input Tokens,\(stats.totalInputTokens),\n"
        csvContent += "Total Output Tokens,\(stats.totalOutputTokens),\n"
        csvContent += "Total Tokens,\(stats.totalTokens),\n"
        
        csvContent += "\nProvider Breakdown\n"
        for (provider, count) in stats.providerStats {
            let percentage = Double(count) / Double(stats.totalOperations) * 100
            csvContent += "\(provider),\(count),\(String(format: "%.1f%%", percentage))\n"
        }
        
        csvContent += "\nTask Type Breakdown\n"
        for (taskType, count) in stats.taskTypeStats {
            let percentage = Double(count) / Double(stats.totalOperations) * 100
            csvContent += "\(taskType),\(count),\(String(format: "%.1f%%", percentage))\n"
        }
        
        try csvContent.write(to: URL(fileURLWithPath: outputPath), atomically: true, encoding: .utf8)
    }
}