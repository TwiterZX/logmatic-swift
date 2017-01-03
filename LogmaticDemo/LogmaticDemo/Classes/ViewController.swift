//
//  ViewController.swift
//  LogmaticDemo
//
//  Created by Riad Krim on 03/01/2017.
//

import UIKit

class ViewController: UIViewController {

    @IBOutlet weak var apiKeyValueLabel: UILabel!
    @IBOutlet weak var clickCountValueLabel: UILabel!
    @IBOutlet weak var sendLogButton: UIButton!
    
    private var clickCount:Int = 0


    override func viewDidLoad() {
        super.viewDidLoad()

        self.customizeUI()
        self.updateClickCount()
    }

    func customizeUI() -> Void {
        if LogmaticLogger.shared.apiKey == nil {
            self.apiKeyValueLabel.text = "Not Set"
            self.apiKeyValueLabel.textColor = UIColor.red
            self.sendLogButton.isEnabled = false
        }
        else {
            self.apiKeyValueLabel.text = LogmaticLogger.shared.apiKey
            self.apiKeyValueLabel.textColor = UIColor.green
            self.sendLogButton.isEnabled = true
        }
    }

    func updateClickCount() -> Void {
        self.clickCountValueLabel.text = "\(self.clickCount)"
    }

    @IBAction func sendLog(_ sender: UIButton) {
        print("sendLog triggered")
        clickCount += 1
        self.updateClickCount()

        let logInfo:[String : Int] = ["clickCount" : clickCount]
        LogmaticLogger.shared.log(dictionary: logInfo, message: "iOS.INFO: Log Action")
    }

}
