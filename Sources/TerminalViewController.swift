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

    var autocapitalizationType = UITextAutocapitalizationType.none
    var autocorrectionType = UITextAutocorrectionType.no
    var keyboardAppearance = UIKeyboardAppearance.dark
    var returnKeyType = UIReturnKeyType.default

    private var webView: WKWebView!

    private var webViewDidLoad = false
    private var webViewQueueBeforeLoad = Data()

    private var keyboardInset: CGFloat = 0

    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {

        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)

        NotificationCenter.default
            .addObserver(self,
                         selector: #selector(keyboardWillChangeFrame),
                         name: UIApplication.keyboardWillChangeFrameNotification,
                         object: nil)
    }

    required init?(coder aDecoder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .black

        view.addGestureRecognizer(
            UITapGestureRecognizer(target: self,
                                   action: #selector(becomeFirstResponder)))

        webView = WKWebView(frame: view.bounds)
        webView.isUserInteractionEnabled = false
        webView.isOpaque = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
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

body { margin: 0; }
#terminal textarea { display: none; }

    </style>
    <script src="xterm.js"></script>
  </head>
  <body>
    <div id="terminal"></div>
  </body>
  <script>

function refit(width, height) {
    var cellWidth = terminal._core.renderer.dimensions.actualCellWidth
    var cellHeight = terminal._core.renderer.dimensions.actualCellHeight
    terminal.resize(Math.floor(width / cellWidth),
                    Math.floor(height / cellHeight))
    terminal.scrollToBottom()
}

var terminal = new Terminal({
    rendererType: 'dom',
    fontFamily: 'monaco'
});
terminal.open(document.getElementById('terminal'));

  </script>
</html>
"""
        let xtermjsBundlePath = Bundle.main.path(forResource: "Xterm.js", ofType: "bundle")!
        webView.loadHTMLString(htmlString, baseURL: URL(fileURLWithPath: xtermjsBundlePath))
    }

    override func viewWillAppear(_ animated: Bool) {
        becomeFirstResponder()
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
}

// MARK: - Layout

extension TerminalViewController {

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        let oldSize = webView.frame.size
        let safeAreaInsets = view.safeAreaInsets

        // Add a bit of margin if there's a 20pt status bar
        let topMargin = safeAreaInsets.top == 20 ? 25 : safeAreaInsets.top

        // Take safe area insets, margin and keyboard inset into account
        var frame = view.bounds
        frame.origin.x += safeAreaInsets.left
        frame.origin.y += topMargin
        frame.size.width -= safeAreaInsets.left + safeAreaInsets.right
        frame.size.height -= topMargin
        frame.size.height -= max(keyboardInset, safeAreaInsets.bottom)
        webView.frame = frame

        if frame.size != oldSize && webViewDidLoad {
            refitTerminal()
        }
    }

    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        view.setNeedsLayout()
    }

    private func refitTerminal() {
        let size = webView.frame.size
        let javascript = "refit(\(size.width), \(size.height));"
        webView.evaluateJavaScript(javascript, completionHandler: nil)
    }

    @objc private func keyboardWillChangeFrame(_ notification: Notification) {
        let frameKey = UIApplication.keyboardFrameEndUserInfoKey
        if let frame = (notification.userInfo?[frameKey] as? NSValue)?.cgRectValue,
            frame.height != keyboardInset {
            keyboardInset = frame.height
            if isViewLoaded {
                view.setNeedsLayout()
            }
        }
    }
}

// MARK: - Navigation delegate

extension TerminalViewController: WKNavigationDelegate {

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        refitTerminal()

        webViewDidLoad = true
        if !webViewQueueBeforeLoad.isEmpty {
            write(webViewQueueBeforeLoad)
            webViewQueueBeforeLoad = Data()
        }

        syncFirstResponderStatusToTerminal()
    }
}

// MARK: - Terminal output

extension TerminalViewController {

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

// MARK: - First responder management

extension TerminalViewController {

    override var canBecomeFirstResponder: Bool {
        return true
    }

    @discardableResult
    override func becomeFirstResponder() -> Bool {
        guard super.becomeFirstResponder() else { return false }
        syncFirstResponderStatusToTerminal()
        return true
    }

    @discardableResult
    override func resignFirstResponder() -> Bool {
        guard super.resignFirstResponder() else { return false }
        syncFirstResponderStatusToTerminal()
        return true
    }

    private func syncFirstResponderStatusToTerminal() {
        if isFirstResponder {
            webView.evaluateJavaScript("terminal.emit('focus');", completionHandler: nil)
        } else {
            webView.evaluateJavaScript("terminal.emit('blur');", completionHandler: nil)
        }
    }
}

// MARK: - UIKeyInput

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

// MARK: - Keyboard shortcuts

extension TerminalViewController {

    override var keyCommands: [UIKeyCommand] {
        return [
            UIKeyCommand(input: UIKeyCommand.inputUpArrow,
                         modifierFlags: [],
                         action: #selector(keyCommandArrowUp)),
            UIKeyCommand(input: UIKeyCommand.inputDownArrow,
                         modifierFlags: [],
                         action: #selector(keyCommandArrowDown)),
            UIKeyCommand(input: UIKeyCommand.inputLeftArrow,
                         modifierFlags: [],
                         action: #selector(keyCommandArrowLeft)),
            UIKeyCommand(input: UIKeyCommand.inputRightArrow,
                         modifierFlags: [],
                         action: #selector(keyCommandArrowRight)),
            UIKeyCommand(input: UIKeyCommand.inputEscape,
                         modifierFlags: [],
                         action: #selector(keyCommandEscape))
        ]
    }

    @objc private func keyCommandArrowUp() {
        delegate?.terminalViewController(self, write: "\u{1b}[A")
    }

    @objc private func keyCommandArrowDown() {
        delegate?.terminalViewController(self, write: "\u{1b}[B")
    }

    @objc private func keyCommandArrowLeft() {
        delegate?.terminalViewController(self, write: "\u{1b}[D")
    }

    @objc private func keyCommandArrowRight() {
        delegate?.terminalViewController(self, write: "\u{1b}[C")
    }

    @objc private func keyCommandEscape() {
        delegate?.terminalViewController(self, write: "\u{1b}")
    }
}

// MARK: - Delegate protocol

protocol TerminalViewControllerDelegate: AnyObject {

    func terminalViewController(_ viewController: TerminalViewController, write text: String)
}
