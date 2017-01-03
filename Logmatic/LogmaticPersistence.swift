//
//  LogmaticPersistence.swift
//
//  Created by Riad Krim on 31/12/2016.
//

import Foundation


protocol LogmaticPersistence {
    func add(logs: Logs?)
    func replace(logs: Logs?)
    func savedLogs() -> Logs?
    func deleteAllLogs()
}
