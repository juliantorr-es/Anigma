import AnigmaPrimitives
import Foundation
import FoundationContracts

public struct NativeArtifactReference: Codable, Hashable, Sendable {
  public let artifactID: String
  public let contentHash: String
  public let byteRange: ByteRangeRef?
  public let page: Int?

  public init(
    artifactID: String,
    contentHash: String,
    byteRange: ByteRangeRef? = nil,
    page: Int? = nil
  ) {
    self.artifactID = artifactID
    self.contentHash = contentHash
    self.byteRange = byteRange
    self.page = page
  }
}

public struct HeavyComputeCapsuleInput: Codable, Sendable {
  public let source: NativeArtifactReference
  public let options: [String: String]

  public init(source: NativeArtifactReference, options: [String: String] = [:]) {
    self.source = source
    self.options = options
  }
}

public struct MathOCRResult: Codable, Sendable {
  public let expressions: [Expression]

  public init(expressions: [Expression]) {
    self.expressions = expressions
  }

  public struct Expression: Codable, Sendable {
    public let latex: String
    public let confidence: Double
    public let evidence: EvidenceRef

    public init(latex: String, confidence: Double, evidence: EvidenceRef) {
      self.latex = latex
      self.confidence = confidence
      self.evidence = evidence
    }
  }
}

public struct TableExtractionResult: Codable, Sendable {
  public let tables: [Table]

  public init(tables: [Table]) {
    self.tables = tables
  }

  public struct Table: Codable, Sendable {
    public let rows: Int
    public let columns: Int
    public let evidence: EvidenceRef

    public init(rows: Int, columns: Int, evidence: EvidenceRef) {
      self.rows = rows
      self.columns = columns
      self.evidence = evidence
    }
  }
}

public struct CitationExtractionResult: Codable, Sendable {
  public let citations: [Citation]

  public init(citations: [Citation]) {
    self.citations = citations
  }

  public struct Citation: Codable, Sendable {
    public let text: String
    public let normalizedReference: String?
    public let evidence: EvidenceRef

    public init(text: String, normalizedReference: String? = nil, evidence: EvidenceRef) {
      self.text = text
      self.normalizedReference = normalizedReference
      self.evidence = evidence
    }
  }
}

public enum HeavyComputeCapsuleContractSupport {
  public static func validate(source: NativeArtifactReference, codePrefix: String) throws {
    guard !source.artifactID.isEmpty else {
      throw ContractValidationError.missingField(
        code: "\(codePrefix).source.artifact_id.missing",
        message: "Heavy-compute capsule inputs must reference a source artifact."
      )
    }
    guard !source.contentHash.isEmpty else {
      throw ContractValidationError.missingField(
        code: "\(codePrefix).source.content_hash.missing",
        message: "Heavy-compute capsule inputs must carry a source content hash."
      )
    }
  }

  public static func packReference(
    _ source: NativeArtifactReference,
    kind: NativeRecordKind
  ) throws -> BinaryEnvelope {
    var data = Data()
    try NativeWire.append(source.artifactID, to: &data)
    try NativeWire.append(source.contentHash, to: &data)
    NativeWire.append(Int64(source.byteRange?.start ?? -1), to: &data)
    NativeWire.append(Int64(source.byteRange?.length ?? -1), to: &data)
    NativeWire.append(Int32(source.page ?? -1), to: &data)

    return BinaryEnvelope(
      header: RecordHeader(kind: kind, byteLength: UInt32(data.count)),
      payload: data
    )
  }

  public static func unavailableExecution<T>(
    contractID: ContractID,
    runID: String,
    sessionID: String,
    executor: String,
    output: T.Type
  ) async throws -> ArtifactEnvelope<T> {
    throw ContractExecutionError.underlying(
      code: "\(contractID.name).native_executor.unavailable",
      message: "Heavy-compute capsule contract requires a native executor boundary."
    )
  }
}

public enum MathOCRCapsuleContract: NativeBoundaryContract {
  public typealias Input = HeavyComputeCapsuleInput
  public typealias Output = MathOCRResult

  public static let id = ContractID(
    name: "capsule.math-ocr.native", major: 1, minor: 0, schemaHash: "v1")
  public static let inputSchemaVersion = 1
  public static let outputSchemaVersion = 1
  public static let nativeRecordKind = NativeRecordKind.mathOCRRequest
  public static let preferredLane = HardwareLane.perception

  public static func validate(output: ArtifactEnvelope<Output>) throws {
    guard
      output.payload.expressions.allSatisfy({
        !$0.latex.isEmpty && (0.0...1.0).contains($0.confidence)
      })
    else {
      throw ContractValidationError.invalidSchema(
        code: "math_ocr.output.invalid_expression",
        message: "Math OCR output expressions require LaTeX and normalized confidence."
      )
    }
  }

  public static func execute(input: ArtifactEnvelope<Input>, ctx: ContractContext) async throws
    -> ArtifactEnvelope<Output>
  {
    try HeavyComputeCapsuleContractSupport.validate(
      source: input.payload.source, codePrefix: "math_ocr")
    return try await HeavyComputeCapsuleContractSupport.unavailableExecution(
      contractID: id,
      runID: ctx.runID,
      sessionID: ctx.sessionID,
      executor: ctx.executorIdentity,
      output: Output.self
    )
  }

  public static func packNative(input: ArtifactEnvelope<Input>) throws -> BinaryEnvelope {
    try HeavyComputeCapsuleContractSupport.validate(
      source: input.payload.source, codePrefix: "math_ocr")
    return try HeavyComputeCapsuleContractSupport.packReference(
      input.payload.source, kind: nativeRecordKind)
  }

  public static func unpackNative(envelope: BinaryEnvelope) throws -> ArtifactEnvelope<Output> {
    throw NativeWireError.kindMismatch
  }
}

public enum TableExtractionCapsuleContract: NativeBoundaryContract {
  public typealias Input = HeavyComputeCapsuleInput
  public typealias Output = TableExtractionResult

  public static let id = ContractID(
    name: "capsule.table-extraction.native", major: 1, minor: 0, schemaHash: "v1")
  public static let inputSchemaVersion = 1
  public static let outputSchemaVersion = 1
  public static let nativeRecordKind = NativeRecordKind.tableExtractionRequest
  public static let preferredLane = HardwareLane.perception

  public static func validate(output: ArtifactEnvelope<Output>) throws {
    guard output.payload.tables.allSatisfy({ $0.rows > 0 && $0.columns > 0 }) else {
      throw ContractValidationError.invalidSchema(
        code: "table_extraction.output.invalid_table",
        message: "Extracted tables require positive row and column counts."
      )
    }
  }

  public static func execute(input: ArtifactEnvelope<Input>, ctx: ContractContext) async throws
    -> ArtifactEnvelope<Output>
  {
    try HeavyComputeCapsuleContractSupport.validate(
      source: input.payload.source, codePrefix: "table_extraction")
    return try await HeavyComputeCapsuleContractSupport.unavailableExecution(
      contractID: id,
      runID: ctx.runID,
      sessionID: ctx.sessionID,
      executor: ctx.executorIdentity,
      output: Output.self
    )
  }

  public static func packNative(input: ArtifactEnvelope<Input>) throws -> BinaryEnvelope {
    try HeavyComputeCapsuleContractSupport.validate(
      source: input.payload.source, codePrefix: "table_extraction")
    return try HeavyComputeCapsuleContractSupport.packReference(
      input.payload.source, kind: nativeRecordKind)
  }

  public static func unpackNative(envelope: BinaryEnvelope) throws -> ArtifactEnvelope<Output> {
    throw NativeWireError.kindMismatch
  }
}

public enum CitationExtractionCapsuleContract: NativeBoundaryContract {
  public typealias Input = HeavyComputeCapsuleInput
  public typealias Output = CitationExtractionResult

  public static let id = ContractID(
    name: "capsule.citation-extraction.native", major: 1, minor: 0, schemaHash: "v1")
  public static let inputSchemaVersion = 1
  public static let outputSchemaVersion = 1
  public static let nativeRecordKind = NativeRecordKind.citationExtractionRequest
  public static let preferredLane = HardwareLane.perception

  public static func validate(output: ArtifactEnvelope<Output>) throws {
    guard output.payload.citations.allSatisfy({ !$0.text.isEmpty }) else {
      throw ContractValidationError.invalidSchema(
        code: "citation_extraction.output.invalid_citation",
        message: "Extracted citations require non-empty citation text."
      )
    }
  }

  public static func execute(input: ArtifactEnvelope<Input>, ctx: ContractContext) async throws
    -> ArtifactEnvelope<Output>
  {
    try HeavyComputeCapsuleContractSupport.validate(
      source: input.payload.source, codePrefix: "citation_extraction")
    return try await HeavyComputeCapsuleContractSupport.unavailableExecution(
      contractID: id,
      runID: ctx.runID,
      sessionID: ctx.sessionID,
      executor: ctx.executorIdentity,
      output: Output.self
    )
  }

  public static func packNative(input: ArtifactEnvelope<Input>) throws -> BinaryEnvelope {
    try HeavyComputeCapsuleContractSupport.validate(
      source: input.payload.source, codePrefix: "citation_extraction")
    return try HeavyComputeCapsuleContractSupport.packReference(
      input.payload.source, kind: nativeRecordKind)
  }

  public static func unpackNative(envelope: BinaryEnvelope) throws -> ArtifactEnvelope<Output> {
    throw NativeWireError.kindMismatch
  }
}
