import Foundation
import HiliteCore

public protocol PendingUploadsService {
    func loadAllWithOnSuccess(_ onSuccess: ((Array<PendingUpload>!)->()), onError: ((NSError!)->()))
    func addPendingUpload(_:PendingUpload)
    func savePendingUploads(_ pendingUploads: Array<PendingUpload>) -> Bool
    func clearPendingUploads()
    func clearPendingUploadsJson()
    func savePendingUpload(_ pendingUpload: PendingUpload!)
    func cancelLoading()
    func completeUpload(_ pendingUpload: PendingUpload)
    func removePendingUpload(_ pendingUpload: PendingUpload!)
}
