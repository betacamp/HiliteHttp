import Foundation

public protocol FeedItemAgent {
    func uniqueIdentifier() -> String!
    func type() -> FeedItemAgentType!
}

public enum FeedItemAgentType {
    case pendingUpload, task
}
