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
class AppDelegate: NSObject, UIApplicationDelegate {

    func applicationDidFinishLaunching(_ application: UIApplication) {

        let emulatorCore = EmulatorCore(configPath: "/Users/fernando/Desktop/TinyEMU/temu.cfg")
        emulatorCore.run()
    }
}
