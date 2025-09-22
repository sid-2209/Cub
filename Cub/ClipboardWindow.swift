//
//  ClipboardWindow.swift
//  Cub
//
//  Created by sid on 15/09/25.
//

import Cocoa
import SwiftUI

protocol ClipboardWindowDelegate: AnyObject {
    func clipboardWindowVisibilityChanged(_ isVisible: Bool)
}

class ClipboardWindow: NSWindow {
    weak var clipboardDelegate: ClipboardWindowDelegate?

    private var clipboardView: ClipboardWindowView!
    private var windowState: ClipboardWindowState = .hidden

    // Window dimensions
    private let windowWidth: CGFloat = 280 // Reduced from 350 to prevent overflow
    private let windowHeight: CGFloat = 450 // Slightly reduced to fit better
    private let edgeMargin: CGFloat = 15 // Reduced margin
    private let topMargin: CGFloat = 80 // Reduced top margin

    // Current displayed image
    private var currentImage: CapturedImage?

    // Auto-dimming and activity tracking
    private var activityTracker: ActivityTracker!
    private var wasAutoHidden: Bool = false
    private var isDimmingEnabled: Bool = true
    private var isAutoHideEnabled: Bool = true
    private var visibilityMode: ClipboardVisibilityMode = .show

    init() {
        // Calculate initial position
        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect.zero
        let windowFrame = NSRect(
            x: screenFrame.maxX - windowWidth - edgeMargin,
            y: screenFrame.minY + topMargin, // Position from bottom, not top
            width: windowWidth,
            height: windowHeight
        )

        super.init(
            contentRect: windowFrame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        setupWindow()
        setupClipboardView()
        setupActivityTracker()
        setupNotifications()
        loadWindowState()
    }

    private func setupWindow() {
        // Modern macOS window appearance with NSVisualEffectView
        backgroundColor = NSColor.clear
        isOpaque = false
        hasShadow = true
        level = NSWindow.Level.floating
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]

        // Enable modern window appearance
        titlebarAppearsTransparent = true
        titleVisibility = .hidden
        styleMask.insert(.fullSizeContentView)

        // Window behavior
        hidesOnDeactivate = false
        ignoresMouseEvents = false
        acceptsMouseMovedEvents = false

        // Remove from window list and dock
        isExcludedFromWindowsMenu = true

        // Accessibility configuration for window
        if #available(macOS 10.13, *) {
            setAccessibilityLabel("Cub Screenshot Clipboard")
            setAccessibilityHelp("Shows captured screenshots. Drag images to copy them to other applications.")
            setAccessibilityIdentifier("clipboard-window")
        }

        // Set strict size constraints on the window itself
        minSize = NSSize(width: 200, height: 300)
        maxSize = NSSize(width: windowWidth, height: windowHeight)

        // Setup modern material background
        setupModernBackground()

        // Position window properly
        positionWindowAtEdge()

        print("📋 Window setup completed with level: \(level.rawValue)")
        print("📋 Window size constraints: min=\(minSize), max=\(maxSize)")
    }

    private func setupModernBackground() {
        // Create NSVisualEffectView for modern macOS appearance
        let visualEffectView = NSVisualEffectView()

        // Configure material and appearance based on system theme
        if #available(macOS 10.14, *) {
            let isDarkMode = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            visualEffectView.material = isDarkMode ? .hudWindow : .popover
            visualEffectView.state = .active

            // Enable automatic appearance updates
            visualEffectView.appearance = nil // Use system appearance
        } else {
            visualEffectView.material = .dark
            visualEffectView.state = .active
        }

        // Configure blending and masking
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.wantsLayer = true
        visualEffectView.layer?.cornerRadius = 12.0
        visualEffectView.layer?.masksToBounds = true

        // Set frame to fill window
        visualEffectView.frame = contentView?.bounds ?? frame
        visualEffectView.autoresizingMask = [.width, .height]

        // Insert as the background view
        if let contentView = contentView {
            contentView.addSubview(visualEffectView, positioned: .below, relativeTo: nil)
        }

        if #available(macOS 10.14, *) {
            let materialName = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? "hudWindow" : "popover"
            print("✅ [MODERN] NSVisualEffectView configured with material: \(materialName)")
        } else {
            print("✅ [MODERN] NSVisualEffectView configured with dark material")
        }
    }

    private func setupClipboardView() {
        clipboardView = ClipboardWindowView()

        guard let contentView = contentView else { return }

        contentView.addSubview(clipboardView)

        // Use constraints instead of autoresizing mask for better control
        NSLayoutConstraint.activate([
            clipboardView.topAnchor.constraint(equalTo: contentView.topAnchor),
            clipboardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            clipboardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            clipboardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            clipboardView.widthAnchor.constraint(lessThanOrEqualToConstant: windowWidth),
            clipboardView.heightAnchor.constraint(lessThanOrEqualToConstant: windowHeight)
        ])

        print("📋 ClipboardView setup with constraints")
    }

    private func setupActivityTracker() {
        activityTracker = ActivityTracker()
        activityTracker.delegate = self

        // Load visibility mode
        loadVisibilityMode()

        // Load user preferences
        isDimmingEnabled = UserDefaults.standard.bool(forKey: "AutoDimmingEnabled")
        isAutoHideEnabled = UserDefaults.standard.bool(forKey: "AutoHideEnabled")

        // Set defaults if first launch
        if UserDefaults.standard.object(forKey: "AutoDimmingEnabled") == nil {
            isDimmingEnabled = true
            isAutoHideEnabled = true
            UserDefaults.standard.set(true, forKey: "AutoDimmingEnabled")
            UserDefaults.standard.set(true, forKey: "AutoHideEnabled")
        }

        print("📋 [ACTIVITY] Activity tracker setup completed")
        print("📋 [ACTIVITY] Visibility mode: \(visibilityMode.displayName)")
        print("📋 [ACTIVITY] Auto-dimming enabled: \(isDimmingEnabled)")
        print("📋 [ACTIVITY] Auto-hide enabled: \(isAutoHideEnabled)")
    }

    private func setupNotifications() {
        // Listen for window position preference changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleWindowPositionChange),
            name: NSNotification.Name("WindowPositionChanged"),
            object: nil
        )

        // Listen for app-controlled appearance changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppearanceChange),
            name: .appearanceDidChange,
            object: nil
        )

        print("📋 ClipboardWindow notifications set up")
    }

    private func loadVisibilityMode() {
        // Load visibility mode with migration support
        if let modeString = UserDefaults.standard.string(forKey: "ClipboardVisibilityMode"),
           let mode = ClipboardVisibilityMode(rawValue: modeString) {
            visibilityMode = mode
        } else {
            // Migration from old boolean preference
            let legacyAlwaysShow = UserDefaults.standard.bool(forKey: "AlwaysShowClipboard")
            visibilityMode = ClipboardVisibilityMode.fromLegacyPreference(alwaysShow: legacyAlwaysShow)
            UserDefaults.standard.set(visibilityMode.rawValue, forKey: "ClipboardVisibilityMode")
        }
    }

    private func positionWindowAtEdge() {
        print("📍 [POSITION] Starting window positioning...")

        var screen = NSScreen.main
        print("📍 [POSITION] Main screen: \(screen != nil ? "✅ Available" : "❌ Nil")")

        // Fallback to first available screen if main is unavailable
        if screen == nil {
            screen = NSScreen.screens.first
            print("⚠️ [POSITION] Main screen unavailable, using first available screen")
        }

        guard let validScreen = screen else {
            print("❌ [POSITION] No screens available for positioning")
            return
        }

        let visibleFrame = validScreen.visibleFrame
        print("📍 [POSITION] Screen visible frame: \(visibleFrame)")

        // Get user's preferred window position
        let windowPosition = SettingsStore.shared.windowPositionEnum
        print("📍 [POSITION] User preference: \(windowPosition.displayName)")

        // Ensure window fits within screen bounds with stricter constraints
        let maxWidth = visibleFrame.width * 0.25 // Maximum 25% of screen width
        let maxHeight = visibleFrame.height - topMargin * 2

        let adjustedWidth = min(windowWidth, min(maxWidth, visibleFrame.width - edgeMargin * 2))
        let adjustedHeight = min(windowHeight, maxHeight)

        print("📍 [POSITION] Adjusted dimensions: \(adjustedWidth) x \(adjustedHeight)")

        // Calculate X position based on user preference
        let xPosition: CGFloat
        switch windowPosition {
        case .left:
            xPosition = visibleFrame.minX + edgeMargin
            print("📍 [POSITION] Positioning at left edge")
        case .right:
            xPosition = visibleFrame.maxX - adjustedWidth - edgeMargin
            print("📍 [POSITION] Positioning at right edge")
        }

        let newFrame = NSRect(
            x: xPosition,
            y: visibleFrame.minY + topMargin, // Position from bottom
            width: adjustedWidth,
            height: adjustedHeight
        )

        print("📍 [POSITION] Calculated new frame: \(newFrame)")
        print("📍 [POSITION] Screen visible frame: \(visibleFrame)")
        print("📍 [POSITION] Window size adjusted: \(adjustedWidth)×\(adjustedHeight)")
        print("📍 [POSITION] Original window size: \(windowWidth)×\(windowHeight)")
        print("📍 [POSITION] Max width allowed: \(maxWidth)")

        setFrame(newFrame, display: true, animate: false)

        // Force constrain the window after setting frame
        let actualFrame = frame
        print("📍 [POSITION] Actual window frame after setFrame: \(actualFrame)")

        // If the window is still too wide, force it smaller
        if actualFrame.width > adjustedWidth + 10 { // 10px tolerance
            let correctedFrame = NSRect(
                x: actualFrame.origin.x,
                y: actualFrame.origin.y,
                width: adjustedWidth,
                height: adjustedHeight
            )
            print("🔧 Correcting oversized window from \(actualFrame.width) to \(adjustedWidth)")
            setFrame(correctedFrame, display: true, animate: false)
        }
    }

    // MARK: - Auto-Dimming Animation Methods

    private func dimWindow() {
        guard isDimmingEnabled && visibilityMode.allowsAutoDimming else { return }
        guard windowState == .visible || windowState == .alwaysVisible else { return }

        print("🌙 [DIMMING] Dimming window to 50% opacity")
        let previousState = windowState
        windowState = .dimmed

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.4
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            animator().alphaValue = 0.5
        }

        saveWindowState()
        print("✅ [DIMMING] Window dimmed successfully (was \(previousState.rawValue))")
    }

    private func undimWindow() {
        guard windowState == .dimmed else { return }

        print("☀️ [DIMMING] Undimming window to full opacity")

        // Restore to the appropriate visible state based on visibility mode
        windowState = visibilityMode == .alwaysShow ? .alwaysVisible : .visible

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            animator().alphaValue = 1.0
        }

        saveWindowState()
        print("✅ [DIMMING] Window undimmed successfully (restored to \(windowState.rawValue))")
    }

    private func autoHideWindow() {
        guard isAutoHideEnabled && visibilityMode.allowsAutoHiding else { return }
        guard windowState == .visible || windowState == .dimmed else { return }

        print("🙈 [AUTO-HIDE] Auto-hiding window (mode: \(visibilityMode.displayName))")
        wasAutoHidden = true
        windowState = .hidden

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.5
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            animator().alphaValue = 0.0
        }) {
            self.orderOut(nil)
        }

        saveWindowState()
        clipboardDelegate?.clipboardWindowVisibilityChanged(false)
        print("✅ [AUTO-HIDE] Window auto-hidden successfully")
    }

    private func revealFromAutoHide() {
        guard wasAutoHidden else { return }

        print("👁️ [AUTO-HIDE] Revealing window from auto-hide")
        wasAutoHidden = false
        windowState = .visible

        positionWindowAtEdge()
        orderFront(nil)
        alphaValue = 0.0

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.4
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            animator().alphaValue = 1.0
        }

        saveWindowState()
        clipboardDelegate?.clipboardWindowVisibilityChanged(true)
        print("✅ [AUTO-HIDE] Window revealed with animation")
    }

    // MARK: - Public Methods

    func showClipboard() {
        print("📋 [WINDOW] showClipboard() called - current state: \(windowState)")

        // Handle auto-hidden window revival
        if wasAutoHidden {
            revealFromAutoHide()
            startActivityTracking()
            return
        }

        // Don't show if already visible, but allow alwaysVisible to show again
        guard windowState == .hidden else {
            print("📋 [WINDOW] Window already visible or alwaysVisible, skipping show")
            return
        }

        windowState = .visible
        print("📋 [WINDOW] Setting state to visible, positioning window...")

        positionWindowAtEdge()
        orderFront(nil)
        alphaValue = 0.0

        print("📋 [WINDOW] Starting fade-in animation...")
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            animator().alphaValue = 1.0
        }

        saveWindowState()
        clipboardDelegate?.clipboardWindowVisibilityChanged(true)
        startActivityTracking()
        print("📋 [WINDOW] Clipboard window shown with animation")
    }

    func hideClipboard() {
        guard windowState != .hidden else { return }

        windowState = .hidden
        wasAutoHidden = false
        stopActivityTracking()

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            animator().alphaValue = 0.0
        }) {
            self.orderOut(nil)
        }

        saveWindowState()
        clipboardDelegate?.clipboardWindowVisibilityChanged(false)
        print("📋 Clipboard window hidden")
    }

    func setAlwaysVisible(_ alwaysVisible: Bool) {
        print("📋 [WINDOW] setAlwaysVisible(\(alwaysVisible)) called - current state: \(windowState)")

        if alwaysVisible {
            print("📋 [WINDOW] Setting window to always visible mode")

            // First, ensure the window is positioned and visible
            positionWindowAtEdge()
            print("📋 [WINDOW] Window positioned at right edge")

            // Set state to alwaysVisible
            windowState = .alwaysVisible
            print("📋 [WINDOW] State set to alwaysVisible")

            // Make window visible with proper ordering and activation
            orderFront(nil)
            alphaValue = 1.0

            print("📋 [WINDOW] Window made visible with orderFront")
            print("📋 [WINDOW] Window frame: \(frame)")
            print("📋 [WINDOW] Window isVisible: \(isVisible)")
            print("📋 [WINDOW] Window alphaValue: \(alphaValue)")
        } else {
            print("📋 [WINDOW] Setting window to regular visible mode")
            windowState = .visible
        }

        saveWindowState()
        clipboardDelegate?.clipboardWindowVisibilityChanged(windowState != .hidden)
        print("📋 [WINDOW] setAlwaysVisible completed - final state: \(windowState)")
    }

    func showSelectionDetected() {
        print("📋 [CLIPBOARD] showSelectionDetected called - Command+E pressed")

        // Show window if it's hidden
        if windowState == .hidden {
            print("📋 [CLIPBOARD] Window is hidden, calling showClipboard()")
            showClipboard()
        }

        // Update the placeholder text to show selection detected
        clipboardView.showSelectionDetected()
        print("📋 [CLIPBOARD] Selection detected state displayed")
    }

    func restoreOriginalState() {
        print("📋 [CLIPBOARD] restoreOriginalState called - restoring to default placeholder")
        clipboardView.clearImage()
        print("📋 [CLIPBOARD] Original state restored")
    }


    // MARK: - State Management

    private func saveWindowState() {
        UserDefaults.standard.set(windowState.rawValue, forKey: "ClipboardWindowState")
        print("📋 Saved window state: \(windowState.rawValue)")
    }

    private func loadWindowState() {
        let savedState = UserDefaults.standard.string(forKey: "ClipboardWindowState") ?? "hidden"
        print("📋 Loading window state: \(savedState)")

        switch savedState {
        case "visible":
            windowState = .visible
            print("📋 Setting initial state to visible, showing clipboard")
            showClipboard()
        case "dimmed":
            windowState = .visible
            print("📋 Setting initial state to visible (was dimmed), showing clipboard")
            showClipboard()
        case "alwaysVisible":
            windowState = .alwaysVisible
            print("📋 Setting initial state to alwaysVisible, showing clipboard")
            showClipboard()
        default:
            windowState = .hidden
            print("📋 Setting initial state to hidden")
        }
    }

    // MARK: - Window Events

    override func mouseDown(with event: NSEvent) {
        // Reset activity tracking
        activityTracker.resetActivity()
        // Allow window to be dragged
        performDrag(with: event)
    }

    // MARK: - Screen Changes

    func handleScreenChange() {
        positionWindowAtEdge()
    }

    // MARK: - Helper Properties

    var isClipboardVisible: Bool {
        return windowState != .hidden && isVisible
    }

    var hasImage: Bool {
        return currentImage != nil
    }

    var isAutoHidden: Bool {
        return wasAutoHidden
    }

    var currentWindowState: ClipboardWindowState {
        return windowState
    }

    // MARK: - Window Access for Screenshot Exclusion

    func getNSWindow() -> NSWindow {
        return self
    }

    // MARK: - Screenshot Update

    func updateWithCapturedImage(_ capturedImage: CapturedImage) {
        print("📸 [UPDATE] Updating clipboard window with captured image")
        print("📁 [UPDATE] File: \(capturedImage.fileName)")
        print("📦 [UPDATE] Size: \(capturedImage.displayDimensions)")

        // Store the captured image for drag operations
        currentImage = capturedImage

        // Update the clipboardView with thumbnail
        if let clipboardView = clipboardView {
            clipboardView.updateWithCapturedImage(capturedImage)
        }

        // Show the clipboard window
        showClipboard()

        print("✅ [UPDATE] Clipboard window updated successfully")
    }

    // MARK: - Toolbar Actions

    func handleScreenshotButtonAction() {
        print("📎 [WINDOW] Handling screenshot button action")

        guard let currentImage = currentImage else {
            print("ℹ️ [WINDOW] No current screenshot available")
            // Show visual feedback that no screenshot is available
            showNoScreenshotFeedback()
            return
        }

        print("📸 [WINDOW] Current screenshot available: \(currentImage.fileName)")

        // Show action menu for current screenshot
        showScreenshotActionMenu(for: currentImage)
    }

    private func showNoScreenshotFeedback() {
        // Subtle animation to indicate no screenshot available
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.allowsImplicitAnimation = true
            alphaValue = 0.7
        } completionHandler: {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2
                context.allowsImplicitAnimation = true
                self.alphaValue = 1.0
            }
        }

        print("💡 [WINDOW] Showing visual feedback for no screenshot")
    }

    private func showScreenshotActionMenu(for image: CapturedImage) {
        let menu = NSMenu()
        menu.autoenablesItems = false

        // Copy to Clipboard action
        let copyItem = NSMenuItem(title: "Copy to Clipboard", action: #selector(copyCurrentScreenshot), keyEquivalent: "c")
        copyItem.target = self
        copyItem.isEnabled = true
        menu.addItem(copyItem)

        // Open in Default App action
        let openItem = NSMenuItem(title: "Open in Default App", action: #selector(openCurrentScreenshot), keyEquivalent: "o")
        openItem.target = self
        openItem.isEnabled = true
        menu.addItem(openItem)

        menu.addItem(NSMenuItem.separator())

        // Reveal in Finder action
        let revealItem = NSMenuItem(title: "Reveal in Finder", action: #selector(revealCurrentScreenshot), keyEquivalent: "r")
        revealItem.target = self
        revealItem.isEnabled = true
        menu.addItem(revealItem)

        // Show menu near the screenshot button
        if let clipboardView = contentView as? ClipboardWindowView,
           let toolbar = clipboardView.value(forKey: "toolbar") as? ClipboardToolbar {
            let buttonRect = toolbar.convert(toolbar.bounds, to: nil)
            let screenPoint = convertToScreen(buttonRect)
            menu.popUp(positioning: nil, at: NSPoint(x: screenPoint.minX, y: screenPoint.minY), in: nil)
        }

        print("📋 [WINDOW] Screenshot action menu displayed")
    }

    @objc private func copyCurrentScreenshot() {
        guard let currentImage = currentImage else { return }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([currentImage.image])

        print("📋 [WINDOW] Screenshot copied to clipboard")
    }

    @objc private func openCurrentScreenshot() {
        guard let currentImage = currentImage else { return }

        NSWorkspace.shared.open(currentImage.filePath)
        print("🚀 [WINDOW] Screenshot opened in default app")
    }

    @objc private func revealCurrentScreenshot() {
        guard let currentImage = currentImage else { return }

        NSWorkspace.shared.activateFileViewerSelecting([currentImage.filePath])
        print("🔍 [WINDOW] Screenshot revealed in Finder")
    }

    func handleChatButtonAction() {
        print("💬 [WINDOW] Handling chat button action")

        // TODO: Implement chat functionality
        // For now, show a placeholder action
        showChatPlaceholder()

        print("✅ [WINDOW] Chat action completed")
    }

    private func showChatPlaceholder() {
        // Subtle animation to indicate chat feature is not yet implemented
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            context.allowsImplicitAnimation = true
            alphaValue = 0.8
        } completionHandler: {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.15
                context.allowsImplicitAnimation = true
                self.alphaValue = 1.0
            }
        }

        print("💡 [WINDOW] Chat placeholder feedback shown")
    }

    private func forceShowWindow() {
        print("📋 [WINDOW] forceShowWindow() called - forcing window to appear")

        positionWindowAtEdge()
        orderFront(nil)
        alphaValue = 0.0

        print("📋 [WINDOW] Starting fade-in animation...")
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            animator().alphaValue = 1.0
        }

        saveWindowState()
        clipboardDelegate?.clipboardWindowVisibilityChanged(true)
        print("✅ [WINDOW] Window forced to show with animation")
    }

    // MARK: - Activity Tracking Methods

    private func startActivityTracking() {
        // Only start tracking if the mode supports it and window is not hidden
        guard visibilityMode != .hidden && windowState != .hidden else { return }
        guard (isDimmingEnabled && visibilityMode.allowsAutoDimming) ||
              (isAutoHideEnabled && visibilityMode.allowsAutoHiding) else { return }

        activityTracker.startTracking()
        print("🔍 [ACTIVITY] Started activity tracking for window (mode: \(visibilityMode.displayName))")
    }

    private func stopActivityTracking() {
        activityTracker.stopTracking()
        print("🔍 [ACTIVITY] Stopped activity tracking for window")
    }

    func setAutoDimmingEnabled(_ enabled: Bool) {
        isDimmingEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "AutoDimmingEnabled")

        if !enabled && windowState == .dimmed {
            undimWindow()
        }

        print("📋 [SETTINGS] Auto-dimming enabled: \(enabled)")
    }

    func setAutoHideEnabled(_ enabled: Bool) {
        isAutoHideEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "AutoHideEnabled")

        print("📋 [SETTINGS] Auto-hide enabled: \(enabled)")
    }

    func setVisibilityMode(_ mode: ClipboardVisibilityMode) {
        print("📋 [SETTINGS] Setting visibility mode to: \(mode.displayName)")

        let previousMode = visibilityMode
        visibilityMode = mode

        UserDefaults.standard.set(mode.rawValue, forKey: "ClipboardVisibilityMode")

        // Handle state transitions based on the new mode
        switch mode {
        case .hidden:
            hideClipboard()
            stopActivityTracking()

        case .show:
            // Normal mode - allow both dimming and auto-hiding
            if previousMode == .hidden {
                // Show the window when switching from hidden to show
                windowState = .visible
                forceShowWindow()
                print("📋 [SETTINGS] Switched to show mode - displaying window")
            } else if previousMode == .alwaysShow {
                // Transition from always visible to normal - keep window visible but update state
                windowState = .visible
                if !isVisible {
                    forceShowWindow()
                }
                startActivityTracking()
                print("📋 [SETTINGS] Switched from Always Show to Show mode")
            } else {
                // For any other transition to show mode, ensure window is visible
                windowState = .visible
                if !isVisible {
                    forceShowWindow()
                }
                startActivityTracking()
                print("📋 [SETTINGS] Switched to Show mode - ensuring window is visible")
            }

        case .alwaysShow:
            // Always visible mode - allow dimming but no auto-hiding
            windowState = .alwaysVisible
            orderFront(nil)
            alphaValue = 1.0
            startActivityTracking()
        }

        print("📋 [SETTINGS] Visibility mode updated from \(previousMode.displayName) to \(mode.displayName)")
    }

    func handleGalleryButtonAction() {
        print("🖼️ [WINDOW] Handling gallery button action")

        // Show the gallery window
        GalleryWindowController.show()

        print("✅ [WINDOW] Gallery window requested to show")
    }

    // MARK: - Window Behavior Overrides

    override var canBecomeKey: Bool {
        return false
    }

    override var canBecomeMain: Bool {
        return false
    }

    // MARK: - Window Event Overrides for Activity Tracking

    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        activityTracker.resetActivity()
    }

    override func keyDown(with event: NSEvent) {
        super.keyDown(with: event)
        activityTracker.resetActivity()
    }

    // MARK: - Notification Handlers

    @objc private func handleAppearanceChange() {
        print("🎨 [APPEARANCE] App appearance setting changed")
        // Trigger visual refresh for new appearance
        DispatchQueue.main.async {
            self.contentView?.needsDisplay = true
            // Notify the clipboard view to update its appearance
            if let clipboardView = self.clipboardView {
                clipboardView.needsDisplay = true
            }
        }
    }

    @objc private func handleWindowPositionChange() {
        print("📍 [POSITION] Window position preference changed, repositioning...")
        // Trigger window repositioning if window is visible
        if windowState != .hidden {
            DispatchQueue.main.async {
                self.positionWindowAtEdge()
            }
        }
    }
}

// MARK: - ActivityTrackerDelegate

extension ClipboardWindow: ActivityTrackerDelegate {
    func userActivityDetected() {
        print("🔄 [ACTIVITY] User activity detected")

        // Undim window if currently dimmed
        if windowState == .dimmed {
            undimWindow()
        }
    }

    func inactivityPeriodReached(_ duration: TimeInterval) {
        print("⏰ [ACTIVITY] Inactivity period reached: \(duration) seconds (mode: \(visibilityMode.displayName))")

        switch duration {
        case 60.0: // 1 minute - dim window
            if (windowState == .visible || windowState == .alwaysVisible) &&
               isDimmingEnabled && visibilityMode.allowsAutoDimming {
                dimWindow()
            }
        case 180.0: // 3 minutes - auto-hide window
            if (windowState == .visible || windowState == .dimmed) &&
               isAutoHideEnabled && visibilityMode.allowsAutoHiding {
                autoHideWindow()
            }
        default:
            break
        }
    }
}

// MARK: - ClipboardWindowView

class ClipboardWindowView: NSView {
    private var imageView: DraggableImageView!
    private var metadataLabel: NSTextField!
    private var placeholderLabel: NSTextField!
    private var toolbar: ClipboardToolbar!

    // Color preferences
    private let availableColors: [NSColor] = [
        NSColor.systemRed,
        NSColor.systemBlue,
        NSColor.systemGreen,
        NSColor.systemOrange,
        NSColor.systemPurple
    ]

    private var currentBorderColor: NSColor {
        let colorIndex = UserDefaults.standard.integer(forKey: "SelectedBorderColor")
        return availableColors[min(colorIndex, availableColors.count - 1)]
    }

    // Layout constants
    private let outerBorderWidth: CGFloat = 1.0
    private let innerBorderWidth: CGFloat = 2.0
    private let borderSpacing: CGFloat = 8.0
    private let contentPadding: CGFloat = 16.0
    private let toolbarHeight: CGFloat = 48.0
    private let toolbarSpacing: CGFloat = 8.0

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    private func setupView() {
        // Modern transparent background for NSVisualEffectView integration
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        layer?.cornerRadius = 12.0

        // Add size constraints to prevent expansion
        translatesAutoresizingMaskIntoConstraints = false

        setupImageView()
        setupMetadataLabel()
        setupPlaceholderLabel()
        setupToolbar()
        setupModernVibrancy()
        setupAccessibility()

        // Listen for color preference changes and appearance changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(colorPreferenceChanged),
            name: NSNotification.Name("BorderColorChanged"),
            object: nil
        )

        // Listen for system appearance changes (light/dark mode)
        if #available(macOS 10.14, *) {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(appearanceChanged),
                name: NSApplication.didChangeScreenParametersNotification,
                object: nil
            )

            // Also listen for effective appearance changes
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(effectiveAppearanceChanged),
                name: NSNotification.Name("NSEffectiveAppearanceDidChangeNotification"),
                object: nil
            )
        }

    }

    private func setupModernVibrancy() {
        // Apply vibrancy effects for better text legibility over blurred background
        if #available(macOS 10.14, *) {
            // Use system-defined vibrant colors that automatically adjust contrast
            placeholderLabel.textColor = NSColor.labelColor
            metadataLabel.textColor = NSColor.secondaryLabelColor

            // Remove any custom background layers to allow proper vibrancy
            placeholderLabel.wantsLayer = false
            placeholderLabel.layer?.backgroundColor = nil
        }

        print("✅ [MODERN] Vibrancy effects configured per Apple HIG - no artificial backgrounds")
    }

    private func setupAccessibility() {
        // Configure accessibility for the main view container
        if #available(macOS 10.13, *) {
            setAccessibilityRole(.group)
            setAccessibilityLabel("Screenshot clipboard container")
            setAccessibilityHelp("Contains screenshot thumbnails that can be dragged to other applications")
            setAccessibilityIdentifier("clipboard-container")

            // Make the view focusable for keyboard navigation
            setAccessibilityFocused(false)
        }

        print("♿ [A11Y] Accessibility configuration completed")
    }

    @objc private func appearanceChanged() {
        // Respond to system appearance changes (light/dark mode)
        DispatchQueue.main.async {
            self.updateForCurrentAppearance()
        }
        print("🎨 [MODERN] Appearance updated for system theme change")
    }

    @objc private func effectiveAppearanceChanged() {
        // Respond to effective appearance changes
        DispatchQueue.main.async {
            self.updateForCurrentAppearance()
        }
        print("🎨 [MODERN] Effective appearance changed")
    }


    private func updateForCurrentAppearance() {
        // Update visual elements for current system appearance
        needsDisplay = true
        setupModernVibrancy()

        // Update window's visual effect view material based on appearance
        if #available(macOS 10.14, *) {
            if let window = window {
                updateWindowMaterialForAppearance(window)
            }
        }
    }

    private func updateWindowMaterialForAppearance(_ window: NSWindow) {
        // Find and update the visual effect view
        if let contentView = window.contentView {
            for subview in contentView.subviews {
                if let visualEffectView = subview as? NSVisualEffectView {
                    if #available(macOS 10.14, *) {
                        // Automatically adapt material based on system appearance
                        let isDarkMode = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                        visualEffectView.material = isDarkMode ? .hudWindow : .popover
                        print("🎨 [MODERN] Updated material for \(isDarkMode ? "dark" : "light") mode")
                    }
                    break
                }
            }
        }
    }

    private func setupImageView() {
        imageView = DraggableImageView()
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.imageAlignment = .alignCenter
        imageView.isHidden = true

        // Accessibility configuration
        imageView.setAccessibilityRole(.image)
        imageView.setAccessibilityLabel("Screenshot thumbnail")
        imageView.setAccessibilityHelp("Drag this image to copy it to another application")
        imageView.setAccessibilityIdentifier("screenshot-thumbnail")

        addSubview(imageView)
        imageView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: topAnchor, constant: outerBorderWidth + borderSpacing + innerBorderWidth + contentPadding),
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: outerBorderWidth + borderSpacing + innerBorderWidth + contentPadding),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -(outerBorderWidth + borderSpacing + innerBorderWidth + contentPadding)),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -(outerBorderWidth + borderSpacing + innerBorderWidth + contentPadding + 40 + toolbarHeight + toolbarSpacing)) // Space for metadata and toolbar
        ])

        print("📎 [SETUP] DraggableImageView created and configured for drag operations with accessibility")
    }

    private func setupMetadataLabel() {
        metadataLabel = NSTextField()
        metadataLabel.isEditable = false
        metadataLabel.isBordered = false
        metadataLabel.backgroundColor = NSColor.clear
        metadataLabel.textColor = NSColor.secondaryLabelColor
        metadataLabel.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        metadataLabel.alignment = .center
        metadataLabel.isHidden = true

        // Accessibility configuration
        metadataLabel.setAccessibilityRole(.staticText)
        metadataLabel.setAccessibilityLabel("Screenshot metadata")
        metadataLabel.setAccessibilityIdentifier("screenshot-metadata")

        addSubview(metadataLabel)
        metadataLabel.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            metadataLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: contentPadding),
            metadataLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -contentPadding),
            metadataLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -(outerBorderWidth + borderSpacing + innerBorderWidth + 10)),
            metadataLabel.heightAnchor.constraint(equalToConstant: 20)
        ])
    }

    private func setupPlaceholderLabel() {
        placeholderLabel = NSTextField()
        placeholderLabel.isEditable = false
        placeholderLabel.isBordered = false
        placeholderLabel.backgroundColor = NSColor.clear
        // Use system-defined vibrant color that automatically adjusts contrast over materials
        placeholderLabel.textColor = NSColor.secondaryLabelColor
        placeholderLabel.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        placeholderLabel.alignment = .center
        placeholderLabel.stringValue = "No screenshots captured\n\nPress ⌘E to capture"
        placeholderLabel.maximumNumberOfLines = 0

        // Accessibility configuration
        placeholderLabel.setAccessibilityRole(.staticText)
        placeholderLabel.setAccessibilityLabel("Clipboard status")
        placeholderLabel.setAccessibilityHelp("Shows the current status of the clipboard window")
        placeholderLabel.setAccessibilityIdentifier("clipboard-status")

        addSubview(placeholderLabel)
        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            placeholderLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            placeholderLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            placeholderLabel.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: contentPadding),
            placeholderLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -contentPadding)
        ])
    }

    private func setupToolbar() {
        toolbar = ClipboardToolbar()
        toolbar.delegate = self

        addSubview(toolbar)
        toolbar.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            toolbar.centerXAnchor.constraint(equalTo: centerXAnchor),
            toolbar.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -(outerBorderWidth + borderSpacing + innerBorderWidth + contentPadding))
        ])

        print("🔧 [SETUP] ClipboardToolbar created and positioned at bottom")
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Modern border design that works with NSVisualEffectView
        let outerRect = bounds
        let innerRect = NSRect(
            x: outerBorderWidth + borderSpacing,
            y: outerBorderWidth + borderSpacing,
            width: bounds.width - 2 * (outerBorderWidth + borderSpacing),
            height: bounds.height - 2 * (outerBorderWidth + borderSpacing)
        )

        // Draw subtle outer border with dynamic color
        let outerPath = NSBezierPath(roundedRect: outerRect, xRadius: 12.0, yRadius: 12.0)
        if #available(macOS 10.14, *) {
            NSColor.separatorColor.withAlphaComponent(0.3).setStroke()
        } else {
            NSColor.separatorColor.setStroke()
        }
        outerPath.lineWidth = outerBorderWidth
        outerPath.stroke()

        // Draw modern inner accent border
        let innerPath = NSBezierPath(roundedRect: innerRect, xRadius: 8.0, yRadius: 8.0)

        // Use system accent color for modern appearance
        if #available(macOS 10.14, *) {
            NSColor.controlAccentColor.withAlphaComponent(0.6).setStroke()
        } else {
            currentBorderColor.setStroke()
        }

        innerPath.lineWidth = innerBorderWidth

        // Modern solid border instead of dashed for cleaner look
        innerPath.stroke()
    }

    // MARK: - Image Display

    func displayImage(_ capturedImage: CapturedImage) {
        // Set both image and captured image data for drag operations
        imageView.image = capturedImage.image
        imageView.capturedImage = capturedImage
        imageView.isHidden = false
        placeholderLabel.isHidden = true

        // Update metadata
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short

        let metadataText = "\(capturedImage.displayDimensions) • \(formatter.string(from: capturedImage.captureDate))"
        metadataLabel.stringValue = metadataText
        metadataLabel.isHidden = false

        needsDisplay = true
        print("📎 [VIEW] Image displayed with drag capability: \(capturedImage.displayDimensions)")
    }

    func showSelectionDetected() {
        // Hide any existing image and metadata
        imageView.isHidden = true
        metadataLabel.isHidden = true

        // Show selection detected message with proper system color
        placeholderLabel.stringValue = "Selection detected\n\nDrag to select screen area"
        placeholderLabel.textColor = NSColor.secondaryLabelColor
        placeholderLabel.isHidden = false

        // Update accessibility information
        if #available(macOS 10.13, *) {
            placeholderLabel.setAccessibilityValue("Selection detected. Drag to select screen area.")
        }

        needsDisplay = true
        print("📋 [VIEW] Selection detected message displayed")
        print("♿ [A11Y] Accessibility updated for selection state")
    }

    func clearImage() {
        imageView.image = nil
        imageView.isHidden = true
        metadataLabel.isHidden = true

        // Restore original placeholder text with proper system color
        placeholderLabel.stringValue = "No screenshots captured\n\nPress ⌘E to capture"
        placeholderLabel.textColor = NSColor.secondaryLabelColor
        placeholderLabel.isHidden = false

        // Update accessibility information
        if #available(macOS 10.13, *) {
            placeholderLabel.setAccessibilityValue("No screenshots captured. Press Command E to capture.")
            imageView.setAccessibilityValue(nil)
        }

        needsDisplay = true
        print("♿ [A11Y] Accessibility cleared for empty state")
    }

    func updateWithCapturedImage(_ capturedImage: CapturedImage) {
        print("🖼️ [VIEW] Updating ClipboardWindowView with captured image")

        // Set the thumbnail image for display (not the full resolution image)
        imageView.image = capturedImage.thumbnailImage
        imageView.capturedImage = capturedImage

        // Update metadata with file information
        let sizeInMB = Double(capturedImage.fileSize) / (1024 * 1024)
        let formattedSize = String(format: "%.1f MB", sizeInMB)

        metadataLabel.stringValue = """
        \(capturedImage.displayDimensions)
        \(formattedSize) • \(capturedImage.fileName)
        \(capturedImage.fileDirectory)
        """

        // Update accessibility information
        if #available(macOS 10.13, *) {
            let accessibilityDescription = "Screenshot of \(capturedImage.displayDimensions), file size \(formattedSize), saved as \(capturedImage.fileName)"
            imageView.setAccessibilityValue(accessibilityDescription)
            metadataLabel.setAccessibilityValue(metadataLabel.stringValue)
        }

        // Show the image and hide placeholder
        imageView.isHidden = false
        metadataLabel.isHidden = false
        placeholderLabel.isHidden = true

        needsDisplay = true

        print("✅ [VIEW] Image view updated with thumbnail: \(Int(capturedImage.thumbnailImage.size.width))×\(Int(capturedImage.thumbnailImage.size.height))")
        print("📁 [VIEW] Original file: \(capturedImage.filePath.path)")
        print("♿ [A11Y] Accessibility information updated for screenshot")
    }

    @objc private func colorPreferenceChanged() {
        needsDisplay = true
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override var isOpaque: Bool {
        return false
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }
}

// MARK: - ClipboardToolbarDelegate

extension ClipboardWindowView: ClipboardToolbarDelegate {
    func screenshotButtonTapped() {
        print("📎 [TOOLBAR] Screenshot button action received")
        // Delegate to parent window for screenshot actions
        if let window = window as? ClipboardWindow {
            window.handleScreenshotButtonAction()
        }
    }

    func chatButtonTapped() {
        print("💬 [TOOLBAR] Chat button action received")
        // Delegate to parent window for chat actions
        if let window = window as? ClipboardWindow {
            window.handleChatButtonAction()
        }
    }

    func galleryButtonTapped() {
        print("🖼️ [TOOLBAR] Gallery button action received")
        // Delegate to parent window for gallery actions
        if let window = window as? ClipboardWindow {
            window.handleGalleryButtonAction()
        }
    }
}
