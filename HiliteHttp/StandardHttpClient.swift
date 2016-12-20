import Foundation
import SwiftyJSON
import HiliteHttp

enum HttpClientError: Error {
    case responseDataIsNil
    case unknown(String?)
}

class StandardHttpClient: NSObject, HttpClient, URLSessionTaskDelegate {
    var session: Foundation.URLSession!
    var dataTask: URLSessionDataTask?
    var shouldReauthenticate: Bool?
    
    override init() {
        super.init()
        session = Foundation.URLSession(configuration: URLSessionConfiguration.default, delegate:self, delegateQueue:nil);
    }
    
    init(ignoreCache: Bool) {
        super.init()
        session = Foundation.URLSession(configuration: URLSessionConfiguration.ephemeral, delegate:self, delegateQueue:nil);
    }
    
    func getFromUrl(_ url: URL, onSuccess: @escaping (Data!)->(), onUnauthorized: (()->())?, onError: ((Error?)->())?, onCancelled: (()->())?) {
        dataTask?.cancel();
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        dataTask = session.dataTask(with: request, completionHandler: { [weak self] (data, response, error)  in
            if (self?.dataTask?.state == URLSessionTask.State.completed) {
                self?.handleResponse(self?.dataTask, data: data, urlResponse: response, error: error, request: request, onSuccess: onSuccess, onUnauthorized: onUnauthorized, onError: onError)
            } else if (self?.dataTask?.state == URLSessionTask.State.canceling) {
                onCancelled?()
            }
            self?.dataTask = nil
        }) 

        dataTask?.resume();
    }

    func postToUrl(_ url: URL!, jsonData: Data!, onSuccess: @escaping (Data!)->(), onUnauthorized: (()->())?, onError: ((Error?)->())?, onCancelled: (()->())?) -> () {
        dataTask?.cancel();

        var request = URLRequest(url: url)
        request.httpMethod = "POST";
        request.httpBody = jsonData;
        request.setValue("application/json", forHTTPHeaderField: "Content-Type");

        dataTask = session.dataTask(with: request, completionHandler: { [weak self] (data, response, error) in
            print("\(self?.dataTask?.state)", terminator: "")
            if (self?.dataTask?.state == URLSessionTask.State.completed) {
                self?.handleResponse(self?.dataTask, data: data, urlResponse: response, error: error, request: request, onSuccess: onSuccess, onUnauthorized: onUnauthorized, onError: onError)
                self?.dataTask = nil
            } else if (self?.dataTask?.state == URLSessionTask.State.canceling) {
                onCancelled?()
                self?.dataTask = nil
            }
        }) 
        dataTask?.resume();
    }
    
    func putToUrl(_ url: URL!, jsonData: Data!, onSuccess: @escaping (Data!)->(), onUnauthorized: (()->())?, onError: ((Error?)->())?, onCancelled: (()->())?) {
        dataTask?.cancel()
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        
        //println(NSString(data: jsonData, encoding: NSUTF8StringEncoding)!)
        dataTask = session.dataTask(with: request, completionHandler: { [weak self] (data, response, err) in
            if (self?.dataTask?.state == URLSessionTask.State.completed) {
                self?.handleResponse(self?.dataTask, data: data, urlResponse: response, error: err, request: request, onSuccess: onSuccess, onUnauthorized: onUnauthorized, onError: onError)
                self?.dataTask = nil
            } else if (self?.dataTask?.state == URLSessionTask.State.canceling) {
                onCancelled?()
            }
        }) 
        dataTask?.resume()
    }
    
    func putToUrl(_ url: URL!, withFileAtUrl: URL!, onSuccess: @escaping (Data!)->(), onUnauthorized: (()->())?, onError: ((Error?)->())?, onCancelled: (()->())?) {
        dataTask?.cancel();
        dataTask = nil
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST";
        request.setValue("video/quicktime", forHTTPHeaderField: "Content-Type")
        request.setValue("Keep-Alive", forHTTPHeaderField: "Connection");

        dataTask = session
            .uploadTask(with: request as URLRequest, fromFile:withFileAtUrl,
            completionHandler: { [weak self]
                (data, urlResponse, error) -> Void in
                if (self?.dataTask?.state == URLSessionTask.State.completed) {
                    self?.handleResponse(self?.dataTask, data: data, urlResponse: urlResponse, error: error as Error?, request: request as URLRequest!, onSuccess: onSuccess, onUnauthorized: onUnauthorized, onError: onError)
                } else if (self?.dataTask?.state == URLSessionTask.State.canceling) {
                    onCancelled?()
                }
                self?.dataTask = nil
            })

        dataTask?.resume();
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        // nothing to do
    }
    
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {

        completionHandler(Foundation.URLSession.AuthChallengeDisposition.useCredential, URLCredential(trust: challenge.protectionSpace.serverTrust!))
    }
    
    func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        // nothing to do
    }
    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        // nothing to do
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        // print "\(totalBytesSent) / \(totalBytesExpectedToSend)"
    }
    
    func cancel() {
        dataTask?.cancel()
    }
    
    func handleResponse(_ task: URLSessionTask?, data: Data?, urlResponse: URLResponse?, error: Error?, request: URLRequest!, onSuccess: @escaping (Data!)->(), onUnauthorized: (()->())?, onError: ((Error?)->())?) -> Void {
        
        if let error = error { print(error); onError?(error); return; }

        guard let httpResponse = urlResponse as? HTTPURLResponse else { onError?(nil); return }
        
        if statusCodeIsUnauthorized(httpResponse.statusCode) {
            onUnauthorized?();
            return
        }
        
        guard let data = data else {
            onError?(HttpClientError.responseDataIsNil)
            return
        }

        if statusCodeIsOk(httpResponse.statusCode) {
            onSuccess(data)
            return
        }
        
        let json = JSON(data: data)
        let errorString = json["error"].string ?? NSString(data: data, encoding: String.Encoding.utf8.rawValue) as? String
        
        onError?(HttpClientError.unknown(errorString))
    }
}

fileprivate func statusCodeIsUnauthorized(_ code: Int) -> Bool {
    return code == 401
}

fileprivate func statusCodeIsOk(_ code: Int) -> Bool {
    return 200...299 ~= code
}
