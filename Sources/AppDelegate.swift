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
class AppDelegate: NSObject {

    var window: UIWindow?
    private var terminalViewController: TerminalViewController!
    private let emulatorCore: EmulatorCore

    override init() {
        emulatorCore = EmulatorCore(configPath: "/Users/fernando/Desktop/TinyEMU/temu.cfg")
        super.init()
    }
}

extension AppDelegate: UIApplicationDelegate {

    func applicationDidFinishLaunching(_ application: UIApplication) {
        let window = UIWindow(frame: UIScreen.main.bounds)
        self.window = window

        terminalViewController = TerminalViewController()
        terminalViewController.delegate = self
        window.rootViewController = terminalViewController
        window.makeKeyAndVisible()

        emulatorCore.delegate = self
        emulatorCore.start()
    }
}

extension AppDelegate: EmulatorCoreDelegate {

    func emulatorCore(_ core: EmulatorCore, didReceiveOutput data: Data) {
        terminalViewController.write(data)
    }
}

extension AppDelegate: TerminalViewControllerDelegate {

    func terminalViewController(_ viewController: TerminalViewController, write text: String) {
        if let data = text.data(using: .utf8) {
            emulatorCore.write(data)
        }
    }
}
