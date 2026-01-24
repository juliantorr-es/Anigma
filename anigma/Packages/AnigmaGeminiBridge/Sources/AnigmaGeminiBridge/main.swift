import Hummingbird
import Foundation
import NIOCore

@main
struct AnigmaGeminiBridge {
    static func main() async throws {
        // Parse command line arguments
        var port = 8080
        if let portIndex = CommandLine.arguments.firstIndex(of: "--port"),
           CommandLine.arguments.count > portIndex + 1,
           let portArg = Int(CommandLine.arguments[portIndex + 1]) {
            port = portArg
        }

        let router = Router<BasicRequestContext>()
        let mcpClient = MCPClient.shared

        // Health endpoint
        router.get("/health") { _, _ -> [String: String] in
            return ["status": "healthy", "message": "Anigma Gemini Bridge running"]
        }

        // List tools endpoint
        router.get("/v1/tools") { _, _ -> [String: AnyCodable] in
            do {
                return try await mcpClient.listTools()
            } catch {
                return ["error": AnyCodable("\(error)")]
            }
        }

        // Tool execution endpoint
        router.post("/v1/tools/call") { request, _ -> [String: AnyCodable] in
            do {
                // Decode request body
                let bodyBuffer = try await request.body.collect(upTo: 1024 * 1024) // 1MB max

                // HB2 ByteBuffer conversion
                let data = Data(buffer: bodyBuffer)

                guard let requestDict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                        return ["error": AnyCodable("Invalid JSON body")]
                }

                guard let toolName = requestDict["name"] as? String else {
                    return ["error": AnyCodable("Missing 'name' field")]
                }

                let argsDict = (requestDict["arguments"] as? [String: Any]) ?? [:]
                var args: [String: AnyCodable] = [:]
                for (key, value) in argsDict {
                    args[key] = AnyCodable(value)
                }

                return try await mcpClient.callTool(name: toolName, arguments: args)
            } catch {
                return ["error": AnyCodable("\(error)")]
            }
        }

        // Metrics endpoint
        router.get("/metrics") { _, _ -> [String: AnyCodable] in
            return [
                "status": AnyCodable("running")
            ]
        }

        let app = Application(
            router: router,
            configuration: .init(address: .hostname("127.0.0.1", port: port))
        )

        print("🌍 Anigma Gemini Bridge starting on http://127.0.0.1:\(port)...")
        try await app.runService()
    }
}
