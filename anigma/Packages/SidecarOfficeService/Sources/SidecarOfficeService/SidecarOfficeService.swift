//
//  SidecarOfficeService.swift
//  SidecarOfficeService
//
//  High-fidelity Office engine integration (running in Sidecar).
//

import Foundation
import AnigmaNativeShims

public protocol OfficeEngine {
    func convert(document: Data, to format: String) throws -> Data
    func renderPage(document: Data, page: Int) throws -> Data
}

public enum SidecarOfficeServiceError: Error, LocalizedError {
    case conversionUnavailable(format: String)
    case renderUnavailable(page: Int)

    public var errorDescription: String? {
        switch self {
        case let .conversionUnavailable(format):
            return "Office document conversion to \(format) is not implemented in SidecarOfficeService."
        case let .renderUnavailable(page):
            return "Office document rendering for page \(page) is not implemented in SidecarOfficeService."
        }
    }
}

public class NativeOfficeService: OfficeEngine {
    // In real implementation, this wraps LibreOfficeKit via C shim
    public init() {}

    public func convert(document: Data, to format: String) throws -> Data {
        throw SidecarOfficeServiceError.conversionUnavailable(format: format)
    }

    public func renderPage(document: Data, page: Int) throws -> Data {
        throw SidecarOfficeServiceError.renderUnavailable(page: page)
    }
}
