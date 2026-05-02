import Testing
import Foundation
import ContractsCore

@Suite("NativeWire RecordHeader serialization")
struct NativeWireRecordHeaderTests {
  @Test("RecordHeader serialized byte length and offsets are stable")
  func recordHeaderSerializedLayoutIsStable() throws {
    let header = RecordHeader(
      version: 0x1234,
      kind: .citationExtractionResponse,
      byteLength: 0x0102_0304,
      flags: 0x0506_0708,
      checksum: 0x0A0B_0C0D
    )

    let serialized = header.serializedData()
    #expect(serialized.count == RecordHeader.serializedByteCount)
    #expect(Array(serialized[0..<4]) == [0x41, 0x49, 0x4E, 0x47]) // magic
    #expect(Array(serialized[4..<6]) == [0x34, 0x12]) // version
    #expect(Array(serialized[6..<8]) == [0x05, 0x01]) // kind
    #expect(Array(serialized[8..<12]) == [0x04, 0x03, 0x02, 0x01]) // byteLength
    #expect(Array(serialized[12..<16]) == [0x08, 0x07, 0x06, 0x05]) // flags
    #expect(Array(serialized[16..<20]) == [0x0D, 0x0C, 0x0B, 0x0A]) // checksum
  }

  @Test("BinaryEnvelope serialization uses exact 20-byte header without padding")
  func binaryEnvelopeHeaderIsNotPadded() {
    let header = RecordHeader(kind: .mlWorkerEmbedRequest, byteLength: 3, checksum: 0x1122_3344)
    let payload = Data([0xAA, 0xBB, 0xCC])
    let envelope = BinaryEnvelope(header: header, payload: payload)

    let serialized = envelope.serialize()
    #expect(serialized.count == RecordHeader.serializedByteCount + payload.count)
    #expect(Data(serialized.prefix(RecordHeader.serializedByteCount)) == header.serializedData())
    #expect(Data(serialized.suffix(payload.count)) == payload)
  }

  @Test("RecordHeader decoding reads deterministic little-endian offsets")
  func recordHeaderDeserializeRoundTrip() throws {
    let bytes = Data([
      0x41, 0x49, 0x4E, 0x47, // magic
      0x02, 0x00, // version
      0x03, 0x00, // kind
      0x10, 0x00, 0x00, 0x00, // byteLength
      0x01, 0x00, 0x00, 0x00, // flags
      0xAA, 0xBB, 0xCC, 0xDD, // checksum
    ])
    let header = try RecordHeader(serializedData: bytes)

    #expect(header.magic == RecordHeader.magicValue)
    #expect(header.version == 2)
    #expect(header.kind == NativeRecordKind.mlWorkerEmbedRequest.rawValue)
    #expect(header.byteLength == 16)
    #expect(header.flags == 1)
    #expect(header.checksum == 0xDDCC_BBAA)
  }
}
