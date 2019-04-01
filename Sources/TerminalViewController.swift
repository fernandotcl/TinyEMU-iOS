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

    private var terminalInputAccessoryView: TerminalInputAccessoryView!

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

        terminalInputAccessoryView = TerminalInputAccessoryView()
        terminalInputAccessoryView.delegate = self

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
    var cellWidth = terminal._core.renderer.dimensions.actualCellWidth;
    var cellHeight = terminal._core.renderer.dimensions.actualCellHeight;
    var columns = Math.floor(width / cellWidth);
    var rows = Math.floor(height / cellHeight);
    terminal.resize(columns, rows);
    terminal.scrollToBottom();
    return { columns: columns, rows: rows };
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

    override var inputAccessoryView: UIView? {
        return terminalInputAccessoryView
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
        webView.evaluateJavaScript(javascript) { [weak self] object, error in
            if let self = self,
                let dict = object as? Dictionary<AnyHashable, Any>,
                let columns = dict["columns"] as? Int,
                let rows = dict["rows"] as? Int {
                self.delegate?.terminalViewController(self,
                                                      resizeWithColumns: columns,
                                                      rows: rows)
            }
        }
    }

    @objc private func keyboardWillChangeFrame(_ notification: Notification) {
        let frameKey = UIApplication.keyboardFrameEndUserInfoKey
        guard let frame = (notification.userInfo?[frameKey] as? NSValue)?
            .cgRectValue else { return }

        let intersection = view.bounds.intersection(frame)
        let inset: CGFloat
        if intersection.isNull {
            inset = 0
        } else {
            inset = intersection.height
        }

        if inset != keyboardInset {
            keyboardInset = inset
            view.setNeedsLayout()
        }
    }
}

// MARK: - Navigation delegate

extension TerminalViewController: WKNavigationDelegate {

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        refitTerminal()

        webViewDidLoad = true
        if !webViewQueueBeforeLoad.isEmpty {
            handleTerminalOutput(webViewQueueBeforeLoad)
            webViewQueueBeforeLoad = Data()
        }

        syncFirstResponderStatusToTerminal()
    }
}

// MARK: - Terminal I/O

extension TerminalViewController {

    func handleTerminalOutput(_ data: Data) {
        guard webViewDidLoad else {
            webViewQueueBeforeLoad.append(data)
            return
        }

        let encoded = data.base64EncodedString()
        let javascript = "terminal.write(window.atob('\(encoded)'));"
        webView.evaluateJavaScript(javascript, completionHandler: nil)
    }

    func handleTerminalOutput(_ string: String) {
        if let data = string.data(using: .utf8) {
            handleTerminalOutput(data)
        }
    }

    private func handleTerminalInput(
        _ input: String,
        additionalModifiers: UIKeyModifierFlags = []) {

        var sequence = input

        let modifiers = terminalInputAccessoryView.enabledModifiers
            .union(additionalModifiers)

        if modifiers.contains(.control) {
            if let character = sequence.uppercased().first?.asciiValue {
                sequence = String(UnicodeScalar(character ^ 0x40))
            }
        }
        if modifiers.contains(.alternate) {
            sequence = "\u{1b}[" + sequence
        }

        delegate?.terminalViewController(self, write: sequence)

        terminalInputAccessoryView.clearModifiers()
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
        handleTerminalInput(text)
    }

    func deleteBackward() {
        handleTerminalInput("\u{7f}")
    }
}

// MARK: - Keyboard shortcuts

extension TerminalViewController {

    override var keyCommands: [UIKeyCommand] {
        var keyCommands = [
            UIKeyCommand(input: UIKeyCommand.inputUpArrow,
                         modifierFlags: [],
                         action: #selector(handleKeyCommandArrowUp)),
            UIKeyCommand(input: UIKeyCommand.inputDownArrow,
                         modifierFlags: [],
                         action: #selector(handleKeyCommandArrowDown)),
            UIKeyCommand(input: UIKeyCommand.inputLeftArrow,
                         modifierFlags: [],
                         action: #selector(handleKeyCommandArrowLeft)),
            UIKeyCommand(input: UIKeyCommand.inputRightArrow,
                         modifierFlags: [],
                         action: #selector(handleKeyCommandArrowRight)),
            UIKeyCommand(input: UIKeyCommand.inputEscape,
                         modifierFlags: [],
                         action: #selector(handleKeyCommandEscape)),
            UIKeyCommand(input: "K",
                         modifierFlags: [.command],
                         action: #selector(handleKeyCommandClear))
        ]
        keyCommands += "ABCDEFGHIJKLMNOPQRSTUVWYXZ0123456789".map {
            [UIKeyCommand(input: String($0),
                          modifierFlags: .control,
                          action: #selector(handleKeyCommandModifier(_:))),
             UIKeyCommand(input: String($0),
                          modifierFlags: .alternate,
                          action: #selector(handleKeyCommandModifier(_:))),
             UIKeyCommand(input: String($0),
                          modifierFlags: [.control, .alternate],
                          action: #selector(handleKeyCommandModifier(_:)))]
        }.reduce([], +)
        return keyCommands
    }

    @objc private func handleKeyCommandArrowUp() {
        handleTerminalInput("\u{1b}[A")
    }

    @objc private func handleKeyCommandArrowDown() {
        handleTerminalInput("\u{1b}[B")
    }

    @objc private func handleKeyCommandArrowLeft() {
        handleTerminalInput("\u{1b}[D")
    }

    @objc private func handleKeyCommandArrowRight() {
        handleTerminalInput("\u{1b}[C")
    }

    @objc private func handleKeyCommandEscape() {
        handleTerminalInput("\u{1b}")
    }

    @objc private func handleKeyCommandClear() {
        webView.evaluateJavaScript("terminal.clear();", completionHandler: nil)
    }

    @objc private func handleKeyCommandModifier(_ keyCommand: UIKeyCommand) {
        handleTerminalInput(keyCommand.input!,
                            additionalModifiers: keyCommand.modifierFlags)
    }
}

// MARK: - Input accessory view delegate

extension TerminalViewController: TerminalInputAccessoryViewDelegate {

    func terminalInputAccessoryView(
        _ view: TerminalInputAccessoryView,
        didTapKey key: TerminalInputAccessoryView.Key) {

        let sequence: String
        switch key {
        case .escape:
            sequence = "\u{1b}"
        case .tab:
            sequence = "\t"
        case .home:
            sequence = "\u{01}"
        case .end:
            sequence = "\u{05}"
        case .arrowLeft:
            sequence = "\u{1b}[D"
        case .arrowUp:
            sequence = "\u{1b}[A"
        case .arrowDown:
            sequence = "\u{1b}[B"
        case .arrowRight:
            sequence = "\u{1b}[C"
        default:
            return
        }

        handleTerminalInput(sequence)
    }
}

// MARK: - Delegate protocol

protocol TerminalViewControllerDelegate: AnyObject {

    func terminalViewController(_ viewController: TerminalViewController,
                                resizeWithColumns columns: Int,
                                rows: Int)

    func terminalViewController(_ viewController: TerminalViewController,
        write text: String)
}
