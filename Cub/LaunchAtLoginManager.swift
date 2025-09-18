//
//  LaunchAtLoginManager.swift
//  Cub
//
//  Created by sid on 17/09/25.
//

import Foundation
import ServiceManagement
import Cocoa

class LaunchAtLoginManager: ObservableObject {
    static let shared = LaunchAtLoginManager()

    private let launchAtLoginBundleIdentifier = "com.siddhartha.Cub.LaunchAtLoginHelper"

    private init() {}

    // MARK: - Public Interface

    var isEnabled: Bool {
        get {
            return SMLoginItemSetEnabled(launchAtLoginBundleIdentifier as CFString, false)
        }
        set {
            setLaunchAtLogin(enabled: newValue)
        }
    }

    func setLaunchAtLogin(enabled: Bool) {
        print("🚀 [LAUNCH] Setting launch at login: \(enabled)")

        let success = SMLoginItemSetEnabled(launchAtLoginBundleIdentifier as CFString, enabled)

        if success {
            print("✅ [LAUNCH] Successfully \(enabled ? "enabled" : "disabled") launch at login")

            // Update SettingsStore to keep UI in sync
            DispatchQueue.main.async {
                SettingsStore.shared.launchAtLogin = enabled
            }
        } else {
            print("❌ [LAUNCH] Failed to \(enabled ? "enable" : "disable") launch at login")

            // Show error to user
            DispatchQueue.main.async {
                self.showLaunchAtLoginError(enabled: enabled)
            }
        }
    }

    func checkCurrentStatus() -> Bool {
        // Check if our helper app is in the login items
        let success = SMLoginItemSetEnabled(launchAtLoginBundleIdentifier as CFString, false)
        print("🔍 [LAUNCH] Current launch at login status: \(success)")
        return success
    }

    // MARK: - Helper Methods

    private func showLaunchAtLoginError(enabled: Bool) {
        let alert = NSAlert()
        alert.messageText = "Launch at Login Error"
        alert.informativeText = enabled
            ? "Failed to enable launch at login. Please check System Preferences > Users & Groups > Login Items."
            : "Failed to disable launch at login. Please check System Preferences > Users & Groups > Login Items."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Open System Preferences")

        let response = alert.runModal()

        if response == .alertSecondButtonReturn {
            openSystemPreferences()
        }
    }

    private func openSystemPreferences() {
        let url = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension")!
        NSWorkspace.shared.open(url)
    }

    // MARK: - Alternative Implementation for Modern macOS

    /// For macOS 13+ using the modern Login Items API
    @available(macOS 13.0, *)
    func setLaunchAtLoginModern(enabled: Bool) {
        print("🚀 [LAUNCH] Using modern launch at login API: \(enabled)")

        do {
            if enabled {
                if #available(macOS 13.0, *) {
                    try SMAppService.mainApp.register()
                    print("✅ [LAUNCH] Successfully registered with SMAppService")
                }
            } else {
                if #available(macOS 13.0, *) {
                    try SMAppService.mainApp.unregister()
                    print("✅ [LAUNCH] Successfully unregistered from SMAppService")
                }
            }

            // Update SettingsStore
            DispatchQueue.main.async {
                SettingsStore.shared.launchAtLogin = enabled
            }

        } catch {
            print("❌ [LAUNCH] Modern API failed: \(error)")
            // Fallback to legacy method
            setLaunchAtLogin(enabled: enabled)
        }
    }

    @available(macOS 13.0, *)
    func checkModernStatus() -> Bool {
        let status = SMAppService.mainApp.status
        print("🔍 [LAUNCH] Modern API status: \(status)")

        switch status {
        case .enabled:
            return true
        case .requiresApproval:
            print("⚠️ [LAUNCH] Launch at login requires user approval")
            return false
        case .notRegistered:
            return false
        case .notFound:
            print("❌ [LAUNCH] App service not found")
            return false
        @unknown default:
            print("❓ [LAUNCH] Unknown status: \(status)")
            return false
        }
    }

    // MARK: - Public API with Version Detection

    func updateLaunchAtLogin(enabled: Bool) {
        if #available(macOS 13.0, *) {
            setLaunchAtLoginModern(enabled: enabled)
        } else {
            setLaunchAtLogin(enabled: enabled)
        }
    }

    func getCurrentStatus() -> Bool {
        if #available(macOS 13.0, *) {
            return checkModernStatus()
        } else {
            return checkCurrentStatus()
        }
    }
}

// MARK: - Extension for SettingsStore Integration

extension SettingsStore {
    func syncLaunchAtLoginWithSystem() {
        let currentStatus = LaunchAtLoginManager.shared.getCurrentStatus()
        if launchAtLogin != currentStatus {
            print("🔄 [SYNC] Syncing launch at login: \(currentStatus)")
            launchAtLogin = currentStatus
        }
    }
}
