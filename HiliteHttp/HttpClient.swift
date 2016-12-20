import Foundation

public protocol HttpClient {
    func getFromUrl(_ url: URL, onSuccess: @escaping (Data!)->(), onUnauthorized: (()->())?, onError: ((Error?)->())?, onCancelled: (()->())?);
    func postToUrl(_ url: URL!, jsonData: Data!, onSuccess: @escaping (Data!)->(), onUnauthorized: (()->())?, onError: ((Error?)->())?, onCancelled: (()->())?);
    func putToUrl(_ url: URL!, withFileAtUrl:URL!, onSuccess: @escaping (Data!)->(), onUnauthorized: (()->())?, onError:((Error?)->())?, onCancelled: (()->())?)
    func putToUrl(_ url: URL!, jsonData:Data!, onSuccess: @escaping (Data!)->(), onUnauthorized: (()->())?, onError:((Error?)->())?, onCancelled: (()->())?)
    func cancel()
}
