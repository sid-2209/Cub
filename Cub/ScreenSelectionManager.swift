//
//  ScreenSelectionManager.swift
//  Cub
//
//  Created by sid on 15/09/25.
//

import Cocoa
import SwiftUI

protocol ScreenSelectionDelegate: AnyObject {
    func screenSelectionCompleted(rect: NSRect, screen: NSScreen)
    func screenSelectionCancelled()
}

class ScreenSelectionManager: NSObject, ObservableObject {
    weak var delegate: ScreenSelectionDelegate?

    private var overlayWindows: [SelectionOverlayWindow] = []
    private var isSelectionActive: Bool = false

    private weak var permissionManager: PermissionManager?

    func setPermissionManager(_ manager: PermissionManager) {
        self.permissionManager = manager
    }

    // MARK: - Public Methods

    func startScreenSelection() {
        // Check permissions first
        guard let permissionManager = permissionManager else {
            showErrorAlert("Permission manager not available")
            return
        }

        if !permissionManager.isPermissionGranted {
            showPermissionRequiredAlert()
            return
        }

        if isSelectionActive {
            print("⚠️ Selection already active, ignoring")
            return
        }

        print("🎯 Starting screen selection...")
        isSelectionActive = true

        createOverlayWindows()
        showOverlayWindows()
    }

    func cancelSelection() {
        print("🚫 Cancelling screen selection")
        dismissOverlayWindows()
        delegate?.screenSelectionCancelled()
    }

    // MARK: - Multi-Monitor Support

    private func createOverlayWindows() {
        // Clear existing windows
        dismissOverlayWindows()

        // Get all connected screens
        let screens = NSScreen.screens
        print("📺 Detected \(screens.count) screen(s)")

        // Create overlay window for each screen
        for (index, screen) in screens.enumerated() {
            let overlayWindow = SelectionOverlayWindow(for: screen)
            overlayWindow.selectionDelegate = self

            overlayWindows.append(overlayWindow)

            print("📱 Created overlay for screen \(index + 1): \(screen.frame)")
        }
    }

    private func showOverlayWindows() {
        // Hide dock and menu bar temporarily
        NSApplication.shared.presentationOptions = [.hideDock, .hideMenuBar]

        // Show all overlay windows
        for overlayWindow in overlayWindows {
            overlayWindow.makeKeyAndOrderFront(nil)
        }

        // Make the first window key to start receiving events
        overlayWindows.first?.makeKey()

        print("✨ All overlay windows shown")
    }

    private func dismissOverlayWindows() {
        // Restore dock and menu bar
        NSApplication.shared.presentationOptions = []

        // Dismiss all overlay windows
        for overlayWindow in overlayWindows {
            overlayWindow.orderOut(nil)
        }

        overlayWindows.removeAll()
        isSelectionActive = false

        print("🗑️ All overlay windows dismissed")
    }

    // MARK: - Error Handling

    private func showPermissionRequiredAlert() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Screen Recording Permission Required"
            alert.informativeText = "Screen selection requires screen recording permission. Please grant permission first."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Open System Preferences")
            alert.addButton(withTitle: "Cancel")

            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                self.permissionManager?.requestScreenRecordingPermission()
            }
        }
    }

    private func showErrorAlert(_ message: String) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Screen Selection Error"
            alert.informativeText = message
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }

    // MARK: - Coordinate Conversion

    private func convertSelectionToGlobalCoordinates(_ rect: NSRect, from screen: NSScreen) -> NSRect {
        // Convert overlay window coordinates to display coordinates for ScreenCaptureKit
        // CRITICAL: Window coordinates have bottom-left origin, ScreenCaptureKit expects top-left origin
        let screenFrame = screen.frame

        print("🌍 [COORD] convertSelectionToGlobalCoordinates:")
        print("   Input rect (window coords, bottom-left origin): \(rect)")
        print("   Screen frame: \(screenFrame)")

        // Step 1: Convert from window coordinates (bottom-left origin) to display coordinates (top-left origin)
        // Formula: displayY = screenHeight - windowY - selectionHeight
        let displayCoordinatesRect = NSRect(
            x: rect.origin.x,  // X remains the same
            y: screenFrame.height - rect.origin.y - rect.height,  // ✅ Y-coordinate flip for top-left origin
            width: rect.width,
            height: rect.height
        )

        print("   Converted to display coords (top-left origin): \(displayCoordinatesRect)")

        // Step 2: Add screen origin offset for multi-monitor support
        let globalRect = NSRect(
            x: screenFrame.origin.x + displayCoordinatesRect.origin.x,
            y: screenFrame.origin.y + displayCoordinatesRect.origin.y,
            width: displayCoordinatesRect.width,
            height: displayCoordinatesRect.height
        )

        print("   Final global rect (display coords): \(globalRect)")

        // Mathematical verification logging
        print("🔍 [COORD] Mathematical verification:")
        print("   Screen height: \(screenFrame.height)")
        print("   Window Y: \(rect.origin.y)")
        print("   Selection height: \(rect.height)")
        print("   Display Y = \(screenFrame.height) - \(rect.origin.y) - \(rect.height) = \(displayCoordinatesRect.origin.y)")

        // Validate the converted coordinates are within screen bounds
        let screenBoundsForValidation = NSRect(
            x: screenFrame.origin.x,
            y: screenFrame.origin.y,
            width: screenFrame.width,
            height: screenFrame.height
        )

        if !globalRect.intersects(screenBoundsForValidation) {
            print("⚠️ [COORD] WARNING: Converted rect doesn't intersect with source screen")
            print("   Screen bounds: \(screenBoundsForValidation)")
            print("   Converted rect: \(globalRect)")
        } else {
            print("✅ [COORD] Converted rect intersects correctly with screen bounds")
        }

        // Additional validation - ensure rect is within reasonable bounds
        if globalRect.origin.y < 0 || globalRect.maxY > screenFrame.maxY {
            print("⚠️ [COORD] WARNING: Y coordinates may be out of bounds")
            print("   Rect Y range: \(globalRect.origin.y) to \(globalRect.maxY)")
            print("   Screen Y range: \(screenFrame.origin.y) to \(screenFrame.maxY)")
        }

        if globalRect.origin.x < screenFrame.origin.x || globalRect.maxX > screenFrame.maxX {
            print("⚠️ [COORD] WARNING: X coordinates may be out of bounds")
            print("   Rect X range: \(globalRect.origin.x) to \(globalRect.maxX)")
            print("   Screen X range: \(screenFrame.origin.x) to \(screenFrame.maxX)")
        }

        return globalRect
    }

    // MARK: - Helper Methods

    var isActive: Bool {
        return isSelectionActive
    }

    func forceCancel() {
        if isSelectionActive {
            dismissOverlayWindows()
        }
    }
}

// MARK: - SelectionOverlayDelegate

extension ScreenSelectionManager: SelectionOverlayDelegate {
    func selectionCompleted(with rect: NSRect, on screen: NSScreen) {
        print("📸 [SELECTION_MGR] Selection completed on screen: \(screen.localizedName)")
        print("📏 [SELECTION_MGR] Selection rect (window coords): \(rect)")

        // Convert to global coordinates
        let globalRect = convertSelectionToGlobalCoordinates(rect, from: screen)
        print("🌍 [SELECTION_MGR] Selection rect (global coords): \(globalRect)")

        // Dismiss all overlays
        dismissOverlayWindows()

        // Notify delegate
        print("🔄 [SELECTION_MGR] Calling delegate.screenSelectionCompleted - delegate: \(delegate != nil ? "✅ Available" : "❌ Nil")")
        delegate?.screenSelectionCompleted(rect: globalRect, screen: screen)
    }

    func selectionCancelled() {
        print("❌ Selection cancelled")
        dismissOverlayWindows()
        print("🔄 [DEBUG] Calling delegate.screenSelectionCancelled - delegate: \(delegate != nil ? "✅ Available" : "❌ Nil")")
        delegate?.screenSelectionCancelled()
    }
}