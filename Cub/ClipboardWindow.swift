//
//  ClipboardWindow.swift
//  Cub
//
//  Created by sid on 15/09/25.
//

import Cocoa
import SwiftUI

enum ClipboardWindowState {
    case hidden
    case visible
    case alwaysVisible
}

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
        positionWindowAtRightEdge()

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

    private func positionWindowAtRightEdge() {
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

        // Ensure window fits within screen bounds with stricter constraints
        let maxWidth = visibleFrame.width * 0.25 // Maximum 25% of screen width
        let maxHeight = visibleFrame.height - topMargin * 2

        let adjustedWidth = min(windowWidth, min(maxWidth, visibleFrame.width - edgeMargin * 2))
        let adjustedHeight = min(windowHeight, maxHeight)

        print("📍 [POSITION] Adjusted dimensions: \(adjustedWidth) x \(adjustedHeight)")

        // Calculate X position ensuring we don't go off-screen
        let xPosition = max(visibleFrame.minX + edgeMargin, visibleFrame.maxX - adjustedWidth - edgeMargin)

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

    // MARK: - Public Methods

    func showClipboard() {
        print("📋 [WINDOW] showClipboard() called - current state: \(windowState)")

        // Don't show if already visible, but allow alwaysVisible to show again
        guard windowState == .hidden else {
            print("📋 [WINDOW] Window already visible or alwaysVisible, skipping show")
            return
        }

        windowState = .visible
        print("📋 [WINDOW] Setting state to visible, positioning window...")

        positionWindowAtRightEdge()
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
        print("📋 [WINDOW] Clipboard window shown with animation")
    }

    func hideClipboard() {
        guard windowState != .hidden else { return }

        windowState = .hidden

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
            positionWindowAtRightEdge()
            print("📋 [WINDOW] Window positioned at right edge")

            // Set state to alwaysVisible
            windowState = .alwaysVisible
            print("📋 [WINDOW] State set to alwaysVisible")

            // Make window visible with proper ordering and activation
            orderFront(nil)
            makeKeyAndOrderFront(nil)
            alphaValue = 1.0

            print("📋 [WINDOW] Window made visible with orderFront and makeKeyAndOrderFront")
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
        // Allow window to be dragged
        performDrag(with: event)
    }

    // MARK: - Screen Changes

    func handleScreenChange() {
        positionWindowAtRightEdge()
    }

    // MARK: - Helper Properties

    var isClipboardVisible: Bool {
        return windowState != .hidden && isVisible
    }

    var hasImage: Bool {
        return currentImage != nil
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

    // MARK: - Window Behavior Overrides

    override var canBecomeKey: Bool {
        return false
    }

    override var canBecomeMain: Bool {
        return false
    }
}

// MARK: - ClipboardWindowState Extension

extension ClipboardWindowState {
    var rawValue: String {
        switch self {
        case .hidden: return "hidden"
        case .visible: return "visible"
        case .alwaysVisible: return "alwaysVisible"
        }
    }
}

// MARK: - DraggableImageView

class DraggableImageView: NSImageView {
    var capturedImage: CapturedImage?
    private var dragThreshold: CGFloat = 5.0
    private var initialMouseLocation: NSPoint = .zero
    private var isDragInProgress: Bool = false

    override func mouseDown(with event: NSEvent) {
        initialMouseLocation = event.locationInWindow
        isDragInProgress = false

        // Only handle drag if we have an image and valid bounds
        guard let dragImage = image else {
            print("📎 [DRAG] Mouse down ignored - no image available")
            super.mouseDown(with: event)
            return
        }

        guard bounds.width > 0 && bounds.height > 0 else {
            print("❌ [DRAG] Mouse down ignored - invalid bounds: \(bounds)")
            super.mouseDown(with: event)
            return
        }

        guard capturedImage != nil else {
            print("❌ [DRAG] Mouse down ignored - no captured image data available")
            super.mouseDown(with: event)
            return
        }

        print("📎 [DRAG] Mouse down on draggable image at: \(initialMouseLocation)")
        print("📎 [DRAG] Image size: \(dragImage.size), bounds: \(bounds)")
    }

    override func mouseDragged(with event: NSEvent) {
        guard image != nil else {
            super.mouseDragged(with: event)
            return
        }

        let currentLocation = event.locationInWindow
        let dragDistance = sqrt(pow(currentLocation.x - initialMouseLocation.x, 2) + pow(currentLocation.y - initialMouseLocation.y, 2))

        // Check if we've exceeded the drag threshold
        if dragDistance > dragThreshold && !isDragInProgress {
            isDragInProgress = true
            print("📎 [DRAG] Drag threshold exceeded (\(String(format: "%.1f", dragDistance))px), initiating drag session")
            print("📎 [DRAG] Current location: \(currentLocation), initial: \(initialMouseLocation)")

            do {
                try initiateDragSession(with: event)
            } catch {
                print("❌ [DRAG] Failed to initiate drag session: \(error)")
                isDragInProgress = false
            }
        }
    }

    override func mouseUp(with event: NSEvent) {
        let wasDragging = isDragInProgress
        isDragInProgress = false

        if wasDragging {
            print("📎 [DRAG] Mouse up, drag session ended")
        } else {
            print("📎 [DRAG] Mouse up, no drag session was active")
        }

        super.mouseUp(with: event)
    }

    private func initiateDragSession(with event: NSEvent) throws {
        guard let dragImage = image,
              let capturedImageData = capturedImage else {
            let error = NSError(domain: "DragError", code: 1, userInfo: [NSLocalizedDescriptionKey: "No image or captured image data available"])
            print("❌ [DRAG] \(error.localizedDescription)")
            throw error
        }

        // Validate image view bounds to prevent zero-size drag frame
        guard bounds.width > 0 && bounds.height > 0 else {
            let error = NSError(domain: "DragError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid bounds for drag operation: \(bounds)"])
            print("❌ [DRAG] \(error.localizedDescription)")
            throw error
        }

        print("📎 [DRAG] Preparing drag session for image: \(dragImage.size)")
        print("📎 [DRAG] Image view bounds: \(bounds)")

        // Create pasteboard item for drag session (don't write to pasteboard yet)
        guard let pasteboardItem = createPasteboardItem(from: capturedImageData) else {
            let error = NSError(domain: "DragError", code: 5, userInfo: [NSLocalizedDescriptionKey: "Failed to create pasteboard item"])
            print("❌ [DRAG] \(error.localizedDescription)")
            throw error
        }

        print("📎 [DRAG] Created pasteboard item with data formats")

        // Create drag image (slightly smaller and semi-transparent)
        let dragImageSize = NSSize(
            width: min(dragImage.size.width * 0.8, 200),
            height: min(dragImage.size.height * 0.8, 200)
        )

        let dragImageView = NSImageView(frame: NSRect(origin: .zero, size: dragImageSize))
        dragImageView.image = dragImage
        dragImageView.imageScaling = .scaleProportionallyUpOrDown
        dragImageView.alphaValue = 0.8

        // Calculate drag image offset (center it on cursor)
        let _ = NSPoint(
            x: -dragImageSize.width / 2,
            y: -dragImageSize.height / 2
        )

        // Create NSDraggingItem and set its draggingFrame to prevent crash
        let draggingItem = NSDraggingItem(pasteboardWriter: pasteboardItem)

        // Set the dragging frame to the image view's bounds (critical for drag to work)
        draggingItem.draggingFrame = bounds

        print("📎 [DRAG] Created dragging item with frame: \(draggingItem.draggingFrame)")

        // Verify frame is non-zero before proceeding
        guard draggingItem.draggingFrame.width > 0 && draggingItem.draggingFrame.height > 0 else {
            let error = NSError(domain: "DragError", code: 3, userInfo: [NSLocalizedDescriptionKey: "Dragging frame is zero size: \(draggingItem.draggingFrame)"])
            print("❌ [DRAG] \(error.localizedDescription)")
            throw error
        }

        // Begin the drag session (this will handle pasteboard operations internally)
        beginDraggingSession(
            with: [draggingItem],
            event: event,
            source: self
        )

        print("✅ [DRAG] Drag session initiated successfully with frame: \(draggingItem.draggingFrame)")
    }

    private func createPasteboardItem(from capturedImage: CapturedImage) -> NSPasteboardItem? {
        let pasteboardItem = NSPasteboardItem()

        print("📎 [DRAG] Creating file-based pasteboard item")
        print("📁 [DRAG] Original file: \(capturedImage.filePath.path)")
        print("📦 [DRAG] File size: \(formatFileSize(capturedImage.fileSize))")

        // Priority 1: File URL (preserves 100% original quality)
        pasteboardItem.setString(capturedImage.filePath.absoluteString, forType: .fileURL)
        print("✅ [DRAG] Added original file URL: \(capturedImage.filePath.lastPathComponent)")

        // Priority 2: File content as data (for apps that prefer data over URLs)
        do {
            let fileData = try Data(contentsOf: capturedImage.filePath)
            let fileExtension = capturedImage.filePath.pathExtension.lowercased()

            switch fileExtension {
            case "png":
                pasteboardItem.setData(fileData, forType: .png)
                print("✅ [DRAG] Added PNG file data (\(fileData.count) bytes)")
            case "jpg", "jpeg":
                pasteboardItem.setData(fileData, forType: NSPasteboard.PasteboardType("public.jpeg"))
                print("✅ [DRAG] Added JPEG file data (\(fileData.count) bytes)")
            case "tiff", "tif":
                pasteboardItem.setData(fileData, forType: .tiff)
                print("✅ [DRAG] Added TIFF file data (\(fileData.count) bytes)")
            default:
                print("⚠️ [DRAG] Unknown file format: \(fileExtension)")
            }
        } catch {
            print("❌ [DRAG] Failed to read file data: \(error)")
        }

        return pasteboardItem
    }

    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

}

// MARK: - NSDraggingSource Implementation

extension DraggableImageView: NSDraggingSource {
    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        // Support copy operation (most common for images)
        return .copy
    }

    func draggingSession(_ session: NSDraggingSession, willBeginAt screenPoint: NSPoint) {
        print("📎 [DRAG] Drag session beginning at: \(screenPoint)")

        // Add visual feedback - slightly fade the original image
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            self.animator().alphaValue = 0.6
        }
    }

    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        print("📎 [DRAG] Drag session ended at: \(screenPoint) with operation: \(operation.rawValue)")

        // Restore original appearance
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            self.animator().alphaValue = 1.0
        }

        // Provide user feedback based on operation
        if operation == .copy {
            print("✅ [DRAG] Image successfully copied to target application")
        } else {
            print("⚠️ [DRAG] Drag operation cancelled or failed")
        }
    }

    func draggingSession(_ session: NSDraggingSession, movedTo screenPoint: NSPoint) {
        // Optional: Add additional visual feedback during drag
        // Could update cursor or provide other visual cues
    }
}

// MARK: - ClipboardWindowView

class ClipboardWindowView: NSView {
    private var imageView: DraggableImageView!
    private var metadataLabel: NSTextField!
    private var placeholderLabel: NSTextField!

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
            // Primary text with vibrancy
            placeholderLabel.textColor = NSColor.labelColor
            metadataLabel.textColor = NSColor.secondaryLabelColor

            // Enhance readability with subtle background for text
            placeholderLabel.wantsLayer = true
            placeholderLabel.layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.1).cgColor
            placeholderLabel.layer?.cornerRadius = 4.0
        }

        print("✅ [MODERN] Vibrancy effects configured for text legibility")
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
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -(outerBorderWidth + borderSpacing + innerBorderWidth + contentPadding + 40)) // Space for metadata
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
        placeholderLabel.textColor = NSColor.tertiaryLabelColor
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

        // Show selection detected message
        placeholderLabel.stringValue = "Selection detected\n\nDrag to select screen area"
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

        // Restore original placeholder text
        placeholderLabel.stringValue = "No screenshots captured\n\nPress ⌘E to capture"
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