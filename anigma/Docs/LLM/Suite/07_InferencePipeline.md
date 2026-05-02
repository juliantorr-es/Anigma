# 07: Inference Pipeline: Implementation
- **Adapter**: Uses `InferencePlaneAdapter` to translate ECS system requests into core ML / ANE tensors.
- **Buffers**: Inference nodes operate directly on pinned memory surfaces defined in `MediaSurface`.
- **Pipeline Nodes**: System systems iterate over entities with `InferenceComponent`, orchestrating ANE execution via `SaturationSubstrate`.
