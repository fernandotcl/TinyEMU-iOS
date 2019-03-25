//
//  TerminalViewController.swift
//  TinyEMU-iOS
//
//  Created by Fernando Lemos on 3/25/19.
//
//  Refer to the LICENSE file for licensing information.
//

import UIKit
import WebKit


class TerminalViewController: UIViewController {

    private var webView: WKWebView!

    override func viewDidLoad() {
        super.viewDidLoad()

        webView = WKWebView(frame: view.bounds)
        view.addSubview(webView)

        let xtermBundlePath = Bundle.main.path(forResource: "Xterm.js", ofType: "bundle")!
        let xtermBundle = Bundle(path: xtermBundlePath)!
        let xtermJavascript = xtermBundle.path(forResource: "xterm", ofType: "js")!
        let xtermCSS = xtermBundle.path(forResource: "xterm", ofType: "css")!
        print("Javascript: \(xtermJavascript) CSS: \(xtermCSS)")
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        webView.frame = view.bounds
    }
}
