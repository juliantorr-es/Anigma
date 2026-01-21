//
//  SidecarPDFService.swift
//  SidecarPDFService
//
//  Heavy PDF operations (MuPDF).
//

import Foundation

public protocol PDFMutator {
    func merge(pdfs: [Data]) throws -> Data
    func split(pdf: Data, at page: Int) throws -> (Data, Data)
}

public class NativePDFService: PDFMutator {
    public init() {}

    public func merge(pdfs: [Data]) throws -> Data {
        return Data()
    }

    public func split(pdf: Data, at page: Int) throws -> (Data, Data) {
        return (Data(), Data())
    }
}
