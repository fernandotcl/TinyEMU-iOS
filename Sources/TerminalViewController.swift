//
//  TerminalViewController.swift
//  TinyEMU-iOS
//
//  Created by Fernando Lemos on 3/25/19.
//
//  Refer to the LICENSE file for licensing information.
//

import SwiftTerm
import UIKit
import WebKit


class TerminalViewController: UIViewController {

    weak var delegate: TerminalViewControllerDelegate?

    private var terminalView: TerminalView!
    private var terminalInputAccessoryView: TerminalInputAccessoryView!

    private var keyboardInset: CGFloat = 0

    private var tapGestureRecognizer: UIGestureRecognizer!

    override func viewDidLoad() {
        super.viewDidLoad()

        terminalView = TerminalView()
        terminalView.terminalDelegate = self
        view.addSubview(terminalView)

        terminalInputAccessoryView = TerminalInputAccessoryView()
        terminalInputAccessoryView.delegate = self
        terminalView.inputAccessoryView = terminalInputAccessoryView

        setupColors()

        tapGestureRecognizer = UITapGestureRecognizer(
            target: self, action: #selector(tapGestureRecognizerCallback))
        tapGestureRecognizer.delegate = self
        view.addGestureRecognizer(tapGestureRecognizer)

        NotificationCenter.default
            .addObserver(self,
                         selector: #selector(keyboardWillChangeFrame),
                         name: UIApplication.keyboardWillChangeFrameNotification,
                         object: nil)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        terminalView.becomeFirstResponder()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)

        setupColors()
    }

    private func setupColors() {
        view.backgroundColor = .systemBackground

        terminalView.backgroundColor = .systemBackground
        terminalView.nativeBackgroundColor = .systemBackground
        terminalView.nativeForegroundColor = .label
    }
}

// MARK: - Layout

extension TerminalViewController {

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        var margins = view.safeAreaInsets
        margins.top = max(margins.top, 25)
        margins.left = max(margins.left, 5)
        margins.bottom = max(max(margins.top, 5), keyboardInset)
        margins.right = max(margins.right, 5)
        terminalView.frame = view.bounds.inset(by: margins)
    }

    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()

        view.setNeedsLayout()
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

// MARK: - Terminal I/O

extension TerminalViewController {

    func receiveTerminalOutput(_ data: Data) {
        terminalView.feed(byteArray: [UInt8](data)[...])
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

// MARK: - Terminal view delegate

extension TerminalViewController: TerminalViewDelegate {

    func sizeChanged(source: TerminalView, newCols: Int, newRows: Int) {
        delegate?.terminalViewController(self, resizeWithColumns: newCols, rows: newRows)
    }

    func setTerminalTitle(source: TerminalView, title: String) {}

    func send(source: TerminalView, data: ArraySlice<UInt8>) {
        delegate?.terminalViewController(self, send: Data(data))
    }

    func scrolled(source: TerminalView, position: Double) {}
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

// MARK: - Gestures

extension TerminalViewController: UIGestureRecognizerDelegate {

    @objc private func tapGestureRecognizerCallback() {
        guard tapGestureRecognizer.state == .recognized else { return }
        guard !terminalView.isFirstResponder else { return }
        terminalView.becomeFirstResponder()
    }

    @objc func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        !terminalView.isFirstResponder
    }

    @objc func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool { true }
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
