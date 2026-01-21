//
//  SidecarOfficeService.swift
//  SidecarOfficeService
//
//  High-fidelity Office engine integration (running in Sidecar).
//

import Foundation

public protocol OfficeEngine {
    func convert(document: Data, to format: String) throws -> Data
    func renderPage(document: Data, page: Int) throws -> Data
}

public class NativeOfficeService: OfficeEngine {
    // In real implementation, this wraps LibreOfficeKit via C shim
    public init() {}

    public func convert(document: Data, to format: String) throws -> Data {
        // Placeholder
        return Data()
    }

    public func renderPage(document: Data, page: Int) throws -> Data {
        // Placeholder
        return Data()
    }
}
