import Foundation
import HiliteCore

public protocol UploadService {
    func initiateUploadForTask(_ task: Task!, userId: UserId!, capturedVideo:CapturedVideo, onSuccess: @escaping (_ task: Task, _ key: String, _ bucket: String, _ cdnProtocol: CDNProtocol?, _ cdnUrl: CDNUrl?) -> (), onError: ((Error?) -> ())?)
    func completeUpload(_ task: Task!, userId: UserId!, url: URL!, onSuccess: @escaping (Data!)->(), onUnauthorized: (()->())?, onError: ((Error?)->())?)
    func beginMultipartUploadForPendingUpload(_ pendingUpload: PendingUpload!, capturedVideo: CapturedVideo, key: String, bucket: String, cdnProtocol: CDNProtocol!, cdnUrl: CDNUrl!, onSuccess: @escaping (String?, String?, CDNProtocol?, CDNUrl?)->(), onError: ((Error?)->())?)
    func putToUrl(_ url:URL!, withFileAtUrl:URL!, onSuccess: @escaping (Data!)->(), onUnauthorized: (()->())?, onError: ((Error?)->())?)
    func cancelUpload(_ pendingUpload: PendingUpload!)
}
