import Foundation
import HiliteCore

open class TaskFeedAgent: FiltersByFeedAgent {
    let taskService: TaskService!
    let delegate: TasksAgentDelegate?
    public var tasks:Array<Task>! =  Array<Task>()
    public var feedItemAgents = Dictionary<String, TaskBackedFeedItemAgent>()
    
    public init(taskService: TaskService, delegate: TasksAgentDelegate?) {
        self.taskService = taskService
        self.delegate = delegate

        clearItemAgents()
    }

    public func clearItemAgents() {
        feedItemAgents = Dictionary<String, TaskBackedFeedItemAgent>()
    }

    public func reloadWithOnSuccess(_ onSuccess: @escaping (Array<FeedItemAgent>)->Void, onError: @escaping (Error!)->Void) {
        taskService.loadTasks(
            {   [weak self]
                (loadedTasks) in
                self?.clearItemAgents()
                self?.tasks = loadedTasks
                self?.ensureFeedItemAgents()
                self?.withFeedItemAgents({ (itemAgents) -> () in
                    onSuccess(itemAgents)
                })
            },
            onError: { (error) in
                print(error.localizedDescription)
            })
    }
    
    public func numberOfFeedItems() -> Int {
        return self.tasks.count;
    }
    
    public func feedItemAgentAtIndexPath(_ indexPath: IndexPath) -> FeedItemAgent? {
        if (indexPath as NSIndexPath).row >= tasks.count { return nil }
        let task = tasks[(indexPath as NSIndexPath).row]
        var agent = feedItemAgents[task.id()!]
        if (agent == nil) {
            agent = TaskBackedFeedItemAgent(task: task)
            feedItemAgents[task.id()!] = agent
        }
        return agent!
    }

    public func selectFeedItemAgent(_ feedItemAgent: FeedItemAgent!, presentFrom: PresentFrom?) {
        let taskFeedItemAgent = feedItemAgent as! TaskBackedFeedItemAgent!
        let task = taskFeedItemAgent?.task

        self.delegate?.taskAgent(self, didSelectTask:task!, presentFrom:presentFrom)
    }

    public func canHandleFeedItemAgent(_ feedItemAgent: FeedItemAgent!) -> Bool {
        return feedItemAgent.type() == FeedItemAgentType.task
    }
    
    public func cancelLoading() {
        taskService.cancelLoading()
    }
    
    public func feedItemIsDisplayable(_ feedItemAgent: FeedItemAgent!) -> Bool {
        return true
    }
    
    public func withFeedItemAgents(_ withBlock: @escaping (Array<FeedItemAgent>!) -> ()) {
        var itemAgents = Array<FeedItemAgent>()
        for (_, itemAgent) in feedItemAgents {
            itemAgents.append(itemAgent)
        }
        
        withBlock(itemAgents)
    }
    
    public func filterByFeedAgent(_ feedAgent: FeedAgent!) {
        
    }
    
    public func ensureFeedItemAgents() {
        for (index, _) in tasks.enumerated() {
            self.feedItemAgentAtIndexPath(IndexPath(row: index, section: 0))
        }
    }
    
    public func isEmpty() -> Bool {
        
        return self.numberOfFeedItems() < 1 || numberOfDisplayableFeedItems() < 1
    }
    
    public func numberOfDisplayableFeedItems() -> Int {
        var count:Int = 0
        for (_, feedItemAgent) in self.feedItemAgents {
            if self.feedItemIsDisplayable(feedItemAgent) { count += 1 }
        }
        
        return count
    }
}
