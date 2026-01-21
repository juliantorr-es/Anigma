import Foundation

@available(macOS 13.0, *)
public actor ModelManagementUI {
    private let modelsPath: String

    public init(modelsPath: String) {
        self.modelsPath = modelsPath
    }

    public func show() async throws {
        print("🤖 Model Management UI - Coming soon!")
        print("Models path: \(modelsPath)")
    }
}
