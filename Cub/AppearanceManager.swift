//
//  AppearanceManager.swift
//  Cub
//
//  Created by sid on 17/09/25.
//

import Foundation
import Cocoa

class AppearanceManager: ObservableObject {
    static let shared = AppearanceManager()

    private init() {
        setupSystemAppearanceObserver()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Public Interface

    func updateAppearance(mode: AppearanceMode) {
        print("🎨 [APPEARANCE] Setting appearance mode: \(mode.displayName)")

        DispatchQueue.main.async {
            switch mode {
            case .light:
                NSApp.appearance = NSAppearance(named: .aqua)
                print("☀️ [APPEARANCE] Set to Light mode")

            case .dark:
                NSApp.appearance = NSAppearance(named: .darkAqua)
                print("🌙 [APPEARANCE] Set to Dark mode")

            case .auto:
                NSApp.appearance = nil // Use system default
                print("🔄 [APPEARANCE] Set to Auto mode (system default)")
            }

            // Update SettingsStore to keep UI in sync
            SettingsStore.shared.appearanceModeEnum = mode

            // Notify other components of appearance change
            self.broadcastAppearanceChange()
        }
    }

    func getCurrentAppearance() -> AppearanceMode {
        let settingsMode = SettingsStore.shared.appearanceModeEnum
        print("🔍 [APPEARANCE] Current appearance mode: \(settingsMode.displayName)")
        return settingsMode
    }

    func isCurrentlyDarkMode() -> Bool {
        let effectiveAppearance = NSApp.effectiveAppearance
        let isDark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        print("🔍 [APPEARANCE] Currently dark mode: \(isDark)")
        return isDark
    }

    // MARK: - System Integration

    private func setupSystemAppearanceObserver() {
        // Listen for system appearance changes (when in auto mode)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(systemAppearanceDidChange),
            name: NSNotification.Name("NSEffectiveAppearanceDidChangeNotification"),
            object: NSApp
        )

        print("👁️ [APPEARANCE] System appearance observer set up")
    }

    @objc private func systemAppearanceDidChange() {
        let currentMode = getCurrentAppearance()

        // Only respond to system changes if we're in auto mode
        if currentMode == .auto {
            print("🔄 [APPEARANCE] System appearance changed while in auto mode")
            broadcastAppearanceChange()
        }
    }

    private func broadcastAppearanceChange() {
        // Notify clipboard window and other components
        NotificationCenter.default.post(
            name: .appearanceDidChange,
            object: nil,
            userInfo: [
                "mode": getCurrentAppearance(),
                "isDarkMode": isCurrentlyDarkMode()
            ]
        )

        print("📡 [APPEARANCE] Broadcasted appearance change notification")
    }

    // MARK: - Initialization Helper

    func initializeAppearance() {
        let storedMode = getCurrentAppearance()
        print("🚀 [APPEARANCE] Initializing with stored mode: \(storedMode.displayName)")

        // Apply the stored appearance mode
        updateAppearance(mode: storedMode)
    }

    // MARK: - Utility Methods

    func getSystemAppearanceName() -> String {
        let appearance = NSApp.effectiveAppearance

        if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
            return "Dark"
        } else {
            return "Light"
        }
    }

    func syncWithSystemPreferences() {
        // If the user changed system appearance while app was running,
        // and we're in auto mode, make sure we're in sync
        let currentMode = getCurrentAppearance()

        if currentMode == .auto {
            print("🔄 [APPEARANCE] Syncing with system preferences")
            updateAppearance(mode: .auto)
        }
    }
}

// MARK: - Extension for SettingsStore Integration

extension SettingsStore {
    func syncAppearanceWithSystem() {
        let currentMode = AppearanceManager.shared.getCurrentAppearance()

        // Initialize appearance on first launch or when settings change
        AppearanceManager.shared.updateAppearance(mode: currentMode)
    }
}

// MARK: - Notification Names

extension NSNotification.Name {
    static let appearanceDidChange = NSNotification.Name("AppearanceDidChange")
}
