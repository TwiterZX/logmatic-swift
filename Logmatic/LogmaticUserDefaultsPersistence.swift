//
//  LogmaticUserDefaultsPersistence.swift
//
//  Created by Riad Krim on 31/12/2016.
//

import Foundation

private let kLogmaticUserDefaultsLogsKey:String = "io.logmatic.logmatic.user-defaults.logs"


class LogmaticUserDefaultsPersistence: LogmaticPersistence {

    public static let shared:LogmaticUserDefaultsPersistence = LogmaticUserDefaultsPersistence()


    // MARK: - LogmaticPersistence
    
    internal func add(logs: Logs?) {
        let mergedLogs:Logs? = Array<Logs>.mergeSafely(array1: logs, array2: self.savedLogs())
        self.replace(logs: mergedLogs)
    }

    internal func replace(logs: Logs?) {
        UserDefaults.standard.set(logs, forKey: kLogmaticUserDefaultsLogsKey)
        UserDefaults.standard.synchronize()
    }

    internal func savedLogs() -> Logs? {
        return UserDefaults.standard.object(forKey: kLogmaticUserDefaultsLogsKey) as! Logs?
    }

    internal func deleteAllLogs() {
        self.replace(logs: nil)
    }

}
