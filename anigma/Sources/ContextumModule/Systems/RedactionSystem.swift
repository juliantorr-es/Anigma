import Foundation
import ContractsCore
import CryptoKit
import DatabaseCore

/// System for applying redaction rules with governed content mutation
public actor RedactionSystem {
    private let database: ContextumDatabase

    public init(database: ContextumDatabase) {
        self.database = database
    }

    /// Apply redaction rules to target content
    public func applyRedactionRules(
        rulesetHash: String,
        rules: [RedactionRule],
        targets: [RedactionTarget]
    ) async throws -> RedactionManifest {
        let manifestID = UUID().uuidString
        var manifestEntries: [RedactionManifestEntry] = []

        for target in targets {
            let originalHash = hashContent(target.content)
            var redactedContent = target.content

            // Apply each rule in sequence
            for rule in rules {
                redactedContent = applyRule(rule, to: redactedContent)
            }

            let redactedHash = hashContent(redactedContent)

            // Store redacted content and manifest entry
            // Also store as artifact via ArtifactAuthority if configured
            let redactedData = Data(redactedContent.utf8)
            _ = try? await database.storeContentAsArtifact(redactedData, mimeType: "text/plain", tags: ["redacted"], metadata: ["originalHash": originalHash, "redactedHash": redactedHash])
            
            try await database.storeRedactedContent(
                targetHash: target.hash,
                originalHash: originalHash,
                redactedContent: redactedContent,
                redactedHash: redactedHash,
                isReversible: rules.contains(where: \.isReversible)
            )

            manifestEntries.append(RedactionManifestEntry(
                targetHash: target.hash,
                originalContentHash: originalHash,
                redactedContentHash: redactedHash,
                redactedAt: Date()
            ))
        }

        return RedactionManifest(
            manifestID: manifestID,
            rulesetHash: rulesetHash,
            entries: manifestEntries,
            totalRedacted: manifestEntries.count
        )
    }

    private func applyRule(_ rule: RedactionRule, to content: String) -> String {
        // Compile regex with error logging
        let regex: NSRegularExpression
        do {
            regex = try NSRegularExpression(pattern: rule.pattern)
        } catch {
            print("⚠️ [RedactionSystem] Invalid regex pattern in rule '\(rule.ruleID)': \(error)")
            return content  // Skip this rule if pattern is invalid
        }

        let range = NSRange(content.startIndex..., in: content)
        return regex.stringByReplacingMatches(
            in: content,
            range: range,
            withTemplate: rule.replacement
        )
    }

    private func hashContent(_ content: String) -> String {
        let data = Data(content.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}

/// Redaction rule definition
public struct RedactionRule: Codable, Sendable {
    public let ruleID: String
    public let pattern: String
    public let replacement: String
    public let isReversible: Bool
    public let encryptionKeyID: String?

    public init(
        ruleID: String,
        pattern: String,
        replacement: String,
        isReversible: Bool = false,
        encryptionKeyID: String? = nil
    ) {
        self.ruleID = ruleID
        self.pattern = pattern
        self.replacement = replacement
        self.isReversible = isReversible
        self.encryptionKeyID = encryptionKeyID
    }
}

/// Target for redaction
public struct RedactionTarget: Sendable {
    public let hash: String
    public let content: String

    public init(hash: String, content: String) {
        self.hash = hash
        self.content = content
    }
}

/// Redaction manifest artifact
public struct RedactionManifest: Codable, Sendable {
    public let manifestID: String
    public let rulesetHash: String
    public let entries: [RedactionManifestEntry]
    public let totalRedacted: Int
}

public struct RedactionManifestEntry: Codable, Sendable {
    public let targetHash: String
    public let originalContentHash: String
    public let redactedContentHash: String
    public let redactedAt: Date
}

extension ContextumDatabase {
    func storeRedactedContent(
        targetHash: String,
        originalHash: String,
        redactedContent: String,
        redactedHash: String,
        isReversible: Bool
    ) async throws {
        let sql = """
            UPDATE chunks
            SET content = ?,
                metadata = json_set(
                    COALESCE(metadata, '{}'),
                    '$.redacted', 1,
                    '$.originalHash', ?,
                    '$.redactedHash', ?,
                    '$.reversible', ?
                )
            WHERE chunkHash = ?
            """

        _ = try await dbActor.executeAsync(sql, parameters: [
            DatabaseParameter.text(redactedContent),
            DatabaseParameter.text(originalHash),
            DatabaseParameter.text(redactedHash),
            DatabaseParameter.int(isReversible ? 1 : 0),
            DatabaseParameter.text(targetHash)
        ])

        // Update FTS index
        let ftsSql = "UPDATE fts_chunks SET content = ? WHERE chunkHash = ?"
        _ = try await dbActor.executeAsync(ftsSql, parameters: [
            DatabaseParameter.text(redactedContent),
            DatabaseParameter.text(targetHash)
        ])
    }
}
