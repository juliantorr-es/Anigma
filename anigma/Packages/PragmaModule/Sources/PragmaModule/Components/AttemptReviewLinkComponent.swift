import AnigmaPrimitives

import AnigmaPrimitives

//
//  AttemptReviewLinkComponent.swift
//  PragmaModule
//
//  Component linking a comment to an attempt review.
//

import Foundation
import AnigmaCore

/// Component linking a comment to an attempt review.
public struct AttemptReviewLinkComponent: Component, Codable {
    /// Attempt referenced by this review comment.
    public let attemptId: AttemptId

    /// Optional file path for the review comment.
    public let filePath: String?

    /// Optional line number for the review comment.
    public let line: Int?

    public init(attemptId: AttemptId, filePath: String? = nil, line: Int? = nil) {
        self.attemptId = attemptId
        self.filePath = filePath
        self.line = line
    }
}
