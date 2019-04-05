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
    private let machineLoader: MachineLoader
    private let emulatorCore: EmulatorCore

    override init() {
        let bundleURL = Bundle.main.url(forResource: "Machine",
                                        withExtension: "bundle")!
        machineLoader = MachineLoader()
        try! machineLoader.load(Bundle(url: bundleURL)!)

        emulatorCore = EmulatorCore(configPath:
            machineLoader.configFileURL.path)

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
        terminalViewController.receiveTerminalOutput(data)
    }
}

extension AppDelegate: TerminalViewControllerDelegate {

    func terminalViewController(_ viewController: TerminalViewController,
                                resizeWithColumns columns: Int,
                                rows: Int) {
        emulatorCore.resize(withColumns: columns, rows: rows)
    }

    func terminalViewController(_ viewController: TerminalViewController,
                                send data: Data) {
        emulatorCore.sendInput(data)
    }
}
