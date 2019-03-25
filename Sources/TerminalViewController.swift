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

    weak var delegate: TerminalViewControllerDelegate?

    private var webView: WKWebView!

    private var webViewDidLoad = false
    private var webViewQueueBeforeLoad = Data()

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .black

        webView = WKWebView(frame: view.bounds)
        webView.isUserInteractionEnabled = false
        webView.isOpaque = false
        webView.navigationDelegate = self
        view.addSubview(webView)

        let htmlString = """
<!doctype html>
<html>
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="height=device-height, initial-scale=1.0, user-scalable=no, minimum-scale=1.0, maximum-scale=1.0" />
    <link rel="stylesheet" href="xterm.css" />
    <style type="text/css">
#terminal textarea { display: none; }
    </style>
    <script src="xterm.js"></script>
    <script src="xterm-fit.js"></script>
  </head>
  <body>
    <div id="terminal"></div>
  </body>
  <script>
Terminal.applyAddon(fit);
var terminal = new Terminal({
    rendererType: 'dom',
    fontFamily: 'monaco',
});
terminal.open(document.getElementById('terminal'));
terminal.fit();
  </script>
</html>
"""
        let xtermjsBundlePath = Bundle.main.path(forResource: "Xterm.js", ofType: "bundle")!
        webView.loadHTMLString(htmlString, baseURL: URL(fileURLWithPath: xtermjsBundlePath))
    }

    override func viewWillAppear(_ animated: Bool) {
        becomeFirstResponder()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        webView.frame = view.bounds
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    override var canBecomeFirstResponder: Bool {
        return true
    }

    func write(_ data: Data) {
        guard webViewDidLoad else {
            webViewQueueBeforeLoad.append(data)
            return
        }

        let encoded = data.base64EncodedString()
        let javascript = "terminal.write(window.atob('\(encoded)'));"
        webView.evaluateJavaScript(javascript, completionHandler: nil)
    }

    func write(_ string: String) {
        if let data = string.data(using: .utf8) {
            write(data)
        }
    }
}

extension TerminalViewController: WKNavigationDelegate {

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        webViewDidLoad = true
        if !webViewQueueBeforeLoad.isEmpty {
            write(webViewQueueBeforeLoad)
            webViewQueueBeforeLoad = Data()
        }
    }
}

extension TerminalViewController: UIKeyInput {

    var hasText: Bool {
        return true
    }

    func insertText(_ text: String) {
        delegate?.terminalViewController(self, write: text)
    }

    func deleteBackward() {
        delegate?.terminalViewController(self, write: "\u{7f}")
    }
}

protocol TerminalViewControllerDelegate: AnyObject {

    func terminalViewController(_ viewController: TerminalViewController, write text: String)
}
