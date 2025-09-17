//
//  PermissionManager.swift
//  Cub
//
//  Created by sid on 15/09/25.
//

import Cocoa
@preconcurrency import ScreenCaptureKit
import SwiftUI
import UserNotifications

enum PermissionStatus {
    case notDetermined
    case granted
    case denied
    case unknown
}

class PermissionManager: ObservableObject {
    @Published var screenRecordingStatus: PermissionStatus = .notDetermined
    @Published var hasRequestedPermission: Bool = false

    private var permissionCheckTimer: Timer?

    init() {
        checkScreenRecordingPermission()
        startPeriodicPermissionCheck()
        requestNotificationPermission()
    }

    deinit {
        permissionCheckTimer?.invalidate()
    }

    // MARK: - Permission Status Checking

    func checkScreenRecordingPermission() {
        let previousStatus = screenRecordingStatus

        if #available(macOS 14.0, *) {
            // Use ScreenCaptureKit for macOS 14+
            checkScreenRecordingPermissionModern()
        } else {
            // Fallback for older macOS versions
            checkScreenRecordingPermissionLegacy()
        }

        // If status changed, notify observers
        if previousStatus != screenRecordingStatus {
            DispatchQueue.main.async {
                self.objectWillChange.send()
            }
        }
    }

    @available(macOS 14.0, *)
    private func checkScreenRecordingPermissionModern() {
        Task { @MainActor in
            do {
                let canRecord = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                self.screenRecordingStatus = canRecord.displays.isEmpty ? .denied : .granted
            } catch {
                self.screenRecordingStatus = .denied
            }
        }
    }

    private func checkScreenRecordingPermissionLegacy() {
        // For older macOS versions, use CGWindowListCopyWindowInfo
        let windowList = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID)
        let windowArray = windowList as? [[String: Any]] ?? []

        // If we can get window information, we likely have permission
        // This is not foolproof but works for basic detection
        DispatchQueue.main.async {
            self.screenRecordingStatus = windowArray.isEmpty ? .denied : .granted
        }
    }

    // MARK: - Permission Request

    func requestScreenRecordingPermission() {
        hasRequestedPermission = true

        // On macOS, we can't programmatically request screen recording permission
        // We need to guide the user to System Preferences
        showPermissionAlert()
    }

    // MARK: - User Interface

    private func showPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "Screen Recording Permission Required"
        alert.informativeText = """
        Cub needs screen recording permission to capture screenshots for your visual clipboard.

        To grant permission:
        1. Click 'Open System Preferences' below
        2. Navigate to Privacy & Security → Screen Recording
        3. Check the box next to 'Cub'
        4. Restart Cub if needed
        """
        alert.alertStyle = .informational

        alert.addButton(withTitle: "Open System Preferences")
        alert.addButton(withTitle: "Try Again")
        alert.addButton(withTitle: "Quit")

        let response = alert.runModal()

        switch response {
        case .alertFirstButtonReturn:
            openSystemPreferences()
        case .alertSecondButtonReturn:
            checkScreenRecordingPermission()
        case .alertThirdButtonReturn:
            NSApplication.shared.terminate(nil)
        default:
            break
        }
    }

    private func openSystemPreferences() {
        let url: URL

        if #available(macOS 13.0, *) {
            // macOS 13+ uses the new System Settings app
            url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!
        } else {
            // Older macOS versions use System Preferences
            url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!
        }

        NSWorkspace.shared.open(url)
    }

    // MARK: - Periodic Checking

    private func startPeriodicPermissionCheck() {
        // Check permission status every 2 seconds to detect changes
        permissionCheckTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            self.checkScreenRecordingPermission()
        }
    }

    // MARK: - Helper Methods

    var isPermissionGranted: Bool {
        return screenRecordingStatus == .granted
    }

    var permissionStatusDescription: String {
        switch screenRecordingStatus {
        case .notDetermined:
            return "Not Determined"
        case .granted:
            return "Granted"
        case .denied:
            return "Denied"
        case .unknown:
            return "Unknown"
        }
    }

    var permissionStatusIcon: String {
        switch screenRecordingStatus {
        case .granted:
            return "checkmark.circle.fill"
        case .denied:
            return "xmark.circle.fill"
        case .notDetermined, .unknown:
            return "questionmark.circle.fill"
        }
    }

    func handleAppLaunch() {
        checkScreenRecordingPermission()

        // If permission is denied and we haven't requested it yet, show alert
        if screenRecordingStatus == .denied && !hasRequestedPermission {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.requestScreenRecordingPermission()
            }
        }
    }

    // MARK: - Test Permission (for debugging)

    func testScreenCapture() -> Bool {
        guard isPermissionGranted else { return false }

        // For modern macOS, we rely on the permission check itself
        // CGWindowListCreateImage is deprecated, so we just return the permission status
        return true
    }

    // MARK: - Notification Permissions

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                if granted {
                    print("✅ Notification permission granted")
                } else {
                    print("❌ Notification permission denied: \(error?.localizedDescription ?? "Unknown error")")
                }
            }
        }
    }
}
