//
//  SidecarTranslateService.swift
//  SidecarTranslateService
//
//  Neural Machine Translation (Marian NMT).
//

import Foundation
import AnigmaNativeShims

public protocol Translator {
    func translate(text: String, sourceLang: String, targetLang: String) throws -> String
}

public class NativeTranslateService: Translator {
    public init() {}

    public func translate(text: String, sourceLang: String, targetLang: String) throws -> String {
        return "Translated: " + text
    }
}
