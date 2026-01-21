//
//  SwiftTestTool.swift
//  HarmoniaModule
//
//  Governed swift_test tool that delegates to the enhanced test runner.
//

import AnigmaPrimitives
import Foundation

public struct SwiftTestTool: Sendable {
    public init() {}

    public func execute(_ request: ToolCallRequest, session: SessionContext) async
        -> ToolCallResponse {
        let enhanced = EnhancedSwiftTestTool()
        return await enhanced.execute(request, session: session)
    }
}
