//
//  ClipboardToolbar.swift
//  Cub
//
//  Created by sid on 17/09/25.
//

import Cocoa
import SwiftUI

protocol ClipboardToolbarDelegate: AnyObject {
    func screenshotButtonTapped()
    func galleryButtonTapped()
}

class ClipboardToolbar: NSView {
    weak var delegate: ClipboardToolbarDelegate?

    private var screenshotButton: NSButton!
    private var galleryButton: NSButton!
    private var visualEffectView: NSVisualEffectView!

    // Layout constants following Apple's HIG
    private let buttonSize: CGFloat = 32
    private let buttonSpacing: CGFloat = 12
    private let horizontalPadding: CGFloat = 16
    private let verticalPadding: CGFloat = 8
    private let cornerRadius: CGFloat = 8

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupToolbar()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupToolbar()
    }

    private func setupToolbar() {
        wantsLayer = true
        layer?.cornerRadius = cornerRadius

        // Create modern background with visual effect
        setupModernBackground()
        setupButtons()
        setupConstraints()
        setupAccessibility()

        // Listen for appearance changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appearanceChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )

        print("🔧 [TOOLBAR] Clipboard toolbar created with modern design")
    }

    private func setupModernBackground() {
        // Create visual effect view for modern "Liquid Glass" effect
        visualEffectView = NSVisualEffectView()
        visualEffectView.material = .popover
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.state = .active
        visualEffectView.wantsLayer = true
        visualEffectView.layer?.cornerRadius = cornerRadius

        addSubview(visualEffectView)
        visualEffectView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            visualEffectView.topAnchor.constraint(equalTo: topAnchor),
            visualEffectView.leadingAnchor.constraint(equalTo: leadingAnchor),
            visualEffectView.trailingAnchor.constraint(equalTo: trailingAnchor),
            visualEffectView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        print("✨ [TOOLBAR] Modern visual effect background configured")
    }

    private func setupButtons() {
        // Screenshot button with paperclip SF Symbol
        screenshotButton = createToolbarButton(
            systemImage: "paperclip",
            accessibilityLabel: "Current Screenshot",
            accessibilityHelp: "View or perform actions on the current screenshot",
            action: #selector(screenshotButtonAction)
        )

        // Gallery button with photo grid SF Symbol
        galleryButton = createToolbarButton(
            systemImage: "photo.on.rectangle.angled",
            accessibilityLabel: "Screenshot Gallery",
            accessibilityHelp: "Open gallery to view all captured screenshots",
            action: #selector(galleryButtonAction)
        )

        addSubview(screenshotButton)
        addSubview(galleryButton)

        print("📷 [TOOLBAR] Screenshot and Gallery buttons created")
    }

    private func createToolbarButton(
        systemImage: String,
        accessibilityLabel: String,
        accessibilityHelp: String,
        action: Selector
    ) -> NSButton {
        let button = NSButton()
        button.isBordered = false
        button.bezelStyle = .regularSquare
        button.imagePosition = .imageOnly
        button.target = self
        button.action = action

        // Configure SF Symbol with proper sizing
        if let image = NSImage(systemSymbolName: systemImage, accessibilityDescription: accessibilityLabel) {
            let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .medium)
            let configuredImage = image.withSymbolConfiguration(config)
            button.image = configuredImage
        }

        // Modern button appearance
        button.wantsLayer = true
        button.layer?.cornerRadius = 6
        button.layer?.backgroundColor = NSColor.clear.cgColor

        // Modern button appearance with hover effects
        button.showsBorderOnlyWhileMouseInside = true

        // Accessibility
        button.setAccessibilityLabel(accessibilityLabel)
        button.setAccessibilityHelp(accessibilityHelp)
        button.setAccessibilityRole(.button)

        // Size constraints
        button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: buttonSize),
            button.heightAnchor.constraint(equalToConstant: buttonSize)
        ])

        return button
    }

    private func setupConstraints() {
        screenshotButton.translatesAutoresizingMaskIntoConstraints = false
        galleryButton.translatesAutoresizingMaskIntoConstraints = false

        // Calculate total width needed for proper sizing
        let totalWidth = horizontalPadding * 2 + buttonSize * 2 + buttonSpacing
        let totalHeight = verticalPadding * 2 + buttonSize

        // Set intrinsic content size
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: totalWidth),
            heightAnchor.constraint(equalToConstant: totalHeight)
        ])

        // Position buttons in horizontal layout
        NSLayoutConstraint.activate([
            // Screenshot button (left)
            screenshotButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: horizontalPadding),
            screenshotButton.centerYAnchor.constraint(equalTo: centerYAnchor),

            // Gallery button (right)
            galleryButton.leadingAnchor.constraint(equalTo: screenshotButton.trailingAnchor, constant: buttonSpacing),
            galleryButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            galleryButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -horizontalPadding)
        ])

        print("📐 [TOOLBAR] Constraints configured for buttons layout")
    }

    private func setupAccessibility() {
        // Configure toolbar container accessibility
        setAccessibilityRole(.toolbar)
        setAccessibilityLabel("Clipboard actions toolbar")
        setAccessibilityHelp("Contains buttons for screenshot actions and gallery access")
        setAccessibilityIdentifier("clipboard-toolbar")

        print("♿ [TOOLBAR] Accessibility labels configured")
    }

    // MARK: - Button Actions

    @objc private func screenshotButtonAction() {
        print("📎 [TOOLBAR] Screenshot button tapped")
        delegate?.screenshotButtonTapped()

        // Visual feedback
        animateButtonPress(screenshotButton)
    }

    @objc private func galleryButtonAction() {
        print("🖼️ [TOOLBAR] Gallery button tapped")
        delegate?.galleryButtonTapped()

        // Visual feedback
        animateButtonPress(galleryButton)
    }

    private func animateButtonPress(_ button: NSButton) {
        // Subtle press animation following Apple's guidelines
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.1
            context.allowsImplicitAnimation = true
            button.layer?.transform = CATransform3DMakeScale(0.95, 0.95, 1.0)
        } completionHandler: {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.1
                context.allowsImplicitAnimation = true
                button.layer?.transform = CATransform3DIdentity
            }
        }
    }

    // MARK: - Appearance Updates

    @objc private func appearanceChanged() {
        updateAppearance()
    }

    private func updateAppearance() {
        // Update visual effect material based on system appearance
        if #available(macOS 10.14, *) {
            let isDarkMode = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            visualEffectView.material = isDarkMode ? .hudWindow : .popover

            // Update button appearance for better contrast
            let buttonColor = isDarkMode ? NSColor.controlAccentColor.withAlphaComponent(0.1) : NSColor.controlBackgroundColor.withAlphaComponent(0.1)

            screenshotButton.layer?.backgroundColor = buttonColor.cgColor
            galleryButton.layer?.backgroundColor = buttonColor.cgColor

            print("🎨 [TOOLBAR] Appearance updated for \(isDarkMode ? "dark" : "light") mode")
        }
    }

    // MARK: - Public Methods

    func setScreenshotButtonEnabled(_ enabled: Bool) {
        screenshotButton.isEnabled = enabled
        screenshotButton.alphaValue = enabled ? 1.0 : 0.5
    }

    func setGalleryButtonEnabled(_ enabled: Bool) {
        galleryButton.isEnabled = enabled
        galleryButton.alphaValue = enabled ? 1.0 : 0.5
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        updateAppearance()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
