import Foundation

import AWSCore
import AWSCognito
import AWSS3
import HiliteCore

public class AyoAWSService {
    var cognitoCredentialsProvider: AWSCognitoCredentialsProvider?
    var serviceConfig: AWSServiceConfiguration?
    var syncClient: AWSCognito?
    var transferManager: AWSS3TransferManager?


    public func updateConfigWithRegionType(_ regionType: AWSRegionType, identityPoolId: String!, onSuccess: @escaping ()->(), onError: @escaping (Error!)->()) {
        cognitoCredentialsProvider = AWSCognitoCredentialsProvider(regionType: regionType, identityPoolId: identityPoolId)
        serviceConfig = AWSServiceConfiguration(region: regionType, credentialsProvider: cognitoCredentialsProvider)
        AWSServiceManager.default().defaultServiceConfiguration = serviceConfig

        syncClient = AWSCognito.default()
        let dataSet = syncClient?.openOrCreateDataset("ayo-dataSet")
        
        if (dataSet != nil) {
            dataSet!.clear()
            dataSet!.synchronize().continue(successBlock: { [weak self] (task:BFTask?) -> Any? in
                
                guard let task = task else { return nil }
                
                if (task.isCancelled) {
                    Logger.logm("cognito sync CANCELLED")
                } else if (task.error != nil) {
                    onError(task.error)
                } else {
                    Logger.logm("cognito succeeded")
                    
                    self?.transferManager = AWSS3TransferManager.default()
                    
                    onSuccess()
                }
                return nil
            })
        } else {
            onError(HiliteError.create(999, description: "unable to generate AWSCognito dataSet"))
        }
    }
    
    public class func regionTypeFrom(_ string: String!) -> AWSRegionType {
        switch string {
        case "USEast1":
            return AWSRegionType.usEast1
        default:
            return AWSRegionType.usEast1
        }
    }
}
