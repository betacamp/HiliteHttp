import Foundation
import HiliteCore

public protocol TasksAgentDelegate {
    func taskAgent(_ taskAgent: TaskFeedAgent, didSelectTask: Task, presentFrom: PresentFrom?)
}
