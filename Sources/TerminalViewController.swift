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
    var keyboardAppearance = UIKeyboardAppearance.default
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

        view.backgroundColor = .systemBackground

        view.addGestureRecognizer(
            UITapGestureRecognizer(target: self,
                                   action: #selector(becomeFirstResponder)))

        pasteConfiguration = UIPasteConfiguration(forAccepting: String.self)

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
    var cellWidth = terminal._core._renderCoordinator.dimensions.actualCellWidth;
    var cellHeight = terminal._core._renderCoordinator.dimensions.actualCellHeight;
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
terminal.setOption('theme', \(terminalTheme));
terminal.open(document.getElementById('terminal'));

  </script>
</html>
"""
        let xtermjsBundlePath = Bundle.main.path(forResource: "Xterm.js", ofType: "bundle")!
        webView.loadHTMLString(htmlString, baseURL: URL(fileURLWithPath: xtermjsBundlePath))
    }

    private var terminalTheme: String {
        let backgroundColor = UIColor.systemBackground
        let foregroundColor = UIColor.label

        return """
{
    background: '\(backgroundColor.hexRepresentation)',
    foreground: '\(foregroundColor.hexRepresentation)',
    cursor: '\(foregroundColor.hexRepresentation)'
}
"""
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        becomeFirstResponder()
    }

    override var inputAccessoryView: UIView? {
        return terminalInputAccessoryView
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .default
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)

        let javascript = "terminal.setOption('theme', \(terminalTheme));"
        webView.evaluateJavaScript(javascript, completionHandler: nil)
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
            receiveTerminalOutput(webViewQueueBeforeLoad)
            webViewQueueBeforeLoad = Data()
        }

        syncFirstResponderStatusToTerminal()
    }
}

// MARK: - Terminal I/O

extension TerminalViewController {

    func receiveTerminalOutput(_ data: Data) {
        guard webViewDidLoad else {
            webViewQueueBeforeLoad.append(data)
            return
        }

        let encoded = data.base64EncodedString()
        let javascript = "terminal.write(window.atob('\(encoded)'));"
        webView.evaluateJavaScript(javascript, completionHandler: nil)
    }

    func receiveTerminalOutput(_ string: String) {
        if let data = string.data(using: .utf8) {
            receiveTerminalOutput(data)
        }
    }

    private func sendTerminalText(_ text: String) {
        if let data = text.data(using: .utf8) {
            delegate?.terminalViewController(self, send: data)
        }
    }

    private func sendTerminalSequence(
        _ sequence: String,
        additionalModifiers: UIKeyModifierFlags = []) {

        guard let data = sequence.data(using: .ascii), !data.isEmpty else { return }

        let modifiers = terminalInputAccessoryView.enabledModifiers
            .union(additionalModifiers)

        if modifiers.contains(.alternate) {
            delegate?.terminalViewController(self, send: Data([0x1b, 0x5b]))
        }

        if modifiers.contains(.control) {
            var firstChar = data.first!
            if firstChar >= 97 && firstChar <= 122 {
                firstChar -= 32
            }
            delegate?.terminalViewController(self, send: Data([firstChar ^ 0x40]))
        }
        else {
            delegate?.terminalViewController(self, send: data)
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
        if let firstChar = text.first, firstChar.isASCII, text.count == 1 {
            sendTerminalSequence(text)
        } else {
            sendTerminalText(text)
        }
    }

    func deleteBackward() {
        sendTerminalSequence("\u{7f}")
    }
}

// MARK: - Keyboard shortcuts

extension TerminalViewController {

    private var sequenceCommands: [(UIKeyModifierFlags, String, String)] {
        return [
            ([], UIKeyCommand.inputUpArrow, "\u{1b}[A"),
            ([], UIKeyCommand.inputDownArrow, "\u{1b}[B"),
            ([], UIKeyCommand.inputLeftArrow, "\u{1b}[D"),
            ([], UIKeyCommand.inputRightArrow, "\u{1b}[C"),
            ([], UIKeyCommand.inputEscape, "\u{1b}"),
            ([.alternate], UIKeyCommand.inputLeftArrow, "\u{1b}b"),
            ([.alternate], UIKeyCommand.inputRightArrow, "\u{1b}f"),
        ]
    }

    override var keyCommands: [UIKeyCommand] {
        var keyCommands = sequenceCommands.map {
            UIKeyCommand(input: $0.1,
                         modifierFlags: $0.0,
                         action: #selector(handleSequenceCommand(_:)))
        }

        keyCommands += "ABCDEFGHIJKLMNOPQRSTUVWYXZ0123456789".map {
            [UIKeyCommand(input: String($0),
                          modifierFlags: .control,
                          action: #selector(handleModifierCommand(_:))),
             UIKeyCommand(input: String($0),
                          modifierFlags: .alternate,
                          action: #selector(handleModifierCommand(_:))),
             UIKeyCommand(input: String($0),
                          modifierFlags: [.control, .alternate],
                          action: #selector(handleModifierCommand(_:)))]
            }.reduce([], +)

        keyCommands.append(UIKeyCommand(input: "K",
                                        modifierFlags: [.command],
                                        action: #selector(handleClearCommand)))

        return keyCommands
    }

    @objc private func handleSequenceCommand(_ keyCommand: UIKeyCommand) {
        if let sequence = sequenceCommands.first(where: {
            $0.0 == keyCommand.modifierFlags && $0.1 == keyCommand.input
        }) {
            sendTerminalSequence(sequence.2)
        }
    }

    @objc private func handleModifierCommand(_ keyCommand: UIKeyCommand) {
        sendTerminalSequence(keyCommand.input!,
                            additionalModifiers: keyCommand.modifierFlags)
    }

    @objc private func handleClearCommand() {
        webView.evaluateJavaScript("terminal.clear();", completionHandler: nil)
    }
}

// MARK: - UIPasteConfigurationSupporting

extension TerminalViewController {

    override func paste(itemProviders: [NSItemProvider]) {
        guard let provider = itemProviders.first(where: {
            $0.canLoadObject(ofClass: String.self)
        }) else { return }

        _ = provider.loadObject(ofClass: String.self) { [weak self] string, error in
            if let string = string {
                DispatchQueue.main.async { [weak self] in
                    self?.sendTerminalText(string)
                }
            }
        }
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
            sequence = "\u{1b}[H"
        case .end:
            sequence = "\u{1b}[F"
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

        sendTerminalSequence(sequence)
    }
}

// MARK: - Delegate protocol

protocol TerminalViewControllerDelegate: AnyObject {

    func terminalViewController(_ viewController: TerminalViewController,
                                resizeWithColumns columns: Int,
                                rows: Int)

    func terminalViewController(
        _ viewController: TerminalViewController,
        send data: Data)
}

// MARK: - Hex colors

private extension UIColor {

    var hexRepresentation: String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 1
        getRed(&r, green: &g, blue: &b, alpha: &a)

        var components = [r, g, b]
        if a < 1 { components.append(a) }

        return "#" + components.map { String(format: "%02X", Int($0 * 255)) }.joined()
    }
}
