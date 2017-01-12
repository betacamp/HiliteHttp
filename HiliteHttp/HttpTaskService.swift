import Foundation
import SwiftyJSON
import HiliteCore
import HiliteHttp

open class HttpTaskService: TaskService {
    let httpClient = ReauthenticatingHttpClient()
    let api = APIv1()
    let apiV2 = APIv2.sharedInstance
    
    public func loadTasks(_ onSuccess: @escaping (Array<Task>)->Void, onError: (Error)->Void) {
        if let dataTask = httpClient.dataTask {
            if (dataTask.state == URLSessionTask.State.running) { onSuccess([]); return }
        }
        
        guard let _ = ApplicationPreferencesBackedUserSession().userId() else { return }
        guard let url = apiV2.hiliteTasksUrl() else { return }
        
        self.cancelLoading()
        httpClient.getFromUrl(url,
                              onSuccess: {
                                (data) in
                                
                                Logger.logm()
                                
                                let jsonResponse:JSON = JSON(data: data)
                                print(jsonResponse)
                                
                                let tasksJson:JSON = jsonResponse["data"]["tasks"]
                                var tasksArray = Array<Task>()
                                
                                for (_, subJson): (String, JSON) in tasksJson {
                                    tasksArray.append(JSONBackedTask(json: subJson))
                                }
                                onSuccess(tasksArray)
        }, onUnauthorized: { ()->() in
            Logger.logm("UNAUTHORIZED")
        }, onError: {
            (error:Error?) in
            if let unwrappedError = error {
                Logger.loge(unwrappedError.localizedDescription)
            }
        }, onCancelled: nil);
    }
    
    public func cancelLoading() {
        httpClient.cancel()
    }

    public func loadTask(_ taskId: String!, onSuccess: @escaping (Task?)->(), onError: (Error!)->()) {
        self.cancelLoading()
        httpClient.getFromUrl(apiV2.taskUrlWithTaskId(taskId, userId: ApplicationPreferencesBackedUserSession().userId()!)!,
            onSuccess: {
                (data) in

                let jsonResponse:JSON = JSON(data: data)
                let taskJson:JSON = jsonResponse["data"]["task"]

                print(taskJson)
                
                onSuccess(JSONBackedTask(json: taskJson))
            }, onUnauthorized: {
                ()->() in
                Logger.logm("UNATUHORIZED")
            }, onError: {
                (error) in
                Logger.loge(error?.localizedDescription ?? "ERROR")
            }, onCancelled: nil);
    }
}
