import Foundation

@resultBuilder
public struct TUIBuilder {
    public static func buildBlock(_ components: [Renderable]...) -> [Renderable] {
        components.flatMap { $0 }
    }

    public static func buildExpression(_ expression: Renderable) -> [Renderable] {
        [expression]
    }

    public static func buildExpression(_ expression: [Renderable]) -> [Renderable] {
        expression
    }

    public static func buildOptional(_ component: [Renderable]?) -> [Renderable] {
        component ?? []
    }

    public static func buildEither(first component: [Renderable]) -> [Renderable] {
        component
    }

    public static func buildEither(second component: [Renderable]) -> [Renderable] {
        component
    }

    public static func buildArray(_ components: [[Renderable]]) -> [Renderable] {
        components.flatMap { $0 }
    }
}
