//
//  InputNormalizer.swift
//  HarmoniaInference
//
//  Normalizes tool inputs and outputs to eliminate environmental variance.
//  Handles locale invariant formatting, line endings, paths, and metadata.
//  Migrated from HarmoniaModule - Pure functions with zero side effects.
//

import Foundation

/// Normalizes input/output to eliminate environmental sources of nondeterminism
public enum InputNormalizer {

    /// Current normalizer version pinned for determinism
    public static let currentVersion = "1.0.0"

    /// Normalize a string for canonical comparison
    public static func normalize(_ input: String) -> String {
        return input
            .normalizingLineEndings()
            .normalizingPaths()
            .normalizingTimestamps()
            .normalizingLineNumbers()
            .normalizingWhitespace()
    }

    /// Normalize binary data for consistent hashing
    public static func normalize(_ data: Data) -> Data {
        guard let string = String(data: data, encoding: .utf8) else {
            return data // Binary data, return as-is
        }

        return normalize(string).data(using: .utf8) ?? data
    }

    /// Extract content from tool output while normalizing metadata
    public static func extractCanonicalContent(_ output: String) -> String {
        let lines = output.components(separatedBy: .newlines)
        let contentLines = lines.filter { line in
            // Skip typical compiler timestamps
            guard !line.contains("at ") && !line.contains("date ") else { return false }
            // Skip build IDs
            guard !line.contains("Build ID:") && !line.contains("Version:") else { return false }
            // Skip machine-specific paths
            guard !line.contains("/var/folders/") && !line.contains("/tmp/") else { return false }
            return true
        }
        return contentLines.joined(separator: "\n")
    }
}

extension String {
    // Normalize line endings to \n
    fileprivate func normalizingLineEndings() -> String {
        return self.replacingOccurrences(of: "\r\n", with: "\n")
                    .replacingOccurrences(of: "\r", with: "\n")
    }

    // Normalize file paths to canonical form
    fileprivate func normalizingPaths() -> String {
        // Basic Unix path normalization
        let components = self.components(separatedBy: "/")
        var normalized: [String] = []

        for component in components {
            if component.isEmpty || component == "." {
                continue
            }
            if component == ".." {
                if !normalized.isEmpty {
                    _ = normalized.popLast()
                }
                continue
            }
            normalized.append(component)
        }

        let path = normalized.joined(separator: "/")
        return path.hasPrefix("/") ? path : "/\(path)"
    }

    // Remove or normalize timestamps and temporal references
    fileprivate func normalizingTimestamps() -> String {
        // Replace date patterns with a deterministic token
        let patterns = [
            "\\d{4}-\\d{2}-\\d{2}",
            "\\d{2}:\\d{2}:\\d{2}",
            "\\b(at|date|timestamp)\\b[\\s:]*\\d{1,2}[\\s:]*[A-Za-z]{3}",
            "\\bBuild time: [\\d\\.]+"
        ]

        var result = self
        for pattern in patterns {
            result = result.replacingOccurrences(
                of: pattern,
                with: "<timestamp>",
                options: .regularExpression
            )
        }
        return result
    }

    // Normalize line numbers (make them relative)
    fileprivate func normalizingLineNumbers() -> String {
        // Replace absolute line numbers with relative ones
        let patterns = [
            "line \\d+:",
            ":\\d+:",
            "error:\\s*\\d+:"
        ]

        var result = self
        for pattern in patterns {
            result = result.replacingOccurrences(
                of: pattern,
                with: "line X:",
                options: .regularExpression
            )
        }
        return result
    }

    // Normalize whitespace while preserving meaning
    fileprivate func normalizingWhitespace() -> String {
        // Replace tab with single space
        return self.replacingOccurrences(of: "\t", with: " ")
            // Normalize multiple spaces
            .replacingOccurrences(of: " +", with: " ", options: .regularExpression)
            // Trim leading/trailing
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// Additional tools for compiler output normalization
public struct CompilerOutputNormalizer {

    /// Remove compiler-specific nondeterminisms from output
    public static func normalizeCompilerOutput(_ output: String) -> String {
        var result = InputNormalizer.normalize(output)

        // Remove machine-specific paths and IDs
        result = result.replacingOccurrences(
            of: "/Users/[^\\s]+/",
            with: "/<user>/<project>/",
            options: .regularExpression
        )

        // Remove architecture and target-specific info
        result = result.replacingOccurrences(
            of: "for architecture [a-z0-9_]+",
            with: "for architecture <target>",
            options: .regularExpression
        )

        result = result.replacingOccurrences(
            of: "targeting [a-z0-9_-]+",
            with: "targeting <target>",
            options: .regularExpression
        )

        // Remove build hash/digest values
        result = result.replacingOccurrences(
            of: "\\b[0-9a-f]{8,}[0-9a-f]*\\b",
            with: "<hash>",
            options: .regularExpression
        )

        return result
    }

    /// Extract the meaningful content from compiler output
    public static func extractContent(_ output: String) -> String {
        let normalized = normalizeCompilerOutput(output)

        // Focus on actual errors/warnings, not metadata
        let lines = normalized.components(separatedBy: .newlines)
        let contentLines = lines.filter { line in
            // Keep error/warning lines
            guard line.contains("error:") || line.contains("warning:") else { return false }
            // Keep source file references
            guard line.contains(".swift:") else { return false }
            // Keep descriptions but not timestamps
            return true
        }

        return contentLines.joined(separator: "\n")
    }

    /// Convert compiler diagnostic to canonical form
    public static func canonicalDiagnostic(_ output: String) -> String {
        let content = extractContent(output)

        // Parse file:line:column: error/warning: message
        let lines = content.components(separatedBy: .newlines)
        let canonicalLines = lines.compactMap { line -> String? in
            // Extract file:line and message for canonical form
            var canonical = line

            // Extract file path component
            if let pathRange = line.range(of: "[^\\s]+\\.swift:", options: .regularExpression) {
                let fileInfo = String(line[pathRange])
                canonical = fileInfo
            }

            // Extract main message (after colon)
            if let colonRange = line.range(of: ":\\s*(error|warning):", options: .regularExpression) {
                let messageStart = colonRange.upperBound
                if messageStart < line.endIndex {
                    let message = String(line[messageStart...])
                    canonical += ": " + message.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }

            return canonical.isEmpty ? nil : canonical
        }

        // Sort for deterministic ordering
        return canonicalLines.sorted().joined(separator: "\n")
    }
}
