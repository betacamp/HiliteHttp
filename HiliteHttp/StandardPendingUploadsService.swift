import Foundation
import SwiftyJSON
import HiliteCore

open class StandardPendingUploadsService: PendingUploadsService {
    let fileManager:HiliteCore.FileManager!
    
    public init() {
        fileManager = HLFileManager()
    }
    
    public func loadAllWithOnSuccess(_ onSuccess: ((Array<PendingUpload>!) -> ()), onError: ((NSError!) -> ())) {
        let _ = ensurePendingUploadsJson()
        
        let jsonData = fileManager.fileContentsAtUrl(pendingUploadsJsonUrl())
        if let data = jsonData {
            let json = JSON(data: data)
            
            var pendingUploads = Array<PendingUpload>()
            for (_, subJson): (String, JSON) in json["pendingUploads"] {
                pendingUploads.append(JSONBackedPendingUpload(json: subJson))
            }
            
            onSuccess(pendingUploads)
        } else {
            onError(HiliteError.create(999, description: "could not create jsonData in StandardPendingUploadService.loadAllWithOnSuccess"))
        }
    }
    
    public func pendingUploadsJsonUrl() -> URL! {
        return pendingUploadsFolderUrl().appendingPathComponent("pendingUploads.json")
    }
    
    public func pendingUploadsFolderUrl() -> URL! {
        return fileManager.fileUrlToDocumentsFolder().appendingPathComponent("pendingUploads")
    }
    
    public func ensurePendingUploadsJson() -> Bool {
        let _ = ensurePendingUploadsFolder()
        if (!fileManager.fileExistsAtUrl(pendingUploadsJsonUrl())) {
            
            //                let emptyList = NSDictionary()
            //
            //                let json:JSON = ["pendingUploads": emptyList]
            //                let jsonData = json.rawData()
            
            return savePendingUploads(Array<PendingUpload>())
            
        }
        return true
        }
    
    public func ensurePendingUploadsFolder() -> Bool {
        if (!fileManager.fileExistsAtUrl(pendingUploadsFolderUrl())) {
            return fileManager.createFolderAtUrl(pendingUploadsFolderUrl())
        }
        return true
    }

    // adding a pendingUpload with an existing uniqueIdentifier replaces existing pendingUpload
    public func addPendingUpload(_ pendingUpload: PendingUpload) {
        loadAllWithOnSuccess({ [weak self] (loadedPendingUploads) -> () in
            if let weakSelf = self {
                let updatedPendingUploads = weakSelf.appendPendingUpload(pendingUpload, toPendingUploads:loadedPendingUploads)
                
                let _ = weakSelf.savePendingUploads(updatedPendingUploads)
            }
        }, onError: { (error) -> () in
            
        })
    }

    // TODO: make class func. change named to appendUniquePendingUpload
    public func appendPendingUpload(_ pendingUpload: PendingUpload!, toPendingUploads: Array<PendingUpload>) -> Array<PendingUpload> {
        var filteredPendingUploads = toPendingUploads.filter({
            (aPendingUpload:PendingUpload)->Bool in
            return pendingUpload.uniqueIdentifier != aPendingUpload.uniqueIdentifier
        })
        
        Logger.logm("appending upload with isUploaded: \(pendingUpload.isUploaded)")
        Logger.logm("appending upload with uploadProgress: \(pendingUpload.uploadProgress())")
        filteredPendingUploads.append(pendingUpload)
        
        return filteredPendingUploads
    }

    public func removePendingUpload(_ pendingUpload: PendingUpload!) {
        loadAllWithOnSuccess({ (loadedPendingUploads:Array<PendingUpload>!) -> () in
            let filtered = loadedPendingUploads.filter({
                $0.uniqueIdentifier != pendingUpload.uniqueIdentifier
            })

            let _ = self.savePendingUploads(filtered)
        }, onError: { (error) -> () in

        })
    }
    
    public func savePendingUploads(_ pendingUploads: Array<PendingUpload>) -> Bool {
        do {
            let pendingUploadJsonsDict = NSMutableDictionary()
            
            for pendingUpload in pendingUploads {
                pendingUploadJsonsDict.setObject(pendingUpload.toJSON().object, forKey: pendingUpload.uniqueIdentifier! as NSString)
            }
            
            let json = JSON(["pendingUploads": pendingUploadJsonsDict])
            let jsonData = try json.rawData()
            
            Logger.logm(String(data: jsonData, encoding: .utf8)!)
            
            return fileManager.writeData(jsonData, toFileAtUrl:pendingUploadsJsonUrl())
        } catch {
            return false
        }
    }
    
    public func clearPendingUploads() {
        let _ = savePendingUploads(Array<PendingUpload>())
    }

    public func clearPendingUploadsJson() {
        fileManager.removeFileAtUrl(pendingUploadsJsonUrl())
    }
    
    public func cancelLoading() {
        // nothing to do, all operation is synchronous as of now
    }
    
    public func completeUpload(_ pendingUpload: PendingUpload) {
        pendingUpload.completeUpload()

        addPendingUpload(pendingUpload)
        
        BroadcastService.postUploadComplete(pendingUpload)
    }
    
    public func savePendingUpload(_ pendingUpload: PendingUpload!) {
        // for now just use addPendingUpload mechanism
        addPendingUpload(pendingUpload)
    }
}
