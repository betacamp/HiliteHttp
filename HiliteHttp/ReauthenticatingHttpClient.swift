import Foundation
import SwiftyJSON
import HiliteCore

open class ReauthenticatingHttpClient: StandardHttpClient {
    let authenticationService = HttpAuthenticationService()
    var retryDataTask: URLSessionDataTask?
    
    fileprivate func reauthenticate(_ onSuccess: @escaping (UserIdentityCard)->(), onUnauthorized: (()->())?, onError: ((Error?)->())?) {
        Logger.logm()
        
        let userSession = ApplicationPreferencesBackedUserSession();
        
        if !userSession.isLoggedIn() {
            onUnauthorized?()
            return
        }
        
        if let username = userSession.username(), let password = userSession.password() {
            self.authenticationService.authenticateWithUsername(username, password: password, onSuccess: onSuccess, onUnauthorized: onUnauthorized, onError: onError)
        } else {
            onUnauthorized?()
        }
        
    }

    override func handleResponse(_ task: URLSessionTask?, data: Data?, urlResponse: URLResponse?, error: Error?, request: URLRequest!, onSuccess: @escaping (Data!)->(), onUnauthorized: (()->())?, onError: ((Error?)->())?) -> Void {
        
        if (error != nil) { print(error) }
        print(urlResponse)
        
        if let httpResponse = urlResponse as? HTTPURLResponse {
            if (httpResponse.statusCode == 200) {
                onSuccess(data);
            } else if (httpResponse.statusCode == 401) {
                self.reauthenticate({ [weak self] (userIdentityCard) -> () in
                    self?.retryDataTask = self!.session.dataTask(with: request, completionHandler: { (reauthenticatedResponseData, reauthenticatedResponse, reauthenticatedError) -> Void in
                        let reauthenticatedUrlResponse = reauthenticatedResponse as! HTTPURLResponse
                        if (reauthenticatedUrlResponse.statusCode == 200) {
                            onSuccess(reauthenticatedResponseData);
                        } else if (httpResponse.statusCode == 401) {
                            onUnauthorized?();
                        } else {
                            onError?(reauthenticatedError);
                        }
                    });
                    self?.retryDataTask?.resume()
                    },
                    onUnauthorized: onUnauthorized,
                    onError: onError);
            } else {
                if let unwrappedError = error {
                    onError?(unwrappedError);
                } else {
                    guard let data = data else {
                        onError?(HiliteError.create(999, description: "No data present"))
                        return
                    }
                    let jsonData = JSON(data: data)
                        
                    if let _ = jsonData.error {
                        onError?(HiliteError.create(999, description: String(data: data, encoding: .utf8)))
                    } else {
                        onError?(HiliteError.create(999, description: jsonData["error"].string ?? "ERROR"))
                    }
                        
                }
            }
        }        
    }
}
