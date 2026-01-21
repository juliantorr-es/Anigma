//
//  SQLitePolicy.swift
//  DatabaseCore
//
//  Policy layer that makes safe SQLite bindings the default.
//  SQLITE_TRANSIENT is required because Swift objects go out of scope immediately.
//  SQLITE_STATIC would require pointer lifetime guarantees that Swift doesn't provide.
//

import Foundation
import SQLite3

// MARK: - Public Safe API (Default Policy)

/// Binds text data with SQLITE_TRANSIENT (safe default)
/// This is the ONLY public binding API - all text must use TRANSIENT in Swift.
public func bindText(_ stmt: OpaquePointer?, _ index: Int32, _ text: String, category: String = "SQLite") {
    fputs("[SQLitePolicy] Binding text as TRANSIENT (safe default): '\(text.prefix(50))...'\n", stderr)
    sqlite3_bind_text(stmt, index, text, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
}

/// Binds blob data with SQLITE_TRANSIENT (safe default)
/// This is the ONLY public binding API - all blobs must use TRANSIENT in Swift.
public func bindBlob(_ stmt: OpaquePointer?, _ index: Int32, _ data: Data, category: String = "SQLite") {
    let hex = data.map { String(format: "%02x", $0) }.joined()
    fputs("[SQLitePolicy] Binding blob as TRANSIENT (safe default): \(data.count) bytes, hex: \(hex)\n", stderr)
    _ = data.withUnsafeBytes { bytes in
        sqlite3_bind_blob(stmt, index, bytes.baseAddress, Int32(data.count), unsafeBitCast(-1, to: sqlite3_destructor_type.self))
    }
}

/// Binds UUID as blob with SQLITE_TRANSIENT (safe default)
/// Centralized UUID binding to prevent byte order inconsistencies.
public func bindUUID(_ stmt: OpaquePointer?, _ index: Int32, _ uuid: UUID, category: String = "SQLite") {
    let uuidData = withUnsafeBytes(of: uuid) { Data($0) }
    let hex = uuidData.map { String(format: "%02x", $0) }.joined()
    fputs("[SQLitePolicy] Binding UUID \(uuid) as TRANSIENT blob: \(hex)\n", stderr)
    _ = uuidData.withUnsafeBytes { bytes in
        sqlite3_bind_blob(stmt, index, bytes.baseAddress, Int32(uuidData.count), unsafeBitCast(-1, to: sqlite3_destructor_type.self))
    }
}

// MARK: - Dangerous Static API (Explicit Opt-In)

/// DANGEROUS: Binds text with SQLITE_STATIC (requires manual lifetime management)
/// Only use this if you absolutely know that data outlives the statement.
/// This function is intentionally named to scare developers.
public func bindTextDangerouslyWithStaticLifetime(_ stmt: OpaquePointer?, _ index: Int32, _ text: String, category: String = "SQLite") {
    fputs("[SQLitePolicy] ⚠️ DANGER: Using SQLITE_STATIC - ensure '\(text.prefix(20))...' outlives statement!\n", stderr)
    sqlite3_bind_text(stmt, index, text, -1, nil) // SQLITE_STATIC
}

/// DANGEROUS: Binds blob with SQLITE_STATIC (requires manual lifetime management)
/// Only use this if you absolutely know that data outlives the statement.
/// This function is intentionally named to scare developers.
public func bindBlobDangerouslyWithStaticLifetime(_ stmt: OpaquePointer?, _ index: Int32, _ data: Data, category: String = "SQLite") {
    fputs("[SQLitePolicy] ⚠️ DANGER: Using SQLITE_STATIC - ensure \(data.count) bytes outlives statement!\n", stderr)
    _ = data.withUnsafeBytes { bytes in
        sqlite3_bind_blob(stmt, index, bytes.baseAddress, Int32(data.count), nil) // SQLITE_STATIC
    }
}

// MARK: - Internal Destructor

/// SQLite TRANSIENT destructor shim for Swift compatibility.
/// Makes a copy of the data, safe with Swift's automatic memory management.
public let sqliteTransientDestructor: sqlite3_destructor_type = unsafeBitCast(
    UnsafeMutableRawPointer(bitPattern: -1),
    to: (@convention(c) (UnsafeMutableRawPointer?) -> Void).self
)
