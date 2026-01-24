//
//  AnigmaMCPServer+Helpers.swift
//  AnigmaMCPModule
//
//  Helper functions and extensions for MCP server.
//

import Foundation
import MCP
import DatabaseCore

extension AnigmaMCPServer {
    func formatDatabaseValue(_ value: DatabaseValue) -> String {
        switch value {
        case .text(let text):
            return text
        case .int(let int):
            return String(int)
        case .double(let double):
            return String(double)
        case .blob(let data):
            return "<blob \(data.count) bytes>"
        case .null:
            return "null"
        }
    }

    func valueToAny(_ value: Value) -> Any? {
        switch value {
        case .null: return NSNull()
        case .bool(let b): return b
        case .int(let i): return i
        case .double(let d): return d
        case .string(let s): return s
        case .array(let a): return a.compactMap { valueToAny($0) }
        case .object(let o):
            var dict: [String: Any] = [: ]
            for (k, v) in o {
                if let val = valueToAny(v) { dict[k] = val }
            }
            return dict
        case .data: return nil
        }
    }

    func convertToValue(_ any: Any) -> Value? {
        if let s = any as? String { return .string(s) }
        if let i = any as? Int { return .number(Double(i)) }
        if let d = any as? Double { return .number(d) }
        if let b = any as? Bool { return .bool(b) }
        return nil
    }
}

extension ToolCallResponse {
    var mcpResult: CallTool.Result {
        if let data = result, let str = String(data: data, encoding: .utf8) {
            return CallTool.Result(content: [.text(str)], isError: status == .failed)
        }
        return CallTool.Result(content: [.text(diagnosis ?? "Tool execution status: \(status.rawValue)")], isError: status == .failed)
    }
}
