//
//  HotkeyManager.swift
//  Cub
//
//  Created by sid on 15/09/25.
//

import Cocoa
import Carbon
import SwiftUI
import UserNotifications

enum HotkeyError: Error, LocalizedError {
    case registrationFailed
    case alreadyRegistered
    case accessibilityPermissionRequired
    case systemConflict
    case unknownError(OSStatus)

    var errorDescription: String? {
        switch self {
        case .registrationFailed:
            return "Failed to register global hotkey"
        case .alreadyRegistered:
            return "Hotkey is already registered by another application"
        case .accessibilityPermissionRequired:
            return "Accessibility permission is required for global hotkeys"
        case .systemConflict:
            return "Hotkey conflicts with system shortcuts"
        case .unknownError(let status):
            return "Unknown error occurred (Code: \(status))"
        }
    }
}

enum HotkeyStatus {
    case notRegistered
    case registered
    case failed(HotkeyError)
    case permissionRequired
}

class HotkeyManager: ObservableObject {
    @Published var hotkeyStatus: HotkeyStatus = .notRegistered
    @Published var currentHotkey: String = "⌘E"

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private let hotkeyID: EventHotKeyID = EventHotKeyID(signature: 0x43756248, id: 1) // 'CubH' as OSType

    private weak var permissionManager: PermissionManager?
    private var screenSelectionManager: ScreenSelectionManager!
    private var screenshotCapture: ScreenshotCapture!
    private weak var clipboardWindow: ClipboardWindow?

    private let kVK_ANSI_E: UInt32 = 0x0E
    private let commandKeyModifier: UInt32 = UInt32(cmdKey)

    init() {
        setupEventHandler()
        setupScreenSelectionManager()
        setupScreenshotCapture()
    }

    private func setupScreenSelectionManager() {
        screenSelectionManager = ScreenSelectionManager()
        // Note: delegate will be set after permission manager is configured
    }

    private func setupScreenshotCapture() {
        screenshotCapture = ScreenshotCapture()
        screenshotCapture.delegate = self
    }

    deinit {
        unregisterHotkey()
        removeEventHandler()
    }

    // MARK: - Public Methods

    func setPermissionManager(_ manager: PermissionManager) {
        self.permissionManager = manager
        screenSelectionManager.setPermissionManager(manager)
        screenshotCapture.setPermissionManager(manager)

        // Set delegate after all dependencies are configured
        screenSelectionManager.delegate = self
        print("🔗 ScreenSelectionManager delegate configured")
    }

    func setClipboardWindow(_ window: ClipboardWindow) {
        self.clipboardWindow = window
        screenshotCapture.setClipboardWindow(window)
    }

    func registerHotkey() {
        print("🔑 [HOTKEY] Starting hotkey registration process...")

        // First check if we need accessibility permissions
        print("🔑 [HOTKEY] Checking accessibility permissions...")
        if !checkAccessibilityPermissions() {
            print("❌ [HOTKEY] Accessibility permissions not granted")
            hotkeyStatus = .permissionRequired
            return
        }
        print("✅ [HOTKEY] Accessibility permissions granted")

        // Unregister existing hotkey if any
        print("🔑 [HOTKEY] Unregistering any existing hotkey...")
        unregisterHotkey()

        // Register Command+E
        print("🔑 [HOTKEY] Attempting to register Command+E hotkey...")
        print("🔑 [HOTKEY] Key code: \(kVK_ANSI_E), Modifier: \(commandKeyModifier)")

        let status = RegisterEventHotKey(
            kVK_ANSI_E,
            commandKeyModifier,
            hotkeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        print("🔑 [HOTKEY] RegisterEventHotKey returned status: \(status)")

        switch status {
        case noErr:
            hotkeyStatus = .registered
            print("✅ [HOTKEY] Global hotkey ⌘E registered successfully")
            print("🔑 [HOTKEY] HotKeyRef: \(hotKeyRef != nil ? "✅ Valid" : "❌ Nil")")
        case OSStatus(eventAlreadyPostedErr):
            hotkeyStatus = .failed(.alreadyRegistered)
            print("❌ [HOTKEY] Hotkey ⌘E is already registered by another application")
        case OSStatus(eventInternalErr):
            hotkeyStatus = .failed(.systemConflict)
            print("❌ [HOTKEY] Hotkey ⌘E conflicts with system shortcuts")
        default:
            hotkeyStatus = .failed(.unknownError(status))
            print("❌ [HOTKEY] Failed to register hotkey ⌘E with status: \(status)")
        }

        print("🔑 [HOTKEY] Final hotkey status: \(hotkeyStatusDescription)")
    }

    func unregisterHotkey() {
        if let hotKeyRef = hotKeyRef {
            let status = UnregisterEventHotKey(hotKeyRef)
            if status == noErr {
                print("🗑️ Global hotkey ⌘E unregistered successfully")
            } else {
                print("⚠️ Failed to unregister hotkey with status: \(status)")
            }
            self.hotKeyRef = nil
        }
        hotkeyStatus = .notRegistered
    }

    func testHotkey() {
        // Simulate hotkey press for testing
        handleHotkeyPressed()
    }

    // MARK: - Private Methods

    private func setupEventHandler() {
        print("🎛️ [HOTKEY] Setting up event handler...")
        let eventTypes = [EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: OSType(kEventHotKeyPressed))]

        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { (nextHandler, event, userData) -> OSStatus in
                print("🎯 [HOTKEY] Event handler callback triggered!")
                return HotkeyManager.eventHandlerCallback(nextHandler: nextHandler, event: event, userData: userData)
            },
            1,
            eventTypes,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )

        if status != noErr {
            print("❌ [HOTKEY] Failed to install event handler with status: \(status)")
        } else {
            print("✅ [HOTKEY] Event handler installed successfully")
        }
    }

    private func removeEventHandler() {
        if let eventHandler = eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
    }

    private static func eventHandlerCallback(nextHandler: EventHandlerCallRef?, event: EventRef?, userData: UnsafeMutableRawPointer?) -> OSStatus {
        guard let userData = userData else { return OSStatus(eventNotHandledErr) }

        let hotkeyManager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()

        var hotkeyID = EventHotKeyID()
        let status = GetEventParameter(
            event,
            OSType(kEventParamDirectObject),
            OSType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotkeyID
        )

        if status == noErr && hotkeyID.id == hotkeyManager.hotkeyID.id {
            DispatchQueue.main.async {
                hotkeyManager.handleHotkeyPressed()
            }
            return noErr
        }

        return OSStatus(eventNotHandledErr)
    }

    private func handleHotkeyPressed() {
        print("🔥 [HOTKEY] Global hotkey ⌘E triggered!")
        print("🔍 [HOTKEY] ClipboardWindow availability: \(clipboardWindow != nil ? "✅ Available" : "❌ Nil")")

        // Immediately show selection detected in clipboard window
        print("🔄 [HOTKEY] Calling clipboardWindow.showSelectionDetected()...")
        clipboardWindow?.showSelectionDetected()
        print("✅ [HOTKEY] Called clipboardWindow.showSelectionDetected()")

        // Check if we have screen recording permissions
        guard let permissionManager = permissionManager else {
            showErrorAlert("Permission manager not available")
            return
        }

        if !permissionManager.isPermissionGranted {
            showPermissionRequiredAlert()
            return
        }

        // Trigger the capture function
        triggerScreenCapture()
    }

    private func triggerScreenCapture() {
        print("📸 Screen capture triggered via hotkey!")
        print("🔍 [DEBUG] ScreenSelectionManager delegate: \(screenSelectionManager.delegate != nil ? "✅ Set" : "❌ Nil")")

        // Start screen selection overlay
        screenSelectionManager.startScreenSelection()
    }

    private func showCaptureTriggeredNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Cub"
        content.body = "Screen capture triggered (⌘E)"
        content.sound = UNNotificationSound.default

        let request = UNNotificationRequest(identifier: "capture-triggered", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    private func showPermissionRequiredAlert() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Screen Recording Permission Required"
            alert.informativeText = "The hotkey ⌘E was pressed, but Cub needs screen recording permission to capture screenshots. Please grant permission first."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Open System Preferences")
            alert.addButton(withTitle: "OK")

            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                self.permissionManager?.requestScreenRecordingPermission()
            }
        }
    }

    private func showErrorAlert(_ message: String) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Hotkey Error"
            alert.informativeText = message
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }

    private func checkAccessibilityPermissions() -> Bool {
        let trusted = AXIsProcessTrusted()
        if !trusted {
            showAccessibilityPermissionAlert()
        }
        return trusted
    }

    private func showAccessibilityPermissionAlert() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Accessibility Permission Required"
            alert.informativeText = """
            Cub needs accessibility permission to register global hotkeys.

            To grant permission:
            1. Click 'Open System Preferences' below
            2. Navigate to Privacy & Security → Accessibility
            3. Check the box next to 'Cub'
            4. Restart Cub
            """
            alert.alertStyle = .informational
            alert.addButton(withTitle: "Open System Preferences")
            alert.addButton(withTitle: "Cancel")

            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                self.openAccessibilityPreferences()
            }
        }
    }

    private func openAccessibilityPreferences() {
        let url: URL

        if #available(macOS 13.0, *) {
            url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        } else {
            url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        }

        NSWorkspace.shared.open(url)
    }

    // MARK: - Helper Methods

    var hotkeyStatusDescription: String {
        switch hotkeyStatus {
        case .notRegistered:
            return "Not Registered"
        case .registered:
            return "Active"
        case .failed(let error):
            return "Failed: \(error.localizedDescription)"
        case .permissionRequired:
            return "Permission Required"
        }
    }

    var hotkeyStatusIcon: String {
        switch hotkeyStatus {
        case .registered:
            return "checkmark.circle.fill"
        case .failed(_), .permissionRequired:
            return "xmark.circle.fill"
        case .notRegistered:
            return "questionmark.circle.fill"
        }
    }

    var isHotkeyActive: Bool {
        if case .registered = hotkeyStatus {
            return true
        }
        return false
    }

    func handleAppLaunch() {
        // Delay registration slightly to ensure app is fully loaded
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.registerHotkey()
        }
    }

    func handleAppWillTerminate() {
        unregisterHotkey()
        screenSelectionManager?.forceCancel()
    }
}

// MARK: - ScreenSelectionDelegate

extension HotkeyManager: ScreenSelectionDelegate {
    func screenSelectionCompleted(rect: NSRect, screen: NSScreen) {
        print("🎯 [DELEGATE] Screen selection completed!")
        print("📏 [DELEGATE] Selection area: \(rect)")
        print("📺 [DELEGATE] Screen: \(screen.localizedName)")

        // Trigger actual screenshot capture
        screenshotCapture.captureScreenshot(rect: rect, from: screen)
    }

    func screenSelectionCancelled() {
        print("🚫 [DELEGATE] Screen selection was cancelled")

        // Restore clipboard window to original state
        print("🔄 [DELEGATE] Calling clipboardWindow.restoreOriginalState()...")
        clipboardWindow?.restoreOriginalState()
        print("✅ [DELEGATE] Clipboard window restored to original state")
    }

    private func showSelectionCompletedNotification(rect: NSRect, screen: NSScreen) {
        let content = UNMutableNotificationContent()
        content.title = "Cub - Selection Complete"
        content.body = "Selected area: \(Int(rect.width))×\(Int(rect.height)) on \(screen.localizedName)"
        content.sound = UNNotificationSound.default

        let request = UNNotificationRequest(identifier: "selection-complete", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}

// MARK: - ScreenshotCaptureDelegate

extension HotkeyManager: ScreenshotCaptureDelegate {
    func screenshotCaptureCompleted(_ capturedImage: CapturedImage) {
        print("🎉 [DELEGATE] Screenshot capture completed successfully!")
        print("📱 [DELEGATE] Image dimensions: \(capturedImage.displayDimensions)")
        print("📦 [DELEGATE] File size: \(formatFileSize(capturedImage.fileSize))")
        print("📅 [DELEGATE] Capture date: \(capturedImage.captureDate)")
        print("🔍 [DELEGATE] ClipboardWindow: \(clipboardWindow != nil ? "✅ Available" : "❌ Nil")")

        // Show success notification
        showCaptureSuccessNotification(capturedImage)

        // Display image in clipboard window
        print("🔄 [DELEGATE] Calling clipboardWindow.updateWithCapturedImage...")
        clipboardWindow?.updateWithCapturedImage(capturedImage)
        print("✅ [DELEGATE] Called clipboardWindow.updateWithCapturedImage")
    }

    func screenshotCaptureFailed(_ error: ScreenshotCaptureError) {
        print("❌ Screenshot capture failed: \(error.localizedDescription)")

        // Show error notification to user
        showCaptureErrorNotification(error)
    }

    private func showCaptureSuccessNotification(_ capturedImage: CapturedImage) {
        let content = UNMutableNotificationContent()
        content.title = "Cub - Screenshot Captured"
        content.body = "Successfully captured \(capturedImage.displayDimensions) image"
        content.sound = UNNotificationSound.default

        let request = UNNotificationRequest(identifier: "capture-success", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    private func showCaptureErrorNotification(_ error: ScreenshotCaptureError) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Screenshot Capture Failed"
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.addButton(withTitle: "Retry")

            let response = alert.runModal()
            if response == .alertSecondButtonReturn {
                // Retry the last capture if possible
                self.screenshotCapture.retryLastCapture()
            }
        }
    }

    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}