import Foundation

/// Immutable feedback record for a specific run or receipt.
/// Phase 5: Honest feedback loops with explicit provenance.
public struct FeedbackVoteComponent: Codable, Hashable, Sendable {
    public let voteID: UUID
    public let receiptID: String
    public let runID: UUID?
    public let rating: Rating
    public let actorID: String
    public let surfaceID: String?
    public let timestamp: Date
    public let comment: String?

    public enum Rating: String, Codable, Sendable {
        case good
        case bad
        case excellent
        case poor
    }

    public init(
        voteID: UUID = UUID(),
        receiptID: String,
        runID: UUID? = nil,
        rating: Rating,
        actorID: String,
        surfaceID: String? = nil,
        timestamp: Date = Date(),
        comment: String? = nil
    ) {
        self.voteID = voteID
        self.receiptID = receiptID
        self.runID = runID
        self.rating = rating
        self.actorID = actorID
        self.surfaceID = surfaceID
        self.timestamp = timestamp
        self.comment = comment
    }
}
