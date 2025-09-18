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
            return SMAppService.mainApp.status == .enabled
        }
        set {
            setLaunchAtLogin(enabled: newValue)
        }
    }

    func setLaunchAtLogin(enabled: Bool) {
        print("🚀 [LAUNCH] Setting launch at login: \(enabled)")
        setLaunchAtLoginModern(enabled: enabled)
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

    /// Modern Login Items API implementation
    private func setLaunchAtLoginModern(enabled: Bool) {
        print("🚀 [LAUNCH] Using modern launch at login API: \(enabled)")

        do {
            if enabled {
                try SMAppService.mainApp.register()
                print("✅ [LAUNCH] Successfully registered with SMAppService")
            } else {
                try SMAppService.mainApp.unregister()
                print("✅ [LAUNCH] Successfully unregistered from SMAppService")
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

    // MARK: - Public API

    func updateLaunchAtLogin(enabled: Bool) {
        setLaunchAtLogin(enabled: enabled)
    }

    func getCurrentStatus() -> Bool {
        return isEnabled
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
