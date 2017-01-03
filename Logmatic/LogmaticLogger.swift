//
//  LogmaticLogger.swift
//
//  Created by Riad Krim on 03/01/2017.
//

import Foundation


private let kLogmaticApiRootUrl:String                      = "https://api.logmatic.io/v1/input"
private let kLogmaticMessageKey:String                      = "message"
private let kLogmaticTimestampKey:String                    = "timestamp"
private let kLogmaticIpTrackingHeaderKey:String             = "X-Logmatic-Add-IP"
private let kLogmaticUserAgentTrackingHeaderKey:String      = "X-Logmatic-Add-UserAgent"
private let kLogmaticLoggingPrefix:String                   = "[Logmatic]"
private let kLogmaticDefaultSendingFrequency:TimeInterval   = 20

public enum LogmaticLogLevel : Int {
    case none
    case short
    case verbose
}

typealias LogDictionary = [AnyHashable : Any]
typealias Logs = [ LogDictionary ]
typealias IndexedLogs = [Int : Logs]

class LogmaticLogger : NSObject {
    
    public static let shared = LogmaticLogger()
    
    public var apiKey:String?
    public var metas:[AnyHashable : Any]?
    public var sendingFrequency:TimeInterval {
        didSet {
            if sendingFrequency < 1 {
                print("Warning: setting a too small sendingFrequency deteriorates phone performance")
            }
        }
    }
    public var usePersistence:Bool {
        get {
            return self.delegate != nil
        }
        set(use) {
            self.delegate = use ? LogmaticUserDefaultsPersistence.shared : nil
        }
    }
    public var logLevel:LogmaticLogLevel
    
    private var askedToWork:Bool
    private var sendingTimer:Timer?
    private var ongoingRequests:IndexedLogs
    private var pendingLogs:Logs
    private var delegate:LogmaticPersistence?
    lazy private var session:URLSession = {
        return self.createSession()
    } ()
    
    
    
    // MARK: - Initializer
    
    private override init() {
        self.sendingFrequency = kLogmaticDefaultSendingFrequency
        self.logLevel = .verbose
        self.askedToWork = false
        self.ongoingRequests = IndexedLogs()
        self.pendingLogs = Logs()
        
        super.init()
        self.addNotificationObserver()
        self.usePersistence = true
    }
    
    deinit {
        self.removeNotificationObserver()
        self.stop()
    }
    
    
    // MARK: - LogmaticLogger
    
    func startLogger() {
        self.askedToWork = true
        self.start()
    }
    
    private func stopLogger() {
        self.askedToWork = false
        self.stop()
    }
    
    public func log(dictionary: LogDictionary?, message: String) {
        precondition(self.apiKey != nil, "Logmatic API Key required. Get one from Logmatic.io > Configuration > API keys")
        
        guard message.characters.count > 0  || dictionary != nil else {
            print("a message or a citionary is needed")
            return
        }
        
        var logmaticDictionary = LogDictionary()
        logmaticDictionary[kLogmaticTimestampKey] = Date().timeIntervalSince1970 * 1000
        
        if self.metas != nil {
            for (key, value) in self.metas! {
                logmaticDictionary[key] = value
            }
        }
        
        if message.characters.count > 0 {
            logmaticDictionary[kLogmaticMessageKey] = message
        }
        
        if dictionary != nil && !dictionary!.isEmpty {
            for (key, value) in dictionary! {
                logmaticDictionary[key] = value
            }
        }
        self.pendingLogs.append(logmaticDictionary)
    }
    
    private func addSessionConfiguration(header: String, value: String) {
        var headers = self.session.configuration.httpAdditionalHeaders
        if headers == nil {
            headers = [AnyHashable: Any](minimumCapacity: 1)
        }
        headers![header] = value
        self.session.configuration.httpAdditionalHeaders = headers
    }
    
    public func setIPTracking(ipTracking: String) {
        self.addSessionConfiguration(header: kLogmaticIpTrackingHeaderKey, value: ipTracking)
    }
    
    public func setUserAgentTracking(userAgentTracking: String) {
        self.addSessionConfiguration(header: kLogmaticUserAgentTrackingHeaderKey, value: userAgentTracking)
    }
    
    
    // MARK: - Private
    // MARK: Init
    
    private func createSession() -> URLSession {
        return URLSession(configuration: URLSessionConfiguration.default)
    }
    
    private func start() {
        self.loadSavedLogs()
        self.sendingTimer = self.createAndStartTimer()
    }
    
    private func createAndStartTimer() -> Timer {
        let sendingTimer = Timer.scheduledTimer(timeInterval:self.sendingFrequency, target:self, selector: #selector(self.sendPendingLogsAndSync), userInfo: nil, repeats: true)
        sendingTimer.fire()
        return sendingTimer
    }
    
    private func addNotificationObserver() {
        NotificationCenter.default.addObserver(self, selector: #selector(self.didEnterBackground), name: NSNotification.Name.UIApplicationDidEnterBackground, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.willEnterForeground), name: NSNotification.Name.UIApplicationWillEnterForeground, object: nil)
    }
    
    
    // MARK: Stop
    
    private func stop() {
        self.stopTimersAndDelete()
        self.saveAndClearAllLogs()
    }
    
    private func stopTimersAndDelete() {
        self.sendingTimer?.invalidate()
        self.sendingTimer = nil
    }
    
    private func removeNotificationObserver() {
        NotificationCenter.default.removeObserver(self)
    }
    
    
    // MARK: Workflow
    
    @objc private func sendPendingLogsAndSync() {
        if (self.apiKey != nil) && self.pendingLogs.count > 0 {
            let dataTask = self.send(logs: self.pendingLogs)
            self.ongoingRequests[dataTask.taskIdentifier] = self.pendingLogs
            self.pendingLogs.removeAll()
        }
    }
    
    private func send(logs: [[AnyHashable: Any]]) -> URLSessionDataTask {
        
        var dataTask:URLSessionDataTask? = nil
        dataTask = self.session.dataTask(with: self.request(withLogs: logs)) { (data:Data?, response:URLResponse?, error:Error?) in
            let httpResponse = (response as! HTTPURLResponse)
            if httpResponse.statusCode == 200 {
                self.requestSucceeded(with: dataTask!)
            }
            else {
                self.requestFailed(with: dataTask!, error: error)
            }
        }
        dataTask?.resume()
        return dataTask!
    }
    
    private func request(withLogs logs: [[AnyHashable: Any]]) -> URLRequest {
        let url = URL(string: "\(kLogmaticApiRootUrl)/\(self.apiKey!)")!
        let request = NSMutableURLRequest(url: url, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 60)
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.httpMethod = "POST"
        
        do {
            let postData:Data = try JSONSerialization.data(withJSONObject: logs, options: [])
            request.httpBody = postData
        } catch let error {
            print(error)
        }
        
        return request as URLRequest
    }
    
    private func requestSucceeded(with task:URLSessionDataTask) {
        let taskIdentifier:Int = task.taskIdentifier
        let succeededLogs = self.ongoingRequests[taskIdentifier]
        self.ongoingRequests.removeValue(forKey: taskIdentifier)
        let successMessage = "\(kLogmaticLoggingPrefix) \(succeededLogs?.count) log(s) sent successfully."
        
        switch self.logLevel {
        case .short:
            print("\(successMessage)")
        case .verbose:
            print("\(successMessage) Logs:\n\(succeededLogs)")
        default:
            break
        }
    }
    
    private func requestFailed(with task: URLSessionDataTask, error: Error?) {
        let taskIdentifier:Int = task.taskIdentifier
        let failedLogs = self.ongoingRequests[taskIdentifier]
        self.ongoingRequests.removeValue(forKey: taskIdentifier)
        
        var sentLater = false
        
        if error != nil && failedLogs != nil && failedLogs!.count > 0 {
            sentLater = true
            self.pendingLogs = Array<Logs>.mergeSafely(array1: failedLogs, array2: self.pendingLogs)!
        }
        
        let failureMessage = "\(kLogmaticLoggingPrefix) Failed to send \(failedLogs?.count) log(s). Sent later: \(sentLater ? "YES" : "NO")."
        
        switch self.logLevel {
        case .short:
            print("\(failureMessage)")
        case .verbose:
            print("\(failureMessage) Logs:\n\(failedLogs)")
        default:
            break
        }
    }
    
    
    // MARK: Notifs
    
    func willEnterForeground() {
        if askedToWork {
            self.start()
        }
    }
    
    func didEnterBackground() {
        self.stop()
    }
    
    
    // MARK: Persistence
    
    private func loadSavedLogs() {
        let savedLogs = self.delegate?.savedLogs()
        if savedLogs != nil && !savedLogs!.isEmpty {
            self.pendingLogs += savedLogs!
        }
        delegate?.deleteAllLogs()
    }
    
    private func saveAndClearAllLogs() {
        self.delegate?.replace(logs: self.pendingLogs)
        pendingLogs.removeAll()
        ongoingRequests.removeAll()
    }
    
}
