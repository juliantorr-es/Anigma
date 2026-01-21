import Foundation
import MCP
import AnigmaPrimitives

public final class AnigmaMCPBridge {
    public init() {}

    public func getTools() -> [MCP.Tool] {
        let registry = ToolRegistry.shared
        return registry.allContracts().values.map { contract in
            MCP.Tool(
                name: contract.toolName,
                description: contract.toolDescription,
                inputSchema: .object([:]) // Simplified for now
            )
        }
    }
}
