import Foundation
import HiliteCore

public protocol FileUploadService {
    func initiatePhotoUpload(_ contentType: String, filenameExtension: String, userIdentityCard: UserIdentityCard, onSuccess: @escaping (InitiatedPhotoUploadResponse)->Void, onUnauthorized: ()->Void, onError: @escaping (Error?)->Void)
    func uploadUserProfileJpegData(_ data: Data, userIdentityCard: UserIdentityCard, onProgress: @escaping (Float)->Void, onSuccess: @escaping (URL)->Void, onError: @escaping (Error?)->())
    func uploadSignatureImagePngData(_ data: Data, userIdentityCard: UserIdentityCard, onProgress: @escaping (Float)->Void, onSuccess: @escaping (URL)->Void, onError: @escaping (Error?)->())
    func cancel()
}
