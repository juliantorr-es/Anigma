import Testing
@testable import RenderPlanCapsule

struct RenderPlanTests {
    @Test func testAppIntegration() {
        let app = RenderPlanApp()
        #expect(app.isValid)
    }

    @Test func testTextRenderer() {
        let renderer = TextRenderer()
        #expect(renderer.isReady)
    }
}
