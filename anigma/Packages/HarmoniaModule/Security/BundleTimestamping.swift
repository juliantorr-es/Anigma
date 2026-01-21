//
//  BundleTimestamping.swift
//  HarmoniaModule
//
//  Protocol surface for bundle timestamping implementations.
//

import Foundation

/// Abstraction for emitting timestamp claims for exported bundles.
public protocol BundleTimestamping: Sendable {
    func timestampBundleExport(
        bundleId: String,
        bundleHash: String,
        exportPath: String,
        timestampingLevel: TimestampingLevel,
        legalHoldReference: String?,
        retentionPeriod: Int?
    ) async throws -> BundleTimestampClaim
}

extension TrustedTimestampingSystem: BundleTimestamping {}
