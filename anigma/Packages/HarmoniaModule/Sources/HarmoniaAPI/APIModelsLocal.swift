import Foundation
import HarmoniaAPIContracts

// Public APIResponse alias that re-exports the contracts-layer envelope.
public typealias APIResponse<T: Codable & Sendable> = HarmoniaAPIContracts.APIResponse<T>

// HTTP status codes are represented as Ints in APIError.statusCode.
// This file intentionally avoids redefining HTTPStatusCode to prevent conflicts
// with internal contracts-layer utilities.
