import Foundation
import HiliteCore

public protocol FeedAgent {
    func numberOfFeedItems() -> Int
    func feedItemAgentAtIndexPath(_ indexPath: IndexPath) -> FeedItemAgent?
    func reloadWithOnSuccess(_ onSuccess: @escaping (Array<FeedItemAgent>)->(), onError: @escaping (Error!)->())
    func selectFeedItemAgent(_ feedItemAgent: FeedItemAgent!, presentFrom: PresentFrom?)
    func canHandleFeedItemAgent(_ feedItemAgent: FeedItemAgent!) -> Bool
    func cancelLoading()
    func feedItemIsDisplayable(_ feedItemAgent: FeedItemAgent!) -> Bool
    func withFeedItemAgents(_ withBlock: @escaping (Array<FeedItemAgent>!)->())
    func isEmpty() -> Bool
    func numberOfDisplayableFeedItems() -> Int
}
