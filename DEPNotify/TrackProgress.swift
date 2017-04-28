//
//  TrackProgress.swift
//  DEPNotify
//
//  Created by Joel Rennich on 2/16/17.
//  Copyright © 2017 Trusource Labs. All rights reserved.
//

import Foundation

enum StatusState {
    case start
    case done
}

class TrackProgress: NSObject {
    
    // set up some defaults
    
    var path: String
    dynamic var statusText: String
    dynamic var command: String
    var status: StatusState
    let task = Process()
    let fm = FileManager()
    
    // init
    
    override init() {
        
        path = "/var/tmp/depnotify.log"
        
        for arg in 0...(CommandLine.arguments.count - 1) {
            if CommandLine.arguments[arg] == "-path" {
                guard (CommandLine.arguments.count >= arg + 1) else { continue }
                path = CommandLine.arguments[arg + 1]
                continue
            }
        }
        
        statusText = "Starting configuration"
        command = ""
        status = .start
        task.launchPath = "/usr/bin/tail"
        task.arguments = ["-f", path]
        
    }
    
    // watch for updates and post them

    func run() {

        // check to make sure the file exists

        if !fm.fileExists(atPath: path) {
            // need to make the file
            fm.createFile(atPath: path, contents: nil, attributes: nil)
        }

        let pipe = Pipe()
        task.standardOutput = pipe

        let outputHandle = pipe.fileHandleForReading
        outputHandle.waitForDataInBackgroundAndNotify()

        var dataAvailable : NSObjectProtocol!
        dataAvailable = NotificationCenter.default.addObserver(forName: NSNotification.Name.NSFileHandleDataAvailable,
                                                               object: outputHandle, queue: nil) {  notification -> Void in
                                                                let data = pipe.fileHandleForReading.availableData
                                                                if data.count > 0 {
                                                                    if let str = NSString(data: data, encoding: String.Encoding.utf8.rawValue) {
                                                                        //print("Task sent some data: \(str)")
                                                                        self.processCommands(commands: str as String)
                                                                    }
                                                                    outputHandle.waitForDataInBackgroundAndNotify()
                                                                } else {
                                                                    NotificationCenter.default.removeObserver(dataAvailable)
                                                                }
        }

        var dataReady : NSObjectProtocol!
        dataReady = NotificationCenter.default.addObserver(forName: Process.didTerminateNotification,
                                                           object: pipe.fileHandleForReading, queue: nil) { notification -> Void in
                                                            print("Task terminated!")
                                                            NotificationCenter.default.removeObserver(dataReady)
        }

        task.launch()

        statusText = "Reticulating splines..."

    }

    func processCommands(commands: String) {
        let allCommands = commands.components(separatedBy: "\n") 

        for line in allCommands {
            switch line.components(separatedBy: " ").first! {
            case "Status:" :
                statusText = line.replacingOccurrences(of: "Status: ", with: "")
            case "Command:" :
                command = line.replacingOccurrences(of: "Command: ", with: "")
            default:
                if path == "/var/log/jamf.log"
                {
                    if line.contains("jamf[") && line.contains("Installing") {

                        do {
                        let installerRegEx = try NSRegularExpression(pattern: ".*]: ", options: NSRegularExpression.Options.caseInsensitive)
                        let status = installerRegEx.stringByReplacingMatches(in: line, options: NSRegularExpression.MatchingOptions.anchored, range: NSMakeRange(0, line.characters.count), withTemplate: "")
                            statusText = status
                        } catch {
                            NSLog("Couldn't parse jamf.log")
                        }
                    }
                }
                break
            }
        }
    }
}
