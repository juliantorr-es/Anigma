import Foundation

/// Redaction rules for sensitive data in diagnostic messages
public struct DiagnosticRedactionRules {
    private static let passwordPattern = try! NSRegularExpression(
        pattern: "(?i)(?:password|passwd|pwd|pass)\\s*[=:]\\s*(?:['\"])?([^'\"\\s,;}\\]]+)(?:['\"])?",
        options: []
    )
    private static let apiKeyPattern = try! NSRegularExpression(
        pattern: "(?i)(?:api[\\s_-]?key|apikey|api_token|access_token|auth_token|secret_key|secret_token)\\s*[=:]\\s*(?:['\"])?([a-zA-Z0-9_\\-\\.]{6,})(?:['\"])?",
        options: []
    )
    private static let awsSecretPattern = try! NSRegularExpression(
        pattern: "(?i)(?:aws[_-]?secret|secret_access_key|secretaccesskey)\\s*[=:]\\s*(?:['\"])?([A-Za-z0-9/+=]+)(?:['\"])?",
        options: []
    )
    private static let jwtPattern = try! NSRegularExpression(
        pattern: "(?:eyJ[A-Za-z0-9_-]+\\.eyJ[A-Za-z0-9_-]+\\.[A-Za-z0-9_-]+)",
        options: []
    )
    private static let bearerTokenPattern = try! NSRegularExpression(
        pattern: "(?i)(?:bearer|token)\\s+(?:['\"])?([a-zA-Z0-9_\\-\\.]+)(?:['\"])?",
        options: []
    )
    private static let connectionStringPattern = try! NSRegularExpression(
        pattern: "(?i)(?:connection[_-]?string|db[_-]?url|database[_-]?url)\\s*[=:]\\s*(?:['\"])?([^'\"\\s;]+)(?:['\"])?",
        options: []
    )
    private static let oauthTokenPattern = try! NSRegularExpression(
        pattern: "(?i)(?:access_token|refresh_token|id_token)\\s*[=:]\\s*(?:['\"])?([a-zA-Z0-9_\\-\\.]{20,})(?:['\"])?",
        options: []
    )
    private static let privateKeyPattern = try! NSRegularExpression(
        pattern: "(?:-----BEGIN\\s+(?:RSA\\s+)?PRIVATE\\s+KEY.*?-----END\\s+(?:RSA\\s+)?PRIVATE\\s+KEY-----)",
        options: [.dotMatchesLineSeparators]
    )
    private static let emailPattern = try! NSRegularExpression(
        pattern: "[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}",
        options: []
    )
    private static let ipv4Pattern = try! NSRegularExpression(
        pattern: "\\b(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\b",
        options: []
    )
    private static let hexKeyPattern = try! NSRegularExpression(
        pattern: "\\b[0-9a-fA-F]{32,}\\b",
        options: []
    )
    private static let base64BlobPattern = try! NSRegularExpression(
        pattern: "(?:[A-Za-z0-9+/]{4}){8,}(?:[A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=)?",
        options: []
    )
    private static let creditCardPattern = try! NSRegularExpression(
        pattern: "\\b(?:\\d[ -]*?){13,19}\\b",
        options: []
    )
    private static let ssnPattern = try! NSRegularExpression(
        pattern: "\\b(?:\\d{3}[-]?\\d{2}[-]?\\d{4})\\b",
        options: []
    )

    public static let safeKeys: Set<String> = [
        "id", "count", "duration", "timestamp", "level", "category",
        "correlationID", "spanID", "parentSpanID", "status", "name"
    ]

    private static let patterns: [(NSRegularExpression, String)] = [
        (privateKeyPattern, "[REDACTED_PRIVATE_KEY]"),
        (passwordPattern, "[REDACTED_PASSWORD]"),
        (apiKeyPattern, "[REDACTED_API_KEY]"),
        (awsSecretPattern, "[REDACTED_AWS_SECRET]"),
        (jwtPattern, "[REDACTED_JWT_TOKEN]"),
        (bearerTokenPattern, "[REDACTED_BEARER_TOKEN]"),
        (oauthTokenPattern, "[REDACTED_OAUTH_TOKEN]"),
        (connectionStringPattern, "[REDACTED_CONNECTION_STRING]"),
        (creditCardPattern, "[REDACTED_CREDIT_CARD]"),
        (ssnPattern, "[REDACTED_SSN]"),
        (emailPattern, "[REDACTED_EMAIL]"),
        (ipv4Pattern, "[REDACTED_IP_ADDRESS]")
    ]

    private static let deepCleanPatterns: [(NSRegularExpression, String)] = [
        (hexKeyPattern, "[REDACTED_HEX_KEY]"),
        (base64BlobPattern, "[REDACTED_BASE64_BLOB]")
    ]

    public static func sanitize(_ string: String, deepClean: Bool = false) -> String {
        var result = string

        for (pattern, replacement) in patterns {
            result = pattern.stringByReplacingMatches(
                in: result,
                options: [],
                range: NSRange(result.startIndex..., in: result),
                withTemplate: replacement
            )
        }

        if deepClean {
            for (pattern, replacement) in deepCleanPatterns {
                result = pattern.stringByReplacingMatches(
                    in: result,
                    options: [],
                    range: NSRange(result.startIndex..., in: result),
                    withTemplate: replacement
                )
            }
        }

        return result
    }

    public static func sanitizeTags(_ tags: [String: String], deepClean: Bool = false) -> [String: String] {
        var sanitized: [String: String] = [:]

        for (key, value) in tags {
            if safeKeys.contains(key) {
                sanitized[key] = value
            } else {
                sanitized[key] = sanitize(value, deepClean: deepClean)
            }
        }

        return sanitized
    }
}
