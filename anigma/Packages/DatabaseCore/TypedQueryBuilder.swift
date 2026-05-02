//
//  TypedQueryBuilder.swift
//  DatabaseCore
//
//  Strongly-typed query builder for PostgreSQL.
//  Enables type-safe column references and query construction.
//
//  See td-a1d1c9: Create TypedQueryBuilder with strongly-typed columns
//  See td-89a996: PostgreSQL First-Class Implementation Epic
//

import Foundation

/// Marker protocol for types that represent database tables
public protocol TableType: Sendable {
    /// Table name in the database
    static var tableName: String { get }
}

/// Concrete table definition that can be used to define columns
public struct Table<T: TableType>: TableType {
    public static var tableName: String { T.tableName }
}

/// Protocol for column definitions with type information
public protocol TypedColumn: Sendable {
    /// Column name in the database
    var name: String { get }
    
    /// SQL type of the column
    var sqlType: String { get }
    
    /// Whether this column is nullable
    var isNullable: Bool { get }
    
    /// Whether this column is a primary key
    var isPrimaryKey: Bool { get }
    
    /// Default value for the column (if any)
    var defaultValue: String? { get }
}

/// Column builder for defining table schema
public struct ColumnDefinition<T: TableType>: TypedColumn {
    public let name: String
    public let sqlType: String
    public let isNullable: Bool
    public let isPrimaryKey: Bool
    public let defaultValue: String?
    
    public init(
        name: String,
        sqlType: String,
        isNullable: Bool = false,
        isPrimaryKey: Bool = false,
        defaultValue: String? = nil
    ) {
        self.name = name
        self.sqlType = sqlType
        self.isNullable = isNullable
        self.isPrimaryKey = isPrimaryKey
        self.defaultValue = defaultValue
    }
}

/// Reference to a column in a query
public struct ColumnReference<T: TableType>: Sendable, Hashable {
    public let table: T.Type
    public let name: String
    
    public init(table: T.Type, name: String) {
        self.table = table
        self.name = name
    }
    
    /// Get the qualified column name (table.column)
    public func qualified() -> String {
        T.tableName + "." + name
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(String(describing: table))
        hasher.combine(name)
    }
    
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.name == rhs.name && String(describing: lhs.table) == String(describing: rhs.table)
    }
}

/// Type-safe SELECT clause builder
public struct SelectClause: Sendable {
    private var columns: [String] = []
    private var fromTable: String?
    
    public init() {}
    
    public mutating func select(_ column: ColumnReference<some TableType>) {
        columns.append(column.qualified())
    }
    
    public mutating func from<U: TableType>(_ table: U.Type) {
        fromTable = U.tableName
    }
    
    public func build() -> String {
        var sql = "SELECT "
        if columns.isEmpty {
            sql += "*"
        } else {
            sql += columns.joined(separator: ", ")
        }
        if let fromTable = fromTable {
            sql += " FROM " + fromTable
        }
        return sql
    }
}

/// Type-safe WHERE clause builder
public struct WhereClause: Sendable {
    private var conditions: [String] = []
    private var parameters: [DatabaseParameter] = []
    
    public init() {}
    
    public mutating func equal<T: TableType>(_ column: ColumnReference<T>, _ value: String) {
        conditions.append(column.qualified() + " = ?")
        parameters.append(.text(value))
    }
    
    public mutating func equal<T: TableType>(_ column: ColumnReference<T>, _ value: Int) {
        conditions.append(column.qualified() + " = ?")
        parameters.append(.int(value))
    }
    
    public mutating func notEqual<T: TableType>(_ column: ColumnReference<T>, _ value: String) {
        conditions.append(column.qualified() + " != ?")
        parameters.append(.text(value))
    }
    
    public mutating func greaterThan<T: TableType>(_ column: ColumnReference<T>, _ value: Int) {
        conditions.append(column.qualified() + " > ?")
        parameters.append(.int(value))
    }
    
    public mutating func lessThan<T: TableType>(_ column: ColumnReference<T>, _ value: Int) {
        conditions.append(column.qualified() + " < ?")
        parameters.append(.int(value))
    }
    
    public func build() -> (sql: String, parameters: [DatabaseParameter]) {
        let whereSQL = conditions.isEmpty ? "" : " WHERE " + conditions.joined(separator: " AND ")
        return (whereSQL, parameters)
    }
}

/// Main typed query builder
public struct TypedQueryBuilder<T: TableType>: Sendable {
    private var selectClause: SelectClause
    private var whereClause: WhereClause
    private var orderBy: [String] = []
    private var limitValue: Int?
    private var offsetValue: Int?
    
    public init() {
        selectClause = SelectClause()
        whereClause = WhereClause()
    }
    
    public mutating func select(_ column: ColumnReference<T>) {
        selectClause.select(column)
    }
    
    public mutating func from(_ table: T.Type = T.self) {
        selectClause.from(table)
    }
    
    public mutating func whereEqual(_ column: ColumnReference<T>, _ value: String) {
        whereClause.equal(column, value)
    }
    
    public mutating func whereEqual(_ column: ColumnReference<T>, _ value: Int) {
        whereClause.equal(column, value)
    }
    
    public mutating func whereNotEqual(_ column: ColumnReference<T>, _ value: String) {
        whereClause.notEqual(column, value)
    }
    
    public mutating func orderBy(_ column: ColumnReference<T>, ascending: Bool = true) {
        orderBy.append(column.qualified() + (ascending ? " ASC" : " DESC"))
    }

    public mutating func orderByRaw(_ expression: String) {
        orderBy.append(expression)
    }
    
    public mutating func limit(_ value: Int) {
        limitValue = value
    }
    
    public mutating func offset(_ value: Int) {
        offsetValue = value
    }
    
    public func build() -> (sql: String, parameters: [DatabaseParameter]) {
        var sql = selectClause.build()
        let (whereSQL, parameters) = whereClause.build()
        sql += whereSQL
        
        if !orderBy.isEmpty {
            sql += " ORDER BY " + orderBy.joined(separator: ", ")
        }
        
        if let limitValue = limitValue {
            sql += " LIMIT " + String(limitValue)
        }
        
        if let offsetValue = offsetValue {
            sql += " OFFSET " + String(offsetValue)
        }
        
        return (sql, parameters)
    }
}
