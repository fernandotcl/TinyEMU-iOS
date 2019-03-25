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


class TerminalViewController: UIViewController, WKNavigationDelegate {

    private var webView: WKWebView!

    private var webViewDidLoad = false
    private var webViewQueueBeforeLoad = Data()

    override func viewDidLoad() {
        super.viewDidLoad()

        webView = WKWebView(frame: view.bounds)
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
  </head>
  <body>
    <div id="terminal"></div>
  </body>
  <script>
var terminal = new Terminal();
terminal.open(document.getElementById('terminal'));
  </script>
</html>
"""
        let xtermjsBundlePath = Bundle.main.path(forResource: "Xterm.js", ofType: "bundle")!
        webView.loadHTMLString(htmlString, baseURL: URL(fileURLWithPath: xtermjsBundlePath))
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        webView.frame = view.bounds
    }

    func write(data: Data) {
        guard webViewDidLoad else {
            webViewQueueBeforeLoad.append(data)
            return
        }

        let encoded = data.base64EncodedString()
        let javascript = "terminal.write(window.atob('\(encoded)'));"
        webView.evaluateJavaScript(javascript, completionHandler: nil)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        webViewDidLoad = true
        if !webViewQueueBeforeLoad.isEmpty {
            write(data: webViewQueueBeforeLoad)
            webViewQueueBeforeLoad = Data()
        }
    }
}
