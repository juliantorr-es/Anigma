//
//  DocumentIRKit.swift
//  DocumentIRKit
//
//  Canonical intermediate representation for documents.
//

import Foundation

public protocol DocumentIRProvider {
    func snapshot() -> Data
}
