import Foundation
import SwiftyJSON
import AWSS3
import HiliteCore

open class S3FileUploadService: FileUploadService {
    let httpClient = ReauthenticatingHttpClient()
    let uploadHttpClient = StandardHttpClient()
    let api = APIv1()
    let apiV2 = APIv2.sharedInstance
    let ayoAWSService = AyoAWSService()
    let fileManager = HLFileManager()
    public var currentUploadRequest: AWSS3TransferManagerUploadRequest?
    
    public init() {
        
    }

    public func initiatePhotoUpload(_ contentType: String, filenameExtension: String, userIdentityCard: UserIdentityCard, onSuccess: @escaping (InitiatedPhotoUploadResponse)->Void, onUnauthorized: ()->Void, onError: @escaping (Error?)->Void) {
        do {
            let jsonData = try JSON(["contentType": "image/jpg", "filenameExtension": "jpg"]).rawData()
            httpClient.postToUrl(apiV2.initiateProducerPhotoUploadUrl(userIdentityCard.userId()!), jsonData: jsonData, onSuccess: { (responseData) -> () in
                DispatchQueue.main.async(execute: { [weak self] () -> Void in
                    let responseJson = JSON(data: responseData)
                    print(responseJson)
                    
                    let cognito = Cognito(regionType: responseJson["data"]["s3Upload"]["cognito"]["regionType"].stringValue, identityPoolId: responseJson["data"]["s3Upload"]["cognito"]["identityPoolId"].stringValue)
                    
                    print(cognito.identityPoolId)
                    
                    let regionType = AyoAWSService.regionTypeFrom(cognito.regionType)
                    self?.ayoAWSService.updateConfigWithRegionType(regionType, identityPoolId: cognito.identityPoolId,
                        onSuccess: {
                            ()->() in
                            
                            let key =           responseJson["data"]["s3Upload"]["key"].stringValue
                            let bucket =        responseJson["data"]["s3Upload"]["bucket"].stringValue
                            let contentType =   responseJson["data"]["s3Upload"]["contentType"].stringValue
                            let cdnProtocol =   responseJson["data"]["s3Upload"]["cdn"]["protocol"].stringValue
                            let cdnUrl =        responseJson["data"]["s3Upload"]["cdn"]["url"].stringValue
                            let url =           URL(string: responseJson["data"]["s3Upload"]["url"].stringValue)
                            
                            onSuccess(InitiatedPhotoUploadResponse(key: key, bucket: bucket, contentType: contentType, cdn: CDN(url: cdnUrl, proto: cdnProtocol), cognito: cognito, url: url))
                        }, onError:{
                            (updateError)->() in
                            Logger.loge(updateError.localizedDescription)
                            onError(updateError)
                    })
                    
                    })
                }, onUnauthorized: { () -> () in
                    
                }, onError: onError, onCancelled: nil)
        } catch {
            onError(nil)
        }
    }

    public func initiateSignatureImageUpload(_ contentType: String, filenameExtension: String, userIdentityCard: UserIdentityCard, onSuccess: @escaping (InitiatedPhotoUploadResponse)->Void, onUnauthorized: ()->Void, onError: @escaping (Error?)->Void) {
        do {
            let jsonData = try JSON(["contentType": "image/png", "filenameExtension": "png"]).rawData()
            httpClient.postToUrl(apiV2.initiateProducerSignatureImageUploadUrl(userIdentityCard.userId()!), jsonData: jsonData, onSuccess: { (responseData) -> () in
                DispatchQueue.main.async(execute: { [weak self] () -> Void in
                    let responseJson = JSON(data: responseData)
                    print(responseJson)
                    
                    let cognito = Cognito(regionType: responseJson["data"]["s3Upload"]["cognito"]["regionType"].stringValue, identityPoolId: responseJson["data"]["s3Upload"]["cognito"]["identityPoolId"].stringValue)
                    
                    print(cognito.identityPoolId)
                    
                    let regionType = AyoAWSService.regionTypeFrom(cognito.regionType)
                    self?.ayoAWSService.updateConfigWithRegionType(regionType, identityPoolId: cognito.identityPoolId,
                        onSuccess: {
                            ()->() in
                            
                            let key =           responseJson["data"]["s3Upload"]["key"].stringValue
                            let bucket =        responseJson["data"]["s3Upload"]["bucket"].stringValue
                            let contentType =   responseJson["data"]["s3Upload"]["contentType"].stringValue
                            let cdnProtocol =   responseJson["data"]["s3Upload"]["cdn"]["protocol"].stringValue
                            let cdnUrl =        responseJson["data"]["s3Upload"]["cdn"]["url"].stringValue
                            let url =           URL(string: responseJson["data"]["s3Upload"]["url"].stringValue)
                            
                            onSuccess(InitiatedPhotoUploadResponse(key: key, bucket: bucket, contentType: contentType, cdn: CDN(url: cdnUrl, proto: cdnProtocol), cognito: cognito, url: url))
                        }, onError:{
                            (updateError)->() in
                            Logger.loge(updateError.localizedDescription)
                            onError(updateError)
                    })
                    
                    })
                }, onUnauthorized: { () -> () in
                    
                }, onError: onError, onCancelled: nil)            
        } catch {
            onError(nil)
        }
    }

    public func uploadSignatureImagePngData(_ data: Data, userIdentityCard: UserIdentityCard, onProgress: @escaping (Float) -> Void, onSuccess: @escaping (URL) -> Void, onError: @escaping (Error?) -> ()) {
        let filenameExtension = "png"
        let contentType = "image/png"
        
        initiateSignatureImageUpload(contentType, filenameExtension: filenameExtension, userIdentityCard: userIdentityCard, onSuccess: { [weak self] (initiatedPhotoUploadResponse) -> Void in
            print(initiatedPhotoUploadResponse, terminator: "")
            
            let fileUrl = self?.fileManager.fileUrlToTemporaryFileWithFilename("\(userIdentityCard.userId()!)_sig.\(filenameExtension)")
            if let fileUrl = fileUrl {
                try! data.write(to: fileUrl, options: .atomic)
//                data.write(toFile: filePath, atomically: true)
                
                if let transferManager = self?.ayoAWSService.transferManager {
                    
                    let uploadRequest = AWSS3TransferManagerUploadRequest()
                    uploadRequest?.bucket = initiatedPhotoUploadResponse.bucket
                    uploadRequest?.acl = AWSS3ObjectCannedACL.publicRead
                    uploadRequest?.key = initiatedPhotoUploadResponse.key
                    uploadRequest?.contentType = initiatedPhotoUploadResponse.contentType
                    uploadRequest?.body = fileUrl
                    
                    uploadRequest?.uploadProgress = {
                        (bytesSent:Int64, totalBytesSent:Int64, totalBytesExpectedToSend:Int64) in
                        
                        DispatchQueue.main.async(execute: { () -> Void in
                            let progress = Float(totalBytesSent) / Float(totalBytesExpectedToSend)
                            print(progress, terminator: "");
                            onProgress(progress)
                        })
                    }
                    
                    self?.currentUploadRequest = uploadRequest
                    let _ = transferManager.upload(uploadRequest).continue(with: BFExecutor.mainThread(), with: { (task: BFTask?) -> Any? in
                        Logger.logm("done");
                        
                        guard let task = task else {
                            onError(nil)
                            return nil
                        }
                        
                        if (task.isCancelled) {
                            return nil
                        }
                        
                        let _ = task.result as? AWSS3TransferManagerUploadOutput
                        
                        if (task.error != nil) {
                            Logger.logm(task.error.localizedDescription)
                            onError(task.error)
                        } else {
                            // TODO: this URL is now handed back by the server. data.s3Upload.url
                            let url = URL(string: "\(initiatedPhotoUploadResponse.cdn.proto)\(initiatedPhotoUploadResponse.cdn.url)/\(initiatedPhotoUploadResponse.key)")
                            onSuccess(url!)
                        }
                        
                        return nil
                    })
                    
                    // TODO: move this to a more fool proof function
                    //                    uploadRequests[pendingUpload.uniqueIdentifier!] = uploadRequest
                } else {
                    onError(HiliteError.create(999, description: "No valid AWSS3TransferManager found"))
                }
            } else {
                print("could not save photo file!!", terminator: "")
            }
            }, onUnauthorized: { () -> Void in
                Logger.logm("unauthorized!")
            }) { (error) -> Void in
                Logger.loge(error!.localizedDescription)
                
        }
    }
    
    public func uploadUserProfileJpegData(_ data: Data, userIdentityCard: UserIdentityCard, onProgress:@escaping (Float)->Void, onSuccess: @escaping (URL)->Void, onError: @escaping (Error?)->()) {
        let filenameExtension = "jpg"
        let contentType = "image/jpeg"
        
        initiatePhotoUpload(contentType, filenameExtension: filenameExtension, userIdentityCard: userIdentityCard, onSuccess: { [weak self] (initiatedPhotoUploadResponse) -> Void in
            print(initiatedPhotoUploadResponse, terminator: "")
            
            let fileUrl = self?.fileManager.fileUrlToTemporaryFileWithFilename("\(userIdentityCard.userId()!).\(filenameExtension)")
            if let fileUrl = fileUrl {
                try! data.write(to: fileUrl, options: .atomic)
                
                if let transferManager = self?.ayoAWSService.transferManager {
                    
                    let uploadRequest = AWSS3TransferManagerUploadRequest()
                    uploadRequest?.bucket = initiatedPhotoUploadResponse.bucket
                    uploadRequest?.acl = AWSS3ObjectCannedACL.publicRead
                    uploadRequest?.key = initiatedPhotoUploadResponse.key
                    uploadRequest?.contentType = initiatedPhotoUploadResponse.contentType
                    uploadRequest?.body = fileUrl
                    
                    uploadRequest?.uploadProgress = {
                        (bytesSent:Int64, totalBytesSent:Int64, totalBytesExpectedToSend:Int64) in
                        
                        DispatchQueue.main.async(execute: { () -> Void in
                            let progress = Float(totalBytesSent) / Float(totalBytesExpectedToSend)
                            print(progress, terminator: "");
                            onProgress(progress)
                        })
                    }
                    
                    self?.currentUploadRequest = uploadRequest
                    let _ = transferManager.upload(uploadRequest).continue(with: BFExecutor.mainThread(), with: { (task: BFTask?) -> Any? in
                        Logger.logm("done");
                        
                        guard let task = task else {
                            onError(nil)
                            return nil
                        }
                        
                        if (task.isCancelled) {
                            return nil
                        }
                        
                        let _ = task.result as? AWSS3TransferManagerUploadOutput
                        
                        if (task.error != nil) {
                            Logger.logm(task.error.localizedDescription)
//                            Logger.logv(task.error.userInfo)
                            onError(task.error)
                        } else {

//                            let proto = initiatedPhotoUploadResponse.cdn.proto
//                            let cdnUrl = initiatedPhotoUploadResponse.cdn.url
//                            let key = initiatedPhotoUploadResponse.key
//                            
//                            // TODO: this URL is now handed back by the server. data.s3Upload.url
//                            let url = URL(string: "\(proto)\(cdnUrl)/\(key)")
                            onSuccess(initiatedPhotoUploadResponse.url!)
                        }
                        
                        return nil
                    })
                    
                    // TODO: move this to a more fool proof function
//                    uploadRequests[pendingUpload.uniqueIdentifier!] = uploadRequest
                } else {
                    onError(HiliteError.create(999, description: "No valid AWSS3TransferManager found"))
                }
            } else {
                print("could not save photo file!!", terminator: "")
            }
        }, onUnauthorized: { () -> Void in
            Logger.logm("unauthorized!")
        }) { (error) -> Void in
            Logger.loge(error!.localizedDescription)
            
        }
    }
    
    public func cancel() {
        if let uploadRequest = currentUploadRequest {
            uploadRequest.cancel()
        }
    }
}

public struct InitiatedPhotoUploadResponse {
    let key: AWSKey!
    let bucket: AWSBucket!
    let contentType: String!
    let cdn: CDN!
    let cognito: Cognito!
    let url: URL?
}

public struct Cognito {
    let regionType: String!
    let identityPoolId: String!
}

public struct CDN {
    let url: String!
    let proto: String!
}
