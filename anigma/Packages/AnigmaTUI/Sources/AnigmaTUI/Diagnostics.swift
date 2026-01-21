import Foundation

// MARK: - DebugHUD
public struct DebugHUD: Renderable {
    public var fps: Double
    public var memoryUsageMB: Double
    public var dirtyRegionsCount: Int

    public func render(in frame: Rect, to buffer: TerminalBuffer) {
        let text = "FPS: \(String(format: "%.1f", fps)) | MEM: \(String(format: "%.1f", memoryUsageMB))MB | DIRTY: \(dirtyRegionsCount)"
        let hudRect = Rect(x: 0, y: 0, width: text.count, height: 1)
        Text(text, foreground: .black, background: .brightYellow).render(in: hudRect, to: buffer)
    }
}
