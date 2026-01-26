import Foundation

/// Redaction rules for sensitive data in diagnostic messages
public struct DiagnosticRedactionRules {
    // MARK: - Regex Patterns for Sensitive Data
    
    /// Pattern for passwords (common variations like password=, pwd=, etc)
    private static let passwordPattern = try! NSRegularExpression(
        pattern: "(?i)(?:password|passwd|pwd|pass)\\s*[=:]\\s*(?:['\"])?([^'\"\\s,;}\\]]+)(?:['\"])?",
        options: []
    )
    
    /// Pattern for API keys (common prefixes and formats)
    private static let apiKeyPattern = try! NSRegularExpression(
        pattern: "(?i)(?:api[\\s_-]?key|apikey|api_token|access_token|auth_token|secret_key|secret_token)\\s*[=:]\\s*(?:['\"])?([a-zA-Z0-9_\\-\\.]{6,})(?:['\"])?",
        options: []
    )
    
    /// Pattern for AWS secrets
    private static let awsSecretPattern = try! NSRegularExpression(
        pattern: "(?i)(?:aws[_-]?secret|secret_access_key|secretaccesskey)\\s*[=:]\\s*(?:['\"])?([A-Za-z0-9/+=]+)(?:['\"])?",
        options: []
    )
    
    /// Pattern for JWT tokens
    private static let jwtPattern = try! NSRegularExpression(
        pattern: "(?:eyJ[A-Za-z0-9_-]+\\.eyJ[A-Za-z0-9_-]+\\.[A-Za-z0-9_-]+)",
        options: []
    )
    
    /// Pattern for bearer tokens
    private static let bearerTokenPattern = try! NSRegularExpression(
        pattern: "(?i)(?:bearer|token)\\s+(?:['\"])?([a-zA-Z0-9_\\-\\.]+)(?:['\"])?",
        options: []
    )
    
    /// Pattern for database connection strings
    private static let connectionStringPattern = try! NSRegularExpression(
        pattern: "(?i)(?:connection[_-]?string|db[_-]?url|database[_-]?url)\\s*[=:]\\s*(?:['\"])?([^'\"\\s;]+)(?:['\"])?",
        options: []
    )
    
    /// Pattern for OAuth tokens
    private static let oauthTokenPattern = try! NSRegularExpression(
        pattern: "(?i)(?:access_token|refresh_token|id_token)\\s*[=:]\\s*(?:['\"])?([a-zA-Z0-9_\\-\\.]{20,})(?:['\"])?",
        options: []
    )
    
    /// Pattern for private keys
    private static let privateKeyPattern = try! NSRegularExpression(
        pattern: "(?:-----BEGIN\\s+(?:RSA\\s+)?PRIVATE\\s+KEY.*?-----END\\s+(?:RSA\\s+)?PRIVATE\\s+KEY-----)",
        options: [.dotMatchesLineSeparators]
    )
    
    /// Pattern for email addresses (to be cautious with PII)
    private static let emailPattern = try! NSRegularExpression(
        pattern: "[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}",
        options: []
    )
    
    /// Pattern for IPv4 addresses (for privacy)
    private static let ipv4Pattern = try! NSRegularExpression(
        pattern: "\\b(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\b",
        options: []
    )
    
    /// Pattern for credit card numbers
    private static let creditCardPattern = try! NSRegularExpression(
        pattern: "\\b(?:\\d[ -]*?){13,19}\\b",
        options: []
    )
    
    /// Pattern for social security numbers
    private static let ssnPattern = try! NSRegularExpression(
        pattern: "\\b(?:\\d{3}[-]?\\d{2}[-]?\\d{4})\\b",
        options: []
    )
    
    /// Patterns to apply in order
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
    
    // MARK: - Public API
    
    /// Sanitize a string by redacting all sensitive patterns
    /// - Parameter string: The string to sanitize
    /// - Returns: A string with all sensitive data redacted
    public static func sanitize(_ string: String) -> String {
        var result = string
        
        // Apply patterns in order, adjusting ranges as we go
        for (pattern, replacement) in patterns {
            result = pattern.stringByReplacingMatches(
                in: result,
                options: [],
                range: NSRange(result.startIndex..., in: result),
                withTemplate: replacement
            )
        }
        
        return result
    }
    
    /// Check if a string contains any sensitive patterns
    /// - Parameter string: The string to check
    /// - Returns: true if sensitive data is detected
    public static func containsSensitiveData(_ string: String) -> Bool {
        let range = NSRange(string.startIndex..., in: string)
        
        for (pattern, _) in patterns {
            if pattern.firstMatch(in: string, options: [], range: range) != nil {
                return true
            }
        }
        
        return false
    }
    
    /// Get a list of detected sensitive patterns in a string
    /// - Parameter string: The string to analyze
    /// - Returns: An array of (pattern name, detected value) tuples
    public static func detectPatterns(_ string: String) -> [(String, String)] {
        var detected: [(String, String)] = []
        let range = NSRange(string.startIndex..., in: string)
        
        let patternNames = [
            "PRIVATE_KEY",
            "PASSWORD",
            "API_KEY",
            "AWS_SECRET",
            "JWT_TOKEN",
            "BEARER_TOKEN",
            "OAUTH_TOKEN",
            "CONNECTION_STRING",
            "CREDIT_CARD",
            "SSN",
            "EMAIL",
            "IP_ADDRESS"
        ]
        
        for (index, (pattern, _)) in patterns.enumerated() {
            let matches = pattern.matches(in: string, options: [], range: range)
            for match in matches {
                if let matchRange = Range(match.range, in: string) {
                    let matched = String(string[matchRange])
                    detected.append((patternNames[index], matched))
                }
            }
        }
        
        return detected
    }
}
