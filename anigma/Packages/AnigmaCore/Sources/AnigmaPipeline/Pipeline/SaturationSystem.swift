import Foundation
import AnigmaPrimitives
import FoundationContracts
import ContractsCore
import MediaPipelineContracts
import AnigmaFoundation

/// System that orchestrates media transformation through the SaturationSubstrate.
public actor SaturationSystem: AsyncSystem {
    private let substrate: any SaturationSubstrateProtocol

    public nonisolated var name: String { "SaturationSystem" }

    public init(substrate: any SaturationSubstrateProtocol) {
        self.substrate = substrate
    }

    public func update(world: World) async throws {
        let entities = await world.entitiesWith(MediaFabricComponent.self)

        for entity in entities {
            guard let component = await world.getComponent(entity, MediaFabricComponent.self) else { continue }

            let contract = VideoScaleContract(
                sourceFrame: FrameReference(
                    token: SurfaceToken(),
                    width: component.surface.width,
                    height: component.surface.height,
                    format: "bgra"
                ),
                targetWidth: component.surface.width,
                targetHeight: component.surface.height
            )

            let result = try await substrate.process(
                surface: component.surface,
                lane: component.lane,
                contract: contract
            )

            await world.addComponent(entity, MediaFabricComponent(surface: result, lane: component.lane))
        }
    }
}
