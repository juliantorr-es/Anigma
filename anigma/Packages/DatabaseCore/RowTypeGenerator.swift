//
//  RowTypeGenerator.swift
//  DatabaseCore
//
//  Generates Swift row types from schema definitions.
//  Enables type-safe database row decoding.
//
//  See td-cbb1b3: Generate row types from schema definitions
//  See td-89a996: PostgreSQL First-Class Implementation Epic
//

import Foundation

/// Protocol for types that can be decoded from database rows
public protocol RowType: Codable, Sendable {
    /// Initialize from a database row
    init(from row: DatabaseRow) throws
    
    /// Convert to a database row
    func toRow() -> DatabaseRow
}

/// Generator for creating RowType implementations from schema definitions
public enum RowTypeGenerator {
    
    /// Column type definition for row type generation
    public struct ColumnDefinition: Sendable {
        public let name: String
        public let swiftType: String
        public let sqlType: String
        public let isNullable: Bool
        public let isPrimaryKey: Bool
        
        public init(
            name: String,
            swiftType: String,
            sqlType: String,
            isNullable: Bool = false,
            isPrimaryKey: Bool = false
        ) {
            self.name = name
            self.swiftType = swiftType
            self.sqlType = sqlType
            self.isNullable = isNullable
            self.isPrimaryKey = isPrimaryKey
        }
    }
    
    /// Table schema definition for row type generation
    public struct TableSchema: Sendable {
        public let tableName: String
        public let module: String
        public let columns: [ColumnDefinition]
        
        public init(tableName: String, module: String, columns: [ColumnDefinition]) {
            self.tableName = tableName
            self.module = module
            self.columns = columns
        }
    }
    
    /// Generate a RowType struct source code from a table schema
    public static func generateRowType(for schema: TableSchema) -> String {
        let structName = makeStructName(from: schema.tableName)
        var code = """
// Generated RowType for table: 

import Foundation
import DatabaseCore

/// Auto-generated row type for 
public struct 
"""
        code += structName + ": RowType, Codable, Sendable {\n"
        
        // Add properties
        for column in schema.columns {
            let propertyName = makePropertyName(from: column.name)
            let swiftType = column.isNullable ? column.swiftType + "?" : column.swiftType
            code += "    public let " + propertyName + ": " + swiftType + "\n"
        }
        
        code += "\n"
        
        // Add init from row
        code += "    public init(from row: DatabaseRow) throws {\n"
        for column in schema.columns {
            let propertyName = makePropertyName(from: column.name)
            let columnName = column.name
            if column.isNullable {
                code += "        self." + propertyName + " = row[\"" + columnName + "\"]\n"
            } else {
                code += "        guard let value = row[\"" + columnName + "\"] else {\n"
                code += "            throw RowDecodeError.missingColumn(\"" + columnName + "\")\n"
                code += "        }\n"
                code += "        self." + propertyName + " = value\n"
            }
        }
        code += "    }\n\n"
        
        // Add toRow
        code += "    public func toRow() -> DatabaseRow {\n"
        code += "        var values: [String: DatabaseValue] = [:]\n"
        for column in schema.columns {
            let propertyName = makePropertyName(from: column.name)
            let columnName = column.name
            code += "        values[\"" + columnName + "\"] = mapToDatabaseValue(self." + propertyName + ")\n"
        }
        code += "        return DatabaseRow(values: values)\n"
        code += "    }\n"
        
        // Add helper to map Swift types to DatabaseValue
        code += "\n"
        code += "    private func mapToDatabaseValue(_ value: Any?) -> DatabaseValue {\n"
        code += "        if let value = value as? String { return .text(value) }\n"
        code += "        if let value = value as? Int { return .int(value) }\n"
        code += "        if let value = value as? Double { return .double(value) }\n"
        code += "        if let value = value as? Data { return .blob(value) }\n"
        code += "        if let value = value as? Date { return .date(value) }\n"
        code += "        return .null\n"
        code += "    }\n"
        
        code += "}\n"
        
        return code
    }
    
    /// Convert snake_case or kebab-case table name to PascalCase struct name
    private static func makeStructName(from tableName: String) -> String {
        let components = tableName.split { $0 == "_" || $0 == "-" || $0 == " " }.filter { !$0.isEmpty }
        let capitalized = components.map { $0.prefix(1).capitalized + $0.dropFirst() }
        return capitalized.joined() + "Row"
    }
    
    /// Convert snake_case column name to camelCase property name
    private static func makePropertyName(from columnName: String) -> String {
        let components = columnName.split(separator: "_").filter { !$0.isEmpty }
        guard !components.isEmpty else { return columnName }
        return components[0].lowercased() + components.dropFirst().map { 
            $0.prefix(1).capitalized + $0.dropFirst() 
        }.joined()
    }
}

/// Error for row decoding failures
public enum RowDecodeError: Error, CustomStringConvertible {
    case missingColumn(String)
    case typeMismatch(column: String, expected: String, actual: String)
    
    public var description: String {
        switch self {
        case let .missingColumn(column):
            return "Missing column: " + column
        case let .typeMismatch(column, expected, actual):
            return "Type mismatch for column \"" + column + "\": expected " + expected + ", got " + actual
        }
    }
}
