import SwiftUI
import MetalKit
import PlatformAdapters
import RuntimeOrchestrator

// MARK: - Canvas Controller

@MainActor
public class CanvasController: ObservableObject {
    public let orchestrator: RuntimeOrchestrator
    public let renderer: MetalRenderAdapter
    @Published var lastFrameData: Data?
    private var isTicking = false
    
    public init() throws {
        self.orchestrator = try RuntimeOrchestrator()
        
        guard let device = MTLCreateSystemDefaultDevice(),
              let adapter = MetalRenderAdapter(device: device) else {
            throw NSError(domain: "AnigmaUI", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to initialize Metal"])
        }
        self.renderer = adapter
    }
    
    func tick() async {
        guard !isTicking else { return }
        isTicking = true
        defer { isTicking = false }
        
        do {
            let data = try await orchestrator.frameTick()
            self.lastFrameData = data
        } catch {
            print("Frame tick failed: \(error)")
        }
    }
}

// MARK: - Metal View Representable

struct CanvasViewRepresentable: NSViewRepresentable {
    let renderer: MetalRenderAdapter
    @Binding var frameData: Data?
    
    func makeNSView(context: Context) -> MTKView {
        let mtkView = MTKView()
        mtkView.device = MTLCreateSystemDefaultDevice()
        mtkView.delegate = context.coordinator
        mtkView.framebufferOnly = false
        mtkView.enableSetNeedsDisplay = false 
        mtkView.isPaused = false
        mtkView.clearColor = MTLClearColor(red: 0.05, green: 0.05, blue: 0.05, alpha: 1.0)
        return mtkView
    }
    
    func updateNSView(_ nsView: MTKView, context: Context) {
        context.coordinator.frameData = frameData
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(renderer: renderer)
    }
    
    class Coordinator: NSObject, MTKViewDelegate {
        let renderer: MetalRenderAdapter
        var frameData: Data?
        
        init(renderer: MetalRenderAdapter) {
            self.renderer = renderer
        }
        
        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
        
        func draw(in view: MTKView) {
            guard let data = frameData, !data.isEmpty,
                  let drawable = view.currentDrawable,
                  let descriptor = view.currentRenderPassDescriptor else {
                return
            }
            
            renderer.execute(
                renderPlanData: data,
                renderPassDescriptor: descriptor,
                drawable: drawable,
                viewportSize: view.drawableSize,
                textures: []
            )
        }
    }
}

// MARK: - Container View

public struct RuntimeCanvasContainerView: View {
    @StateObject private var controller: CanvasController
    
    public init(controller: CanvasController) {
        _controller = StateObject(wrappedValue: controller)
    }
    
    public var body: some View {
        TimelineView(.animation(minimumInterval: 1.0/120.0, paused: false)) { timeline in
            CanvasViewRepresentable(
                renderer: controller.renderer,
                frameData: $controller.lastFrameData
            )
            .onChange(of: timeline.date) { _, _ in
                Task {
                    await controller.tick()
                }
            }
        }
        .overlay(
            VStack {
                HStack {
                    Text("Engine Active (120fps)")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .padding(4)
                        .background(Color.green.opacity(0.2))
                        .cornerRadius(4)
                    Spacer()
                }
                Spacer()
            }
            .padding()
        )
    }
}
