//
//  SettingsStore.swift
//  Cub
//
//  Created by sid on 17/09/25.
//

import SwiftUI
import Foundation

class SettingsStore: ObservableObject {
    static let shared = SettingsStore()

    // MARK: - General Settings
    @AppStorage("launchAtLogin") var launchAtLogin: Bool = false
    @AppStorage("showMenuBarIcon") var showMenuBarIcon: Bool = true
    @AppStorage("notificationsEnabled") var notificationsEnabled: Bool = true
    @AppStorage("soundEnabled") var soundEnabled: Bool = false

    // MARK: - Clipboard Window Settings
    @AppStorage("clipboardVisibilityMode") var clipboardVisibilityMode: String = ClipboardVisibilityMode.show.rawValue
    @AppStorage("autoDimmingEnabled") var autoDimmingEnabled: Bool = true
    @AppStorage("autoHideEnabled") var autoHideEnabled: Bool = true
    @AppStorage("windowPosition") var windowPosition: String = WindowPosition.right.rawValue
    @AppStorage("clipboardWindowState") var clipboardWindowState: String = "hidden"

    // MARK: - Screenshot Settings
    @AppStorage("screenshotFormat") var screenshotFormat: String = "png"
    @AppStorage("screenshotQuality") var screenshotQuality: Double = 0.8
    @AppStorage("customFilenamePattern") var customFilenamePattern: String = "Screenshot %Y-%m-%d at %H.%M.%S"
    @AppStorage("includeTimestamp") var includeTimestamp: Bool = true
    @AppStorage("selectedBorderColor") var selectedBorderColor: Int = 0

    // MARK: - Hotkey Settings
    @AppStorage("screenshotHotkeyEnabled") var screenshotHotkeyEnabled: Bool = true
    @AppStorage("customHotkeyModifiers") var customHotkeyModifiers: Int = 256 // Command key
    @AppStorage("customHotkeyKey") var customHotkeyKey: String = "e"

    // MARK: - Appearance Settings
    @AppStorage("appearanceMode") var appearanceMode: String = AppearanceMode.auto.rawValue
    @AppStorage("windowOpacity") var windowOpacity: Double = 0.95
    @AppStorage("animationSpeed") var animationSpeed: String = AnimationSpeed.normal.rawValue
    @AppStorage("reduceMotion") var reduceMotion: Bool = false

    // MARK: - Privacy Settings
    @AppStorage("analyticsEnabled") var analyticsEnabled: Bool = false
    @AppStorage("crashReportingEnabled") var crashReportingEnabled: Bool = true
    @AppStorage("shareUsageData") var shareUsageData: Bool = false

    private init() {}

    // MARK: - Computed Properties for Type Safety

    var clipboardMode: ClipboardVisibilityMode {
        get { ClipboardVisibilityMode(rawValue: clipboardVisibilityMode) ?? .show }
        set { clipboardVisibilityMode = newValue.rawValue }
    }

    var screenshotFormatEnum: ScreenshotFormat {
        get { ScreenshotFormat(rawValue: screenshotFormat) ?? .png }
        set { screenshotFormat = newValue.rawValue }
    }

    var windowPositionEnum: WindowPosition {
        get { WindowPosition(rawValue: windowPosition) ?? .right }
        set { windowPosition = newValue.rawValue }
    }

    var appearanceModeEnum: AppearanceMode {
        get { AppearanceMode(rawValue: appearanceMode) ?? .auto }
        set { appearanceMode = newValue.rawValue }
    }

    var animationSpeedEnum: AnimationSpeed {
        get { AnimationSpeed(rawValue: animationSpeed) ?? .normal }
        set { animationSpeed = newValue.rawValue }
    }

    // MARK: - Migration from UserDefaults

    func migrateFromUserDefaults() {
        let userDefaults = UserDefaults.standard

        // Migrate existing settings if they exist
        if userDefaults.object(forKey: "ShowMenuBarIcon") != nil {
            showMenuBarIcon = userDefaults.bool(forKey: "ShowMenuBarIcon")
        }

        if let mode = userDefaults.string(forKey: "ClipboardVisibilityMode") {
            clipboardVisibilityMode = mode
        }

        if userDefaults.object(forKey: "AutoDimmingEnabled") != nil {
            autoDimmingEnabled = userDefaults.bool(forKey: "AutoDimmingEnabled")
        }

        if userDefaults.object(forKey: "AutoHideEnabled") != nil {
            autoHideEnabled = userDefaults.bool(forKey: "AutoHideEnabled")
        }

        if userDefaults.object(forKey: "SelectedBorderColor") != nil {
            selectedBorderColor = userDefaults.integer(forKey: "SelectedBorderColor")
        }

        if let format = userDefaults.string(forKey: "screenshotFormat") {
            screenshotFormat = format
        }

        print("📱 [SETTINGS] Migration from UserDefaults completed")
    }

    // MARK: - Helper Methods

    func resetToDefaults() {
        launchAtLogin = false
        showMenuBarIcon = true
        notificationsEnabled = true
        soundEnabled = false
        clipboardVisibilityMode = ClipboardVisibilityMode.show.rawValue
        autoDimmingEnabled = true
        autoHideEnabled = true
        windowPosition = WindowPosition.right.rawValue
        screenshotFormat = "png"
        screenshotQuality = 0.8
        customFilenamePattern = "Screenshot %Y-%m-%d at %H.%M.%S"
        includeTimestamp = true
        selectedBorderColor = 0
        appearanceMode = AppearanceMode.auto.rawValue
        windowOpacity = 0.95
        animationSpeed = AnimationSpeed.normal.rawValue
        reduceMotion = false
        analyticsEnabled = false
        crashReportingEnabled = true
        shareUsageData = false

        print("📱 [SETTINGS] Reset to default values")
    }
}

// MARK: - Supporting Enums

enum WindowPosition: String, CaseIterable, DisplayNameProvider {
    case left = "left"
    case right = "right"

    var displayName: String {
        switch self {
        case .left: return "Left Edge"
        case .right: return "Right Edge"
        }
    }
}

enum ScreenshotFormat: String, CaseIterable, DisplayNameProvider {
    case png = "png"
    case jpeg = "jpg"
    case tiff = "tiff"

    var displayName: String {
        switch self {
        case .png: return "PNG (Lossless)"
        case .jpeg: return "JPEG (Compressed)"
        case .tiff: return "TIFF (Lossless)"
        }
    }
}

enum AppearanceMode: String, CaseIterable, DisplayNameProvider {
    case light = "light"
    case dark = "dark"
    case auto = "auto"

    var displayName: String {
        switch self {
        case .light: return "Light"
        case .dark: return "Dark"
        case .auto: return "Auto"
        }
    }
}

enum AnimationSpeed: String, CaseIterable, DisplayNameProvider {
    case slow = "slow"
    case normal = "normal"
    case fast = "fast"

    var displayName: String {
        switch self {
        case .slow: return "Slow"
        case .normal: return "Normal"
        case .fast: return "Fast"
        }
    }

    var duration: Double {
        switch self {
        case .slow: return 0.6
        case .normal: return 0.3
        case .fast: return 0.15
        }
    }
}
