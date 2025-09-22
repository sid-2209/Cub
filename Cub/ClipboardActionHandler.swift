//
//  ClipboardActionHandler.swift
//  Cub
//
//  Created by sid on 21/09/24.
//  Extracted action handling logic from ClipboardWindow.swift for modular architecture
//

import Cocoa
import Foundation

// MARK: - Action Handling Protocol

protocol ClipboardActionHandling: AnyObject {
    func handleScreenshotButtonAction(for image: CapturedImage?, in window: NSWindow)
    func handleChatButtonAction(in window: NSWindow)
    func handleGalleryButtonAction()
    func copyScreenshot(_ image: CapturedImage)
    func openScreenshot(_ image: CapturedImage)
    func revealScreenshot(_ image: CapturedImage)
    func showNoScreenshotFeedback(for window: NSWindow)
}

// MARK: - Action Handler Implementation

class ClipboardActionHandler: ClipboardActionHandling {

    // MARK: - Screenshot Actions

    func handleScreenshotButtonAction(for image: CapturedImage?, in window: NSWindow) {
        print("📎 [ACTION] Handling screenshot button action")

        guard let currentImage = image else {
            print("ℹ️ [ACTION] No current screenshot available")
            showNoScreenshotFeedback(for: window)
            return
        }

        print("📸 [ACTION] Current screenshot available: \(currentImage.fileName)")
        showScreenshotActionMenu(for: currentImage, in: window)
    }

    func copyScreenshot(_ image: CapturedImage) {
        print("📋 [ACTION] Copying screenshot to clipboard")

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([image.image])

        print("✅ [ACTION] Screenshot copied to clipboard: \(image.fileName)")
    }

    func openScreenshot(_ image: CapturedImage) {
        print("🚀 [ACTION] Opening screenshot in default app")

        NSWorkspace.shared.open(image.filePath)
        print("✅ [ACTION] Screenshot opened: \(image.filePath.lastPathComponent)")
    }

    func revealScreenshot(_ image: CapturedImage) {
        print("🔍 [ACTION] Revealing screenshot in Finder")

        NSWorkspace.shared.activateFileViewerSelecting([image.filePath])
        print("✅ [ACTION] Screenshot revealed in Finder: \(image.filePath.lastPathComponent)")
    }

    // MARK: - Other Button Actions

    func handleChatButtonAction(in window: NSWindow) {
        print("💬 [ACTION] Handling chat button action")

        // TODO: Implement chat functionality
        // For now, show a placeholder action
        showChatPlaceholder(for: window)

        print("✅ [ACTION] Chat action completed")
    }

    func handleGalleryButtonAction() {
        print("🖼️ [ACTION] Handling gallery button action")

        // Show the gallery window
        GalleryWindowController.show()

        print("✅ [ACTION] Gallery window requested to show")
    }

    // MARK: - Feedback Actions

    func showNoScreenshotFeedback(for window: NSWindow) {
        print("💡 [ACTION] Showing visual feedback for no screenshot")

        // Subtle animation to indicate no screenshot available
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.allowsImplicitAnimation = true
            window.alphaValue = 0.7
        } completionHandler: {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2
                context.allowsImplicitAnimation = true
                window.alphaValue = 1.0
            }
        }
    }

    // MARK: - Private Implementation

    private func showScreenshotActionMenu(for image: CapturedImage, in window: NSWindow) {
        let menu = NSMenu()
        menu.autoenablesItems = false

        // Copy to Clipboard action
        let copyItem = NSMenuItem(
            title: "Copy to Clipboard",
            action: #selector(copyCurrentScreenshotAction),
            keyEquivalent: "c"
        )
        copyItem.target = self
        copyItem.isEnabled = true
        copyItem.representedObject = image
        menu.addItem(copyItem)

        // Open in Default App action
        let openItem = NSMenuItem(
            title: "Open in Default App",
            action: #selector(openCurrentScreenshotAction),
            keyEquivalent: "o"
        )
        openItem.target = self
        openItem.isEnabled = true
        openItem.representedObject = image
        menu.addItem(openItem)

        menu.addItem(NSMenuItem.separator())

        // Reveal in Finder action
        let revealItem = NSMenuItem(
            title: "Reveal in Finder",
            action: #selector(revealCurrentScreenshotAction),
            keyEquivalent: "r"
        )
        revealItem.target = self
        revealItem.isEnabled = true
        revealItem.representedObject = image
        menu.addItem(revealItem)

        // Show menu near the center of the window
        let windowFrame = window.frame
        let menuPoint = NSPoint(
            x: windowFrame.midX,
            y: windowFrame.midY
        )

        menu.popUp(positioning: nil, at: menuPoint, in: nil)
        print("📋 [ACTION] Screenshot action menu displayed")
    }

    private func showChatPlaceholder(for window: NSWindow) {
        print("💡 [ACTION] Chat placeholder feedback shown")

        // Subtle animation to indicate chat feature is not yet implemented
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            context.allowsImplicitAnimation = true
            window.alphaValue = 0.8
        } completionHandler: {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.15
                context.allowsImplicitAnimation = true
                window.alphaValue = 1.0
            }
        }
    }

    // MARK: - Action Selectors

    @objc private func copyCurrentScreenshotAction(_ sender: NSMenuItem) {
        guard let image = sender.representedObject as? CapturedImage else { return }
        copyScreenshot(image)
    }

    @objc private func openCurrentScreenshotAction(_ sender: NSMenuItem) {
        guard let image = sender.representedObject as? CapturedImage else { return }
        openScreenshot(image)
    }

    @objc private func revealCurrentScreenshotAction(_ sender: NSMenuItem) {
        guard let image = sender.representedObject as? CapturedImage else { return }
        revealScreenshot(image)
    }
}

// MARK: - Action Handler Extensions

extension ClipboardActionHandler {

    /// Performs a custom action with the current screenshot
    func performCustomAction(with image: CapturedImage, action: (CapturedImage) -> Void) {
        print("🔧 [ACTION] Performing custom action with screenshot: \(image.fileName)")
        action(image)
    }

    /// Batch action handling for multiple screenshots
    func handleBatchAction(for images: [CapturedImage], action: BatchAction) {
        print("📦 [ACTION] Handling batch action: \(action) for \(images.count) screenshots")

        switch action {
        case .copy:
            batchCopyScreenshots(images)
        case .export:
            batchExportScreenshots(images)
        case .delete:
            batchDeleteScreenshots(images)
        }
    }

    private func batchCopyScreenshots(_ images: [CapturedImage]) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        let nsImages = images.map { $0.image }
        pasteboard.writeObjects(nsImages)

        print("✅ [ACTION] Batch copied \(images.count) screenshots to clipboard")
    }

    private func batchExportScreenshots(_ images: [CapturedImage]) {
        // TODO: Implement batch export functionality
        print("📤 [ACTION] Batch export not yet implemented for \(images.count) screenshots")
    }

    private func batchDeleteScreenshots(_ images: [CapturedImage]) {
        // TODO: Implement batch delete functionality
        print("🗑️ [ACTION] Batch delete not yet implemented for \(images.count) screenshots")
    }
}

// MARK: - Supporting Types

enum BatchAction {
    case copy
    case export
    case delete

    var displayName: String {
        switch self {
        case .copy: return "Copy"
        case .export: return "Export"
        case .delete: return "Delete"
        }
    }
}
