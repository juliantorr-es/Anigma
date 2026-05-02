import Foundation

public struct SheetIR: Codable, Sendable, Identifiable {
    public let id: UUID
    public var title: String
    public var columns: [SheetColumn]
    public var rows: [SheetRow]

    public init(id: UUID = UUID(), title: String, columns: [SheetColumn] = [], rows: [SheetRow] = []) {
        self.id = id
        self.title = title
        self.columns = columns
        self.rows = rows
    }
}

public struct SheetColumn: Codable, Sendable, Identifiable {
    public let id: UUID
    public var name: String
    public var type: SheetColumnType

    public init(id: UUID = UUID(), name: String, type: SheetColumnType) {
        self.id = id
        self.name = name
        self.type = type
    }
}

public enum SheetColumnType: String, Codable, Sendable {
    case text
    case number
    case date
    case currency
    case boolean
}

public struct SheetRow: Codable, Sendable, Identifiable {
    public let id: UUID
    public var cells: [UUID: SheetCell] // Keyed by Column ID

    public init(id: UUID = UUID(), cells: [UUID: SheetCell] = [:]) {
        self.id = id
        self.cells = cells
    }
}

public struct SheetCell: Codable, Sendable {
    public var value: String
    public var formula: String?

    public init(value: String, formula: String? = nil) {
        self.value = value
        self.formula = formula
    }
}
