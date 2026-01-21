# Minimal Vertical Slice: Acceptance Spec

This spec defines the minimal vertical slice required for anigmad to be considered operational.

## Preconditions

The daemon runs per-user and exposes gRPC over UDS by default. The socket path is deterministic and discoverable by the CLI.

## Steps and Required Evidence

1) Start daemon.
Evidence: HealthCheck returns ok=true and includes api_version.

2) Open session.
Evidence: OpenSession returns client_id, capability_token, expires_unix_ms, and granted scopes.

3) Ingest artifact.
Action: IngestArtifact uploads bytes for a small text file.
Evidence: IngestResponse returns ArtifactRef(hash, media_type, size_bytes) and a receipt_hash.

4) Submit job artifact.copy.
Action: SubmitJob uses the ingested artifact as input and a config that specifies a no-op copy output.
Evidence: SubmitJobResponse returns job_id and a receipt_hash for scheduling decision.

5) Observe job completion.
Action: GetJobStatus until terminal or StreamJobEvents to terminal.
Evidence: terminal status includes outputs and final_receipt_hash.

6) Retrieve output artifact.
Action: RetrieveArtifact by hash and read streamed bytes.
Evidence: bytes match the original input bytes.

7) Verify receipt chain.
Action: VerifyChain with head_receipt_hash = final_receipt_hash.
Evidence: VerifyChainResponse ok=true.

8) Restart daemon and re-verify.
Action: stop daemon, start daemon, VerifyChain again.
Evidence: VerifyChainResponse ok=true and receipts remain retrievable by hash.

## Failure Handling Requirements

If any step fails, the daemon must return an ErrorStatus and must emit a failure receipt when the failure is execution-related. Worker crashes must not crash the daemon.
