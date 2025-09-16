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
        // Window appearance
        backgroundColor = NSColor.clear
        isOpaque = false
        hasShadow = true
        level = NSWindow.Level.floating
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]

        // Window behavior
        hidesOnDeactivate = false
        ignoresMouseEvents = false
        acceptsMouseMovedEvents = false

        // Remove from window list and dock
        isExcludedFromWindowsMenu = true

        // Set strict size constraints on the window itself
        minSize = NSSize(width: 200, height: 300)
        maxSize = NSSize(width: windowWidth, height: windowHeight)

        // Window ordering will be handled by overridden properties

        // Position window properly
        positionWindowAtRightEdge()

        print("📋 Window setup completed with level: \(level.rawValue)")
        print("📋 Window size constraints: min=\(minSize), max=\(maxSize)")
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

    func updateWithCapturedImage(_ capturedImage: CapturedImage) {
        print("📋 [CLIPBOARD] updateWithCapturedImage called with image: \(capturedImage.displayDimensions)")
        print("📋 [CLIPBOARD] Current window state: \(windowState)")
        print("📋 [CLIPBOARD] ClipboardView available: \(clipboardView != nil ? "✅ Yes" : "❌ No")")

        currentImage = capturedImage
        clipboardView.displayImage(capturedImage)

        // Show window if it's hidden and we have an image
        if windowState == .hidden {
            print("📋 [CLIPBOARD] Window is hidden, calling showClipboard()")
            showClipboard()
        } else {
            print("📋 [CLIPBOARD] Window state is: \(windowState), not showing")
        }

        print("📋 [CLIPBOARD] Clipboard updated with new image: \(capturedImage.displayDimensions)")
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

        // Add TIFF representation (highest quality)
        if let tiffData = capturedImage.image.tiffRepresentation {
            pasteboardItem.setData(tiffData, forType: .tiff)
            print("📎 [DRAG] Added TIFF data (\(tiffData.count) bytes)")
        }

        // Add PNG representation (web compatible)
        if let pngData = createPNGData(from: capturedImage.image) {
            pasteboardItem.setData(pngData, forType: .png)
            print("📎 [DRAG] Added PNG data (\(pngData.count) bytes)")
        }

        // Add file URL as fallback (create temporary file)
        if let fileURL = createTemporaryImageFile(from: capturedImage) {
            pasteboardItem.setString(fileURL.absoluteString, forType: .fileURL)
            print("📎 [DRAG] Added file URL: \(fileURL.path)")
        }

        return pasteboardItem
    }

    private func createPNGData(from image: NSImage) -> Data? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }

        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        return bitmapRep.representation(using: .png, properties: [:])
    }

    private func createTemporaryImageFile(from capturedImage: CapturedImage) -> URL? {
        let tempDirectory = FileManager.default.temporaryDirectory
        let fileName = "Cub_Screenshot_\(Int(Date().timeIntervalSince1970)).png"
        let fileURL = tempDirectory.appendingPathComponent(fileName)

        guard let pngData = createPNGData(from: capturedImage.image) else {
            return nil
        }

        do {
            try pngData.write(to: fileURL)
            return fileURL
        } catch {
            print("❌ [DRAG] Failed to create temporary file: \(error)")
            return nil
        }
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
        // Background
        wantsLayer = true
        layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        layer?.cornerRadius = 8.0

        // Add size constraints to prevent expansion
        translatesAutoresizingMaskIntoConstraints = false

        setupImageView()
        setupMetadataLabel()
        setupPlaceholderLabel()

        // Listen for color preference changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(colorPreferenceChanged),
            name: NSNotification.Name("BorderColorChanged"),
            object: nil
        )
    }

    private func setupImageView() {
        imageView = DraggableImageView()
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.imageAlignment = .alignCenter
        imageView.isHidden = true

        addSubview(imageView)
        imageView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: topAnchor, constant: outerBorderWidth + borderSpacing + innerBorderWidth + contentPadding),
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: outerBorderWidth + borderSpacing + innerBorderWidth + contentPadding),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -(outerBorderWidth + borderSpacing + innerBorderWidth + contentPadding)),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -(outerBorderWidth + borderSpacing + innerBorderWidth + contentPadding + 40)) // Space for metadata
        ])

        print("📎 [SETUP] DraggableImageView created and configured for drag operations")
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

        let outerRect = bounds
        let innerRect = NSRect(
            x: outerBorderWidth + borderSpacing,
            y: outerBorderWidth + borderSpacing,
            width: bounds.width - 2 * (outerBorderWidth + borderSpacing),
            height: bounds.height - 2 * (outerBorderWidth + borderSpacing)
        )

        // Draw outer border (subtle)
        let outerPath = NSBezierPath(roundedRect: outerRect, xRadius: 8.0, yRadius: 8.0)
        NSColor.separatorColor.setStroke()
        outerPath.lineWidth = outerBorderWidth
        outerPath.stroke()

        // Draw inner dashed border (bold, colored)
        let innerPath = NSBezierPath(roundedRect: innerRect, xRadius: 4.0, yRadius: 4.0)
        currentBorderColor.setStroke()
        innerPath.lineWidth = innerBorderWidth

        // Create dashed pattern
        let dashPattern: [CGFloat] = [8.0, 4.0]
        innerPath.setLineDash(dashPattern, count: 2, phase: 0.0)
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

        needsDisplay = true
        print("📋 [VIEW] Selection detected message displayed")
    }

    func clearImage() {
        imageView.image = nil
        imageView.isHidden = true
        metadataLabel.isHidden = true

        // Restore original placeholder text
        placeholderLabel.stringValue = "No screenshots captured\n\nPress ⌘E to capture"
        placeholderLabel.isHidden = false

        needsDisplay = true
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