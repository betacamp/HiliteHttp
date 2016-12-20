import Foundation
import SwiftyJSON
import HiliteCore

public class HttpAuthenticationService: AuthenticationService {
    let httpClient: HttpClient!
    let api:APIv1!
    
    public init() {
        httpClient = StandardHttpClient()
        api = APIv1();
    }
    
    public init(reauthenticating: Bool) {
        httpClient = reauthenticating ? ReauthenticatingHttpClient() : StandardHttpClient()
        api = APIv1()
    }
    
    public func authenticateWithUsername(_ username: String, password: String, onSuccess: @escaping (UserIdentityCard)->Void, onUnauthorized: (()->())?, onError: ((Error?)->())?) {
        do {
            let jsonCreds:JSON = ["identifier":username,"password":password]
            let jsonData = try jsonCreds.rawData()
            httpClient.postToUrl(api.userAuthUrl(), jsonData: jsonData,
                onSuccess: { (data) in
                    let jsonResponse = JSON(data: data);
                    print(jsonResponse)
                    
                    let userJSON:JSON = jsonResponse["data"]["user"]
                    
                    let userIdentity = JSONBackedUserIdentityCard(json: userJSON)
                    
                    ApplicationPreferencesBackedUserSession().loginWithUserId(userJSON["id"].stringValue, username: userJSON["username"].stringValue, password: password, firstName: userIdentity.firstProducerProfile()?.firstName(), lastName: userIdentity.firstProducerProfile()?.lastName(), charityDisplayName: userIdentity.firstProducerProfile()?.charityCards()?.first?.displayName(), verticalHandle: userIdentity.verticalHandle())
                    
                    UserCapabilitiesAgent().updateFromUserIdentityCard(JSONBackedUserIdentityCard(json: userJSON))
                    
                    onSuccess(JSONBackedUserIdentityCard(json: jsonResponse["data"]["user"]));
                },
                onUnauthorized: onUnauthorized,
                onError: { (error) in
                    onError?(error);
                },
                onCancelled: { ()->() in
                    print("cancelled")
            });
        } catch {
            onError?(nil)
        }
    }
}
