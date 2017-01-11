import Foundation
import HiliteCore

public protocol TaskService {
    func loadTasks(_ onSuccess: @escaping (Array<Task>)->Void, onError: (Error)->Void)
    func cancelLoading()
    func loadTask(_ taskId: String!, onSuccess: @escaping (Task?)->(), onError: (Error!)->())
}
