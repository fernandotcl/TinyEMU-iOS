//
//  TerminalInputAccessoryView.swift
//  TinyEMU-iOS
//
//  Created by Fernando Lemos on 4/1/19.
//
//  Refer to the LICENSE file for licensing information.
//

import UIKit


class TerminalInputAccessoryView: UIView {

    weak var delegate: TerminalInputAccessoryViewDelegate?

    enum Key {
        case escape
        case control
        case alternate
        case tab
        case home
        case end
        case arrowLeft
        case arrowUp
        case arrowDown
        case arrowRight
    }

    private struct KeyDescriptor {
        let key: Key
        let buttonTitle: String
        let priority: Int
    }

    private(set) var enabledModifiers: UIKeyModifierFlags = []

    private var keyDescriptors: [KeyDescriptor] = [
        KeyDescriptor(key: .escape,     buttonTitle: "esc", priority: 0),
        KeyDescriptor(key: .control,    buttonTitle: "^",   priority: 0),
        KeyDescriptor(key: .alternate,  buttonTitle: "⎇",   priority: 2),
        KeyDescriptor(key: .tab,        buttonTitle: "⇥",   priority: 1),
        KeyDescriptor(key: .home,       buttonTitle: "↖︎",   priority: 3),
        KeyDescriptor(key: .end,        buttonTitle: "↘︎",   priority: 3),
        KeyDescriptor(key: .arrowLeft,  buttonTitle: "←",   priority: 0),
        KeyDescriptor(key: .arrowUp,    buttonTitle: "↑",   priority: 0),
        KeyDescriptor(key: .arrowDown,  buttonTitle: "↓",   priority: 0),
        KeyDescriptor(key: .arrowRight, buttonTitle: "→",   priority: 0),
    ]

    private var buttons: [KeyButton]

    override init(frame: CGRect) {
        buttons = keyDescriptors.map {
            let button = KeyButton(type: .custom)
            button.setTitle($0.buttonTitle, for: [])
            button.setTitleColor(.systemGray, for: [])
            button.normalBackgroundColor = .systemGray5
            button.highlightedBackgroundColor = .systemGray4
            return button
        }

        var superFrame = frame
        superFrame.size.height = 44
        super.init(frame: superFrame)

        backgroundColor = .systemGray5

        for button in buttons {
            button.addTarget(self,
                             action: #selector(didTapButton(button:)),
                             for: .touchUpInside)
            addSubview(button)
        }
    }

    required init?(coder aDecoder: NSCoder) { fatalError() }

    override func safeAreaInsetsDidChange() {

        // UIKit installs a constraint setting a constant height matching the initial
        // height for the input accessory view at the time the view is made the input
        // accessory view. So we need to update that once we get new safe area insets.
        // Clearly nobody thought this through...
        for constraint in constraints {
            if constraint.firstAttribute == .height {
                constraint.constant = 44 + safeAreaInsets.bottom
                break
            }
        }

        super.safeAreaInsetsDidChange()
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        var visibleButtons = buttons

        // Truncate the list of visible buttons as needed
        let availableWidth = bounds.size.width - safeAreaInsets.left - safeAreaInsets.right
        let minButtonWidth: CGFloat = 44
        var buttonWidth: CGFloat = 0
        var cutoffPriority = 4
        while buttonWidth < minButtonWidth && cutoffPriority > 0 {
            cutoffPriority -= 1
            visibleButtons = keyDescriptors
                .enumerated()
                .filter { $0.element.priority <= cutoffPriority }
                .map { buttons[$0.offset] }
            buttonWidth = availableWidth / CGFloat(visibleButtons.count)
        }

        // Lay out the buttons
        var remainder: CGFloat = 0
        var frame = CGRect(x: safeAreaInsets.left,
                           y: 0,
                           width: 0,
                           height: bounds.height - safeAreaInsets.bottom)
        for button in visibleButtons {
            let width = buttonWidth + remainder
            let actualWidth = floor(width)
            remainder = width - actualWidth
            frame.origin.x = frame.maxX
            frame.size.width = actualWidth
            button.frame = frame
        }

        // Adjust their visibility
        for button in buttons {
            button.alpha = visibleButtons.contains(button) ? 1 : 0
        }
    }

    @objc private func didTapButton(button: KeyButton) {
        guard let index = buttons.firstIndex(of: button) else { return }
        let key = keyDescriptors[index].key

        switch key {
        case .control:
            if enabledModifiers.contains(.control) {
                enabledModifiers.remove(.control)
                button.isStickyHighlighted = false
            } else {
                enabledModifiers.insert(.control)
                button.isStickyHighlighted = true
            }
        case .alternate:
            if enabledModifiers.contains(.alternate) {
                enabledModifiers.remove(.alternate)
                button.isStickyHighlighted = false
            } else {
                enabledModifiers.insert(.alternate)
                button.isStickyHighlighted = true
            }
        default:
            break
        }

        delegate?.terminalInputAccessoryView(self, didTapKey: key)
    }

    func clearModifiers() {
        enabledModifiers = []
        for button in buttons {
            button.isStickyHighlighted = false
        }
    }
}

// MARK: - Button view

private class KeyButton: UIButton {

    var normalBackgroundColor: UIColor? {
        didSet { adjustColors() }
    }
    var highlightedBackgroundColor: UIColor? {
        didSet { adjustColors() }
    }

    override var isHighlighted: Bool {
        didSet { adjustColors() }
    }
    var isStickyHighlighted = false {
        didSet { adjustColors() }
    }

    private func adjustColors() {
        backgroundColor = isHighlighted || isStickyHighlighted ?
            highlightedBackgroundColor : normalBackgroundColor
    }
}

// MARK: - Delegate protocol

protocol TerminalInputAccessoryViewDelegate: AnyObject {

    func terminalInputAccessoryView(
        _ view: TerminalInputAccessoryView,
        didTapKey key: TerminalInputAccessoryView.Key)
}
