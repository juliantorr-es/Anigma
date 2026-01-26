import Foundation

public enum CanonicalNormalization {
    /// Pretty-prints JSON and sorts keys for deterministic comparison
    public static func normalizeJSON(_ data: Data) throws -> Data {
        let json = try JSONSerialization.jsonObject(with: data)
        let normalized = try JSONSerialization.data(withJSONObject: json, options: [.sortedKeys, .prettyPrinted])
        return normalized
    }
    
    /// Replaces UUIDs with <UUID> placeholder
    public static func maskUUIDs(in string: String) -> String {
        let pattern = "[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return string }
        let range = NSRange(string.startIndex..., in: string)
        return regex.stringByReplacingMatches(in: string, range: range, withTemplate: "<UUID>")
    }
    
    /// Replaces ISO8601 timestamps with <TIMESTAMP> placeholder
    public static func maskTimestamps(in string: String) -> String {
        let pattern = #"\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?Z"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return string }
        let range = NSRange(string.startIndex..., in: string)
        return regex.stringByReplacingMatches(in: string, range: range, withTemplate: "<TIMESTAMP>")
    }
    
    /// Combined normalization for typical log/JSON outputs
    public static func canonicalize(_ string: String) -> String {
        var result = maskUUIDs(in: string)
        result = maskTimestamps(in: result)
        return result
    }
}
