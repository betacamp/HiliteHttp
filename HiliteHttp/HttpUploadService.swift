import Foundation
import SwiftyJSON
import AWSS3
import HiliteCore

open class HttpUploadService: UploadService {
    let httpClient: ReauthenticatingHttpClient!
    let api = APIv1()
    let apiV2 = APIv2.sharedInstance
    var ayoAWSService: AyoAWSService
    var uploadRequests = Dictionary<String, AWSS3TransferManagerUploadRequest!>()
    
    public init() {
        httpClient = ReauthenticatingHttpClient()
        ayoAWSService = AyoAWSService()
    }
    
    public func initiateUploadForTask(_ task: Task!, userId: UserId!, capturedVideo:CapturedVideo, onSuccess: @escaping (_ task: Task, _ key:String, _ bucket:String, _ cdnProtocol: CDNProtocol?, _ cdnUrl: CDNUrl?) -> (), onError: ((Error?) -> ())?) {
        let taskId = task.id()
        
        print(capturedVideo.fileUrlToMOV?.absoluteString ?? "")
        let fileExists = HLFileManager().fileExistsAtUrl(capturedVideo.fileUrlToMOV)
        
        if (!fileExists) {            
            onError?(HiliteError.create(999, description: "capturedVideo does not exist at \(capturedVideo.fileUrlToMOV!)!"))
            return
        }
        
//        let uploadData = NSData(contentsOfFile: capturedVideo.fileUrlToMOV!.path!)
        
        do {
//            let fileUrl = capturedVideo.fileUrlToMOV
            let uploadData = try? Data(contentsOf: capturedVideo.fileUrlToMOV! as URL)
            let uploadLength = uploadData?.count
            let json = JSON(["taskId": taskId!, "contentLength": uploadLength!, "contentType": "quicktime/mov", "filenameExtension": "mov"])
            let jsonData = try json.rawData()
            httpClient.postToUrl(apiV2.initiateUploadUrlTaskId(task.id()!), jsonData: jsonData,
                onSuccess: {
                    (responseData)->() in
                    
                    let jsonResponse = JSON(data: responseData)
                    
                    print(jsonResponse)
                    
                    print(String(data: responseData, encoding: .utf8) as Any)
                    
                    let taskJson = jsonResponse["data"]["task"]
                    let s3UploadJson = jsonResponse["data"]["s3Upload"]
                    let bucket = s3UploadJson["bucket"].stringValue
                    let key = s3UploadJson["key"].stringValue
                    
                    let cognitoJson = s3UploadJson["cognito"]
                    let regionTypeString = cognitoJson["regionType"].stringValue
                    let identityPoolId = cognitoJson["identityPoolId"].stringValue
                    
                    let cdnJson = s3UploadJson["cdn"]
                    let cdnProtocol = cdnJson["protocol"].stringValue
                    let cdnUrl = cdnJson["url"].stringValue
                    
                    let regionType = AyoAWSService.regionTypeFrom(regionTypeString)
                    
                    self.ayoAWSService.updateConfigWithRegionType(regionType, identityPoolId: identityPoolId,
                        onSuccess: {
                            ()->() in
                            onSuccess(JSONBackedTask(json: taskJson), key, bucket, cdnProtocol, cdnUrl)
                        }, onError:{
                            (updateError)->() in
                            Logger.loge(updateError.localizedDescription)
                            onError?(updateError)
                    })
                },
                onUnauthorized: {
                    ()->() in
                    Logger.logm("UNAUTHORIZED");
                },
                onError: {
                    (error:Error?)->() in
                    Logger.loge(error?.localizedDescription ?? "ERROR")
                },
                onCancelled: nil)
        } catch {
            onError?(nil)
        }
    }



    public func beginMultipartUploadForPendingUpload(_ pendingUpload: PendingUpload!, capturedVideo: CapturedVideo, key: String, bucket: String, cdnProtocol: CDNProtocol!, cdnUrl: CDNUrl!, onSuccess: @escaping (String?, String?, CDNProtocol?, CDNUrl?)->(), onError: ((Error?)->())?) {

        if let transferManager = self.ayoAWSService.transferManager {
//            let uploadData = NSData(contentsOfFile: capturedVideo.fileUrlToMOV!.path!)
            
            let uploadRequest = AWSS3TransferManagerUploadRequest()
            uploadRequest?.bucket = bucket
            uploadRequest?.acl = AWSS3ObjectCannedACL.publicRead
            uploadRequest?.key = key
            uploadRequest?.contentType = "video/quicktime"
            uploadRequest?.body = capturedVideo.fileUrlToMOV! as URL!
            
            uploadRequest?.uploadProgress = {
                (bytesSent:Int64, totalBytesSent:Int64, totalBytesExpectedToSend:Int64) in
            
                DispatchQueue.main.async(execute: { () -> Void in
                    let progress = Float(totalBytesSent) / Float(totalBytesExpectedToSend)
                    BroadcastService.postUploadProgressUpdate(pendingUpload, progress: progress)
                })
            }
            
            if let existingUploadRequest = uploadRequests[pendingUpload.uniqueIdentifier!] {
                existingUploadRequest.cancel()
            }

            let _ = transferManager.upload(uploadRequest).continue(with: BFExecutor.mainThread(), with: { [weak self] (task: BFTask?) -> AnyObject? in
                Logger.logm("done");

                guard let task = task else { return nil }
                
                // TODO: move this to a more fool proof function
                self?.uploadRequests[pendingUpload.uniqueIdentifier!] = nil

                if (task.isCancelled) {
                    BroadcastService.postUploadCancelled(pendingUpload)
                    return nil
                }
                
                if let uploadOutput = task.result as? AWSS3TransferManagerUploadOutput {
                    
                    if let error = task.error {
                        Logger.logm(error.localizedDescription)
                        onError?(error)
                        return nil
                    }
                    
                    onSuccess(uploadOutput.eTag, key, cdnProtocol, cdnUrl)
                } else {
                    BroadcastService.postUploadCancelled(pendingUpload)
                }

                return nil
                
            })
            
            // TODO: move this to a more fool proof function
            uploadRequests[pendingUpload.uniqueIdentifier!] = uploadRequest
        } else {
            onError?(HiliteError.create(999, description: "No valid AWSS3TransferManager found"))
        }
    }
    
    public func putToUrl(_ url:URL!, withFileAtUrl:URL!, onSuccess: @escaping (Data!)->(), onUnauthorized: (()->())?, onError: ((Error?)->())?) {
        httpClient.putToUrl(url, withFileAtUrl:withFileAtUrl, onSuccess: onSuccess, onUnauthorized: onUnauthorized, onError: onError, onCancelled: nil)
    }

    public func completeUpload(_ task: Task!, userId: UserId!, url: URL!, onSuccess: @escaping (Data!)->(), onUnauthorized: (()->())?, onError: ((Error?)->())?) {
        do {
            
            let userSession = ApplicationPreferencesBackedUserSession()
            let postToUrl = apiV2.completeUploadUrlWithTaskId(task.id()!)
            let json = JSON([
                "url": url.absoluteString,
                "uid": userId,
                "displayName": userSession.fullName()!,
                "firstName": userSession.firstName()!,
                "lastName": userSession.lastName()!,
                "data": [String: AnyObject]()
            ])
            
            let jsonData = try json.rawData()
            
            print(String(data: jsonData, encoding: .utf8) ?? "")
            
            httpClient.postToUrl(postToUrl, jsonData: jsonData,
                onSuccess: { (responseData) -> () in
                    //                let responseJson = JSON(data: responseData)
                    DispatchQueue.main.async {
                        Logger.logm(String(data: responseData, encoding: .utf8)!)
                        onSuccess(responseData)
                    }
                },
                onUnauthorized: {()->() in
                    DispatchQueue.main.async {
                        Logger.logm("UNAUTHORIZED");
                    }
                }, onError: { (error:Error?) -> () in
                    DispatchQueue.main.async {
                        Logger.loge(error?.localizedDescription ?? "")
                    }
                }, onCancelled: nil)
        } catch {
            onError?(nil)
        }
    }
    
    public func cancelUpload(_ pendingUpload: PendingUpload!) {
        Logger.logm()
        if let existingPendingUpload = uploadRequests[pendingUpload.uniqueIdentifier!] {
            Logger.logm("CANCELLING UPLOAD")
            existingPendingUpload.cancel()
        }
    }
    
    public func pendingUploadIsUploading(_ pendingUpload: PendingUpload!) -> Bool {
        return uploadRequests[pendingUpload.uniqueIdentifier!] != nil
    }
}
