import Foundation
import HiliteCore

open class TaskBackedFeedItemAgent: FeedItemAgent {
    public let task: Task!

    public init(task: Task!) {
        self.task = task
    }
    
    public func type() -> FeedItemAgentType! {
        return FeedItemAgentType.task
    }
    
    public func uniqueIdentifier() -> String! {
        return task.id()
    }
    
}
