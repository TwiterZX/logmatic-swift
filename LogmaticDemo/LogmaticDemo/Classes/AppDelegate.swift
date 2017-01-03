//
//  AppDelegate.swift
//  LogmaticDemo
//
//  Created by Riad Krim on 03/01/2017.
//

import UIKit

 //TODO: Set your personal key here
private let kLogmaticApiKey:String? = nil



@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?


    // MARK: Fake Informations

    func fakeUserAgent() -> String {
        return "LogmaticDemo (Swift version)"
    }

    func fakeIpTracking() -> String {
        return "127.0.0.1"
    }


    // MARK: UIApplicationDelegate

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {

        let logmaticLogger = LogmaticLogger.shared
        logmaticLogger.apiKey = kLogmaticApiKey
        logmaticLogger.sendingFrequency = 4;
        logmaticLogger.setUserAgentTracking(userAgentTracking: self.fakeUserAgent())
        logmaticLogger.setIPTracking(ipTracking: self.fakeIpTracking())

        logmaticLogger.startLogger()
        LogmaticLogger.shared.log(dictionary: nil, message: "iOS.INFO: Application did start")

        return true
    }

}
