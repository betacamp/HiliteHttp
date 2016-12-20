import Foundation
import HiliteCore

public protocol AuthenticationService {
    func authenticateWithUsername(_ username: String, password: String, onSuccess: @escaping (UserIdentityCard)->Void, onUnauthorized: (()->())?, onError: ((Error?)->())?);
}
