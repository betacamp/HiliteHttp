import Foundation
import HiliteCore

public protocol FiltersByFeedAgent: FeedAgent {
    func filterByFeedAgent(_ feedAgent: FeedAgent!)
}
