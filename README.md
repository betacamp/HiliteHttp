# HiliteHttp
HiliteSDK Http module - facilitates communication with the HILITE api

## Integration

#### CocoaPods (iOS 10+)

Install HiliteHttp via CocoaPods by adding it to your `Podfile`:

```ruby
platform :ios, '10.0'
use_frameworks!

target 'MyApp' do
    pod 'HiliteHttp', '~>0.1.4-alpha'
end
```

## Usage

```swift

import HiliteCore
import HiliteHttp

class TaskViewController: UIViewController {
  let taskAgent = TaskFeedAgent(taskService: HttpTaskService(), delegate: self)
  
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    
    taskAgent.reloadWithOnSuccess(_ onSuccess: @escaping (Array<FeedItemAgent>)->Void, onError: @escaping (Error!)->Void) {
    
    let onLoaded = { (loadedFeedItems) in 
      // do something with loaded items
    }
    
    let onError = { (error) in
      print(error.localizedDescription)
    }
    
    taskAgent.reloadWithOnSuccess(onLoaded, onError: onError)
  }
}

extension TaskViewController: TasksAgentDelegate {
  func taskAgent(_ taskAgent: TaskFeedAgent, didSelectTask: Task, presentFrom: PresentFrom?) {
    // do something with selected task
  }
}

```
