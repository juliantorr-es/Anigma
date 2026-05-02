import Foundation

// MARK: - FocusEngine
/// Manages interactive focus and mouse hit-testing
public actor FocusEngine {
    private var focusedComponentId: String?
    private var hitMap: [Rect: String] = [:]

    public func updateHitMap(_ map: [Rect: String]) {
        self.hitMap = map
    }

    public func component(at point: Point) -> String? {
        for (rect, id) in hitMap {
            if point.x >= rect.origin.x && point.x < rect.origin.x + rect.size.width &&
               point.y >= rect.origin.y && point.y < rect.origin.y + rect.size.height {
                return id
            }
        }
        return nil
    }
}
