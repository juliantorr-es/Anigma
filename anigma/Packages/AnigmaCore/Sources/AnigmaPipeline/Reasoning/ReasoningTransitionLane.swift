import Foundation
import SaturationKit

#if canImport(Metal)
import Metal
#endif

/// Heuristically prioritizes reasoning state transitions on the Metal lane when available.
struct ReasoningTransitionLane {
    #if canImport(Metal)
    private let metalLane: MetalTransitionLane?
    #endif

    init() {
        #if canImport(Metal)
        self.metalLane = MetalTransitionLane()
        #endif
    }

    func orderedTransitions(for puzzle: ReasoningPuzzle, state: AbstractState) async -> [AbstractTransition] {
        #if canImport(Metal)
        if let prioritized = await metalLane?.orderedTransitions(for: puzzle, state: state) {
            return prioritized
        }
        #endif

        return puzzle.transitions
    }
}

#if canImport(Metal)
private final class MetalTransitionLane {
    private let megakernel: MetalSaturatedSearchMegakernel
    private let loggingRing: SaturatedLoggingRing

    private let featureDimension = 4

    init?() {
        guard let device = MTLCreateSystemDefaultDevice(),
              let ring = try? SaturatedLoggingRing(capacity: 32, device: device),
              let kernel = try? MetalSaturatedSearchMegakernel(device: device) else {
            return nil
        }

        self.megakernel = kernel
        self.loggingRing = ring
    }

    func orderedTransitions(for puzzle: ReasoningPuzzle, state: AbstractState) async -> [AbstractTransition]? {
        guard puzzle.transitions.count >= 4 else { return nil }

        let query = queryVector(for: puzzle, state: state)
        let candidates = packedCandidateVectors(for: puzzle.transitions)

        guard let selectedIndices = try? await megakernel.search(
            query: query,
            candidates: candidates,
            dimension: featureDimension,
            threshold: 0.15,
            loggingRing: loggingRing
        ), !selectedIndices.isEmpty else {
            return nil
        }

        let selectedSet = Set(selectedIndices.map(Int.init))
        let prioritizedSelected = selectedIndices
            .compactMap { index -> (Int, Double, AbstractTransition)? in
                let intIndex = Int(index)
                guard puzzle.transitions.indices.contains(intIndex) else { return nil }
                let transition = puzzle.transitions[intIndex]
                return (intIndex, similarityScore(query: query, candidate: transitionVector(for: transition)), transition)
            }
            .sorted {
                if $0.1 == $1.1 { return $0.0 < $1.0 }
                return $0.1 > $1.1
            }
            .map(\.2)

        guard !prioritizedSelected.isEmpty else { return nil }

        let remainder = puzzle.transitions.enumerated().compactMap { selectedSet.contains($0.offset) ? nil : $0.element }
        return prioritizedSelected + remainder
    }

    private func queryVector(for puzzle: ReasoningPuzzle, state: AbstractState) -> [Float] {
        [
            Float(state.symbols.count),
            Float(puzzle.constraints.count),
            Float(state.edges.count),
            Float(puzzle.transitions.count)
        ]
    }

    private func transitionVector(for transition: AbstractTransition) -> [Float] {
        [
            Float(transition.preconditions.count),
            Float(transition.effects.count),
            Float(transition.cost),
            Float(transition.name.count)
        ]
    }

    private func packedCandidateVectors(for transitions: [AbstractTransition]) -> [Float] {
        var packed = Array(repeating: Float.zero, count: transitions.count * featureDimension)
        for (index, transition) in transitions.enumerated() {
            let vector = transitionVector(for: transition)
            for dimension in 0..<featureDimension {
                packed[dimension * transitions.count + index] = vector[dimension]
            }
        }
        return packed
    }

    private func similarityScore(query: [Float], candidate: [Float]) -> Double {
        var dotProduct: Double = 0
        var queryMagnitude: Double = 0
        var candidateMagnitude: Double = 0

        for (lhs, rhs) in zip(query, candidate) {
            let lhs = Double(lhs)
            let rhs = Double(rhs)
            dotProduct += lhs * rhs
            queryMagnitude += lhs * lhs
            candidateMagnitude += rhs * rhs
        }

        guard queryMagnitude > 0, candidateMagnitude > 0 else { return 0 }
        return dotProduct / (sqrt(queryMagnitude) * sqrt(candidateMagnitude))
    }
}
#endif
