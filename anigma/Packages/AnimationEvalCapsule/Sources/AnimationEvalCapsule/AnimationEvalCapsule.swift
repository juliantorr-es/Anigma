import Foundation
import AnigmaNativeShims
import AnigmaPrimitives
import CapsuleCore

/// High-level interface for animation evaluation.
public final class AnimationEvalCapsule {
    private var arena: CapsuleHandle<AnyObject>?
    
    // Animation Eval often works on state objects.
    // We can provide methods to evaluate tracks or timelines.
    
    public init() {
        // Setup arena if needed
    }
    
    // TODO: Implement high-level animation evaluation
    // anigma_animation_evaluate
    // anigma_timeline_evaluate
    
    public func evaluate(track: AnimationTrack, time: TimeTick) -> PropertyValue? {
        // Wrap C call
        return nil
    }
}

public typealias TimeTick = Int64

public struct AnimationTrack {
    // ...
}

public struct PropertyValue {
    // ...
}
