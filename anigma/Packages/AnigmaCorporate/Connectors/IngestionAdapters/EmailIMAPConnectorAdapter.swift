//
//  EmailIMAPConnectorAdapter.swift
//  AnigmaCorporate
//
//  Email/IMAP connector ingestion adapter for personal data
//  Normalizes email content into DocumentTruth inputs for Contextum ingestion
//

import Foundation
import CryptoKit
import ContextumModule
import AnigmaSystemSpine

/// Email/IMAP connector ingestion adapter
/// Converts email messages into DocumentTruth inputs for Contextum ingestion
public struct EmailIMAPConnectorAdapter: Sendable {
    public let adapterID = "connector-ingestion/email-imap"
    private let contextum: Contextum
    private let policyPosture: PolicyPosture
    
    public init(contextum: Contextum, policyPosture: PolicyPosture = .emailDefault) {
        self.contextum = contextum
        self.policyPosture = policyPosture
    }
    
    /// Ingest an email message into Contextum with proper DocumentTruth structure
    public func ingestEmailMessage(
        emailId: String,
        subject: String,
        from: String,
        to: [String],
        date: Date,
        body: String,
        attachments: [EmailAttachment] = [],
        consentScope: PermissionScope,
        metadata: [String: String] = [:]
    ) async throws -> DocumentTruthIngestReceipt {
        // Validate network access policy
        guard policyPosture.isNetworkAllowed else {
            throw ConnectorIngestionError.policyViolation("Email ingestion disabled by policy (network access required)")
        }
        
        // Validate email consent scope
        guard consentScope.connectedSources.contains(where: { $0.hasPrefix("Email:") }) else {
            throw ConnectorIngestionError.consentDenied("No email consent for message: \(emailId)")
        }
        
        // Create email document content
        let emailContent = createEmailDocument(
            subject: subject,
            from: from,
            to: to,
            date: date,
            body: body,
            attachments: attachments
        )
        
        // Create DocumentTruth ingest input
        let ingestInput = DocumentTruthIngestInput(
            format: .plainText,  // Email content as plain text
            content: emailContent,
            pdfLayout: nil,
            mimeType: "message/rfc822",
            canonicalRef: "email-imap://\(emailId)",
            uri: "imap://email/\(emailId)",
            title: subject.isEmpty ? "Email \(emailId)" : subject,
            metadata: metadata
        )
        
        // Create ContextSourceComponent for Contextum ingestion
        let sourceComponent = ContextSourceComponent(
            sourceId: UUID().uuidString,
            sourceType: .document,
            artifactHash: try await computeContentHash(emailContent),
            receiptId: UUID().uuidString,
            timestamp: Date(),
            metadata: [
                "connector_adapter": adapterID,
                "email_id": emailId,
                "email_from": from,
                "email_to": to.joined(separator: ","),
                "email_date": date.iso8601String,
                "email_subject": subject,
                "attachment_count": String(attachments.count),
                "ingest_method": "email_imap",
                "consent_scope": consentScope.connectedSources.joined(separator: ",")
            ],
            uri: "imap://email/\(emailId)",
            canonicalRef: "email-imap://\(emailId)",
            currentHash: try await computeContentHash(emailContent),
            mimeType: "message/rfc822"
        )
        
        // Ingest through Contextum pipeline
        let receipt = try await contextum.ingestDocumentTruth(
            source: sourceComponent,
            input: ingestInput
        )
        
        return receipt
    }
    
    /// Ingest multiple email messages with batch processing
    public func ingestEmailMessages(
        emails: [EmailMessage],
        consentScope: PermissionScope
    ) async throws -> [DocumentTruthIngestReceipt] {
        var receipts: [DocumentTruthIngestReceipt] = []
        
        for email in emails {
            do {
                let receipt = try await ingestEmailMessage(
                    emailId: email.id,
                    subject: email.subject,
                    from: email.from,
                    to: email.to,
                    date: email.date,
                    body: email.body,
                    attachments: email.attachments,
                    consentScope: consentScope
                )
                receipts.append(receipt)
            } catch {
                // Log individual email failures but continue with others
                print("⚠️  Email ingestion failed for \(email.subject): \(error.localizedDescription)")
                continue
            }
        }
        
        return receipts
    }
    
    /// Create formatted email document content
    private func createEmailDocument(
        subject: String,
        from: String,
        to: [String],
        date: Date,
        body: String,
        attachments: [EmailAttachment]
    ) -> String {
        var document = ""
        
        // Add email headers
        document += "Subject: \(subject)\n"
        document += "From: \(from)\n"
        document += "To: \(to.joined(separator: ", "))\n"
        document += "Date: \(date.iso8601String)\n"
        document += "\n"  // Blank line before body
        
        // Add email body
        document += "\(body)\n\n"
        
        // Add attachments section
        if !attachments.isEmpty {
            document += "---\n"
            document += "Attachments: \(attachments.count)\n"
            for attachment in attachments {
                document += "- \(attachment.name) (\(attachment.size) bytes, \(attachment.mimeType))\n"
            }
        }
        
        return document
    }
    
    /// Compute content hash for deduplication
    private func computeContentHash(_ content: String) async throws -> String {
        let data = content.data(using: .utf8) ?? Data()
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Email Data Structures

public struct EmailMessage: Sendable {
    public let id: String
    public let subject: String
    public let from: String
    public let to: [String]
    public let date: Date
    public let body: String
    public let attachments: [EmailAttachment]
    
    public init(
        id: String,
        subject: String,
        from: String,
        to: [String],
        date: Date,
        body: String,
        attachments: [EmailAttachment] = []
    ) {
        self.id = id
        self.subject = subject
        self.from = from
        self.to = to
        self.date = date
        self.body = body
        self.attachments = attachments
    }
}

public struct EmailAttachment: Sendable {
    public let name: String
    public let mimeType: String
    public let size: Int
    public let content: Data?
    
    public init(name: String, mimeType: String, size: Int, content: Data? = nil) {
        self.name = name
        self.mimeType = mimeType
        self.size = size
        self.content = content
    }
}

// MARK: - Default Policy Postures for Email

public extension PolicyPosture {
    static var emailDefault: PolicyPosture {
        PolicyPosture(
            isLocalOnly: false,
            isNetworkAllowed: true,
            retentionPolicy: "90days",
            allowDerivedArtifacts: true
        )
    }
    
    static var emailCompliance: PolicyPosture {
        PolicyPosture(
            isLocalOnly: false,
            isNetworkAllowed: true,
            retentionPolicy: "30days",
            allowDerivedArtifacts: false
        )
    }
}

// MARK: - Date Formatting Extension

extension Date {
    var iso8601String: String {
        let formatter = ISO8601DateFormatter()
        return formatter.string(from: self)
    }
}
