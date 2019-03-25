//
//  AppDelegate.swift
//  TinyEMU-iOS
//
//  Created by Fernando Lemos on 3/24/19.
//
//  Refer to the LICENSE file for licensing information.
//

import UIKit


@UIApplicationMain
class AppDelegate: NSObject, UIApplicationDelegate, EmulatorCoreDelegate {

    private var window: UIWindow?
    private var rootViewController: TerminalViewController!
    private let emulatorCore: EmulatorCore

    override init() {
        emulatorCore = EmulatorCore(configPath: "/Users/fernando/Desktop/TinyEMU/temu.cfg")
        super.init()
    }

    func applicationDidFinishLaunching(_ application: UIApplication) {
        let window = UIWindow(frame: UIScreen.main.bounds)
        self.window = window

        rootViewController = TerminalViewController()
        window.rootViewController = rootViewController
        window.makeKeyAndVisible()

        emulatorCore.delegate = self
        emulatorCore.start()
    }

    func emulatorCore(_ core: EmulatorCore, didReceiveOutput data: Data) {
        FileHandle.standardError.write(data)
    }
}