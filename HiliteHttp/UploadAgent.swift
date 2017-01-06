import Foundation
import HiliteCore

public typealias AWSKey = String
public typealias AWSBucket = String
public typealias AWSETag = String
public typealias CDNProtocol = String
public typealias CDNUrl = String

// TODO: UploadAgent -> PendingUpload should be 1:1. change verbage from 'add' to 'set.' upload agents should actually just be created with a pending upload and disallow modification of that pending upload
open class UploadAgent {
    let uploadService:UploadService!
    let pendingUploadsService:PendingUploadsService!
    public var pendingUpload: PendingUpload?
    
    public init() {
        uploadService = HttpUploadService()
        pendingUploadsService = StandardPendingUploadsService()
    }
    
    public func addPendingUploadForTask(_ task: Task, capturedVideo: CapturedVideo) {
        addPendingUpload(TaskBackedPendingUpload(task: task, capturedVideo: capturedVideo, isUploaded: false))
    }
    public func addPendingUpload(_ pendingUpload: PendingUpload!) {
        self.pendingUpload = pendingUpload
        pendingUploadsService.addPendingUpload(pendingUpload)
    }
    
    // TODO: accept pendingUpload instead of task
    public func beginUploadForTask(_ task: Task, userId: UserId!, withCapturedVideo: CapturedVideo, onSuccess: @escaping ((AWSETag?, AWSKey?, AWSBucket?, CDNProtocol?, CDNUrl?)->()), onError: ((Error?)->())?) {
        let pendingUpload = TaskBackedPendingUpload(task: task, capturedVideo: withCapturedVideo, isUploaded: false)
        addPendingUpload(pendingUpload)

//        print(userIdentityCard.toJSON())
        
        if let _ = userId {
            uploadService.initiateUploadForTask(task,
                userId:  userId,
                capturedVideo: withCapturedVideo,
                onSuccess: {
                    (task, key, bucket, cdnProtocol, cdnUrl)->() in
                    print(task)
                    print(bucket)
                    
                    DispatchQueue.main.async(execute: { [weak self] () -> Void in
                        BroadcastService.postUploadBegan(pendingUpload)
                        self?.uploadService.beginMultipartUploadForPendingUpload(pendingUpload, capturedVideo: withCapturedVideo, key: key, bucket: bucket, cdnProtocol: cdnProtocol, cdnUrl: cdnUrl,
                            onSuccess: {
                                (eTag: String?, key: String?, cdnProtocol: String?, cdnUrl: String?)->() in
                                Logger.logv(eTag as AnyObject!)
                                
                                DispatchQueue.main.async(execute: { () -> Void in
                                    self?.pendingUploadsService.completeUpload(pendingUpload)
                                    
                                    onSuccess(eTag, key, bucket, cdnProtocol, cdnUrl)
                                })
                            },
                            onError: onError)
                    })
                },
                onError: onError)
        }

    }

    /* TODO: the url should be handed back when initiating the upload */
    public func completeUpload(_ pendingUpload: PendingUpload!, task: Task!, userId: UserId!, eTag: AWSETag!, key: AWSKey!, bucket: AWSBucket!, cdnProtocol: String!, cdnUrl: String!, onSuccess: @escaping (Data!)->(), onUnauthorized: @escaping ()->(), onError: ((Error?)->())?) {
        
        let urlString = "\(cdnProtocol!)\(cdnUrl!)/\(key!)"
        let url = URL(string: urlString)
        self.uploadService.completeUpload(task, userId: userId, url: url!, onSuccess: onSuccess, onUnauthorized: onUnauthorized, onError: onError);
        BroadcastService.postUploadComplete(pendingUpload)
    }
    
    public func uniqueIdentifier() -> String? {
        return pendingUpload?.uniqueIdentifier
    }
    
    public func cancel() {
        Logger.logm()
        
        guard let pendingUpload = pendingUpload else { return }

        uploadService.cancelUpload(self.pendingUpload!)
    }
}
