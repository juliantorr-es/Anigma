import Foundation
import AnigmaNativeShims
import CapsuleCore

internal final class VizAggregationCapsuleWrapper {
    private let handle: CapsuleHandle<AnyObject>?
    
    init() throws {
        var rawHandle: anigma_viz_aggregation_capsule_t?
        var error = anigma_capsule_error_t()
        
        let status = anigma_viz_aggregation_capsule_create(&rawHandle, &error)
        guard status == ANIGMA_OK, let finalHandle = rawHandle else {
            throw CapsuleError(status: status, error: error)
        }
        
        self.handle = CapsuleHandle<AnyObject>(
            rawHandle: finalHandle,
            destroyFunction: { ptr, err in
                anigma_viz_aggregation_capsule_destroy(ptr, err)
            }
        )
    }
}

public struct DatasetHandle {
    let raw: anigma_viz_dataset_t
    
    init(raw: anigma_viz_dataset_t) {
        self.raw = raw
    }
}

public struct ColumnView {
    public let name: String
    public let type: ScalarType
    public let data: Data
    public let elementCount: Int
    public let nullBitmap: Data?
}

public enum ScalarType {
    case int64
    case uint64
    case float64
    case float32
    case bool
    case timestampMsUtc
    case stringUtf8
    
    func toCType() -> anigma_viz_scalar_type_t {
        switch self {
        case .int64: return ANIGMA_VIZ_SCALAR_I64
        case .uint64: return ANIGMA_VIZ_SCALAR_U64
        case .float64: return ANIGMA_VIZ_SCALAR_F64
        case .float32: return ANIGMA_VIZ_SCALAR_F32
        case .bool: return ANIGMA_VIZ_SCALAR_BOOL
        case .timestampMsUtc: return ANIGMA_VIZ_SCALAR_TIMESTAMP_MS_UTC
        case .stringUtf8: return ANIGMA_VIZ_SCALAR_STRING_UTF8
        }
    }
}
