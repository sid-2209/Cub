//
//  DraggableImageView.swift
//  Cub
//
//  Created by sid on 21/09/24.
//  Extracted from ClipboardWindow.swift for modular architecture
//

import Cocoa

// MARK: - Draggable Image View

class DraggableImageView: NSImageView {
    var capturedImage: CapturedImage?
    private var dragThreshold: CGFloat = 5.0
    private var initialMouseLocation: NSPoint = .zero
    private var isDragInProgress: Bool = false

    // MARK: - Mouse Event Handling

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

    // MARK: - Drag Session Management

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

    // MARK: - Pasteboard Management

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

    // MARK: - Utility Methods

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

// MARK: - Configuration Extensions

extension DraggableImageView {

    /// Configures the image view with accessibility settings
    func configureAccessibility() {
        if #available(macOS 10.13, *) {
            setAccessibilityRole(.image)
            setAccessibilityLabel("Screenshot thumbnail")
            setAccessibilityHelp("Drag this image to copy it to another application")
            setAccessibilityIdentifier("screenshot-thumbnail")
        }
    }

    /// Updates the image view with a new captured image
    func updateWith(capturedImage: CapturedImage) {
        self.capturedImage = capturedImage
        self.image = capturedImage.thumbnailImage
        self.isHidden = false

        // Update accessibility information if available
        if #available(macOS 10.13, *) {
            let sizeInMB = Double(capturedImage.fileSize) / (1024 * 1024)
            let formattedSize = String(format: "%.1f MB", sizeInMB)
            let accessibilityDescription = "Screenshot of \(capturedImage.displayDimensions), file size \(formattedSize), saved as \(capturedImage.fileName)"
            setAccessibilityValue(accessibilityDescription)
        }

        print("📎 [VIEW] DraggableImageView updated with: \(capturedImage.fileName)")
    }

    /// Clears the current image and hides the view
    func clearImage() {
        self.capturedImage = nil
        self.image = nil
        self.isHidden = true

        if #available(macOS 10.13, *) {
            setAccessibilityValue(nil)
        }

        print("📎 [VIEW] DraggableImageView cleared")
    }
}
