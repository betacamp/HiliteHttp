import Foundation
import HiliteCore

public protocol TaskAgentDelegate {
    func taskAgentWantsToLaunchRecorder(_ taskAgent: TaskAgent, presentFrom: PresentFrom)
}
