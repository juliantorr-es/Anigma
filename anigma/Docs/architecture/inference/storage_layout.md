# Storage Layout

Artifacts MUST reside in content-addressed storage with stable directory structure. Names may be friendly, but identity is the artifact hash.

Example layout:

```
Artifacts/Inference/<artifact_type>/<artifact_hash>/payload.bin
Artifacts/Inference/<artifact_type>/<artifact_hash>/meta.json
```

For chunked payloads:

```
Artifacts/Inference/<artifact_type>/<artifact_hash>/chunks/<chunk_index>.bin
Artifacts/Inference/<artifact_type>/<artifact_hash>/chunks/manifest.json
```

Lookup indexes mapping `(model_id, input_hash, params_hash)` to `artifact_hash` MAY exist but MUST be rebuildable and treated as cache artifacts themselves.

Backends MAY store temporary files for acceleration, but only artifacts that comply with the envelope (meta.json) and hashing contracts can be reused beyond the current session.
