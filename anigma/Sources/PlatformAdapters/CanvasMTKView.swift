import MetalKit

public final class CanvasMTKView: MTKView {
    public weak var delegateProxy: MTKViewDelegate? {
        get { return self.delegate }
        set { self.delegate = newValue }
    }
}
