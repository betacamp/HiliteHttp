import Foundation
import HiliteCore

public protocol FeedAgentDelegate {
    func feedAgent(_ feedAgent: FeedAgent, didSelectFeedItemAgent: FeedItemAgent, presentFrom: PresentFrom?)
}
