//
//  PreferencesView.swift
//  Cub
//
//  Created by sid on 17/09/25.
//

import SwiftUI
import Cocoa

// MARK: - Preference Categories

enum PreferenceCategory: String, CaseIterable, Identifiable {
    case general = "general"
    case screenshots = "screenshots"
    case appearance = "appearance"
    case privacy = "privacy"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .general: return "General"
        case .screenshots: return "Screenshots"
        case .appearance: return "Appearance"
        case .privacy: return "Privacy & Permissions"
        }
    }

    var systemImage: String {
        switch self {
        case .general: return "gear"
        case .screenshots: return "camera"
        case .appearance: return "paintbrush"
        case .privacy: return "lock.shield"
        }
    }

    var description: String {
        switch self {
        case .general: return "Application behavior and clipboard settings"
        case .screenshots: return "Capture settings and hotkey configuration"
        case .appearance: return "Visual styling and animation preferences"
        case .privacy: return "System permissions and data sharing"
        }
    }
}

struct PreferencesView: View {
    @ObservedObject var preferencesManager = PreferencesManager.shared
    @EnvironmentObject var permissionManager: PermissionManager
    @EnvironmentObject var hotkeyManager: HotkeyManager
    @StateObject private var settingsStore = SettingsStore.shared

    @State private var selectedCategory: PreferenceCategory = .general
    @State private var showingDirectoryPicker = false

    private let availableColors: [Color] = [
        .red, .blue, .green, .orange, .purple
    ]

    private let colorNames = [
        "Red", "Blue", "Green", "Orange", "Purple"
    ]

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detailView
        }
        .frame(minWidth: 710, minHeight: 470)
        .onAppear {
            setupSettings()
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Preferences Window")
        .focusable()
        .onKeyPress(.tab) {
            return .handled
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        List(PreferenceCategory.allCases, id: \.self, selection: $selectedCategory) { category in
            NavigationLink(value: category) {
                Label(category.displayName, systemImage: category.systemImage)
                    .font(.system(size: 13, weight: .medium))
                    .dynamicTypeSize(.small...)
            }
            .accessibilityLabel(category.displayName)
            .accessibilityHint(category.description)
            .accessibilityAddTraits(selectedCategory == category ? [.isSelected] : [])
        }
        .navigationTitle("Preferences")
        .frame(minWidth: 215)
        .listStyle(.sidebar)
    }

    // MARK: - Detail View

    private var detailView: some View {
        Group {
            switch selectedCategory {
            case .general:
                generalView
            case .screenshots:
                screenshotsView
            case .appearance:
                appearanceView
            case .privacy:
                privacyView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(24)
        .navigationTitle(selectedCategory.displayName)
    }

    // MARK: - General View

    private var generalView: some View {
        ScrollView {
            VStack(spacing: 20) {
                PreferenceSection("Application Behavior", systemImage: "gear") {
                    PreferenceToggle(
                        "Launch at Login",
                        subtitle: "Start Cub automatically when you log in",
                        systemImage: "power",
                        isOn: $settingsStore.launchAtLogin
                    )
                    .onChange(of: settingsStore.launchAtLogin) {
                        LaunchAtLoginManager.shared.updateLaunchAtLogin(enabled: settingsStore.launchAtLogin)
                        print("🚀 [PREFS] Launch at login setting: \(settingsStore.launchAtLogin)")
                    }

                    PreferenceToggle(
                        "Show Menu Bar Icon",
                        subtitle: "Display Cub icon in the menu bar",
                        systemImage: "menubar.rectangle",
                        isOn: $settingsStore.showMenuBarIcon
                    )
                    .onChange(of: settingsStore.showMenuBarIcon) {
                        UserDefaults.standard.set(settingsStore.showMenuBarIcon, forKey: "ShowMenuBarIcon")
                        print("🎯 [PREFS] Menu bar icon setting: \(settingsStore.showMenuBarIcon)")
                    }

                    PreferenceToggle(
                        "Notifications",
                        subtitle: "Show system notifications for events",
                        systemImage: "bell",
                        isOn: $settingsStore.notificationsEnabled
                    )

                    PreferenceToggle(
                        "Sound Effects",
                        subtitle: "Play sounds for actions and alerts",
                        systemImage: "speaker.wave.2",
                        isOn: $settingsStore.soundEnabled
                    )
                }

                PreferenceSection("Clipboard Window", systemImage: "doc.on.clipboard") {
                    PreferencePicker(
                        "Visibility Mode",
                        subtitle: settingsStore.clipboardMode.description,
                        systemImage: "eye",
                        selection: $settingsStore.clipboardMode,
                        style: .segmented
                    )
                    .onChange(of: settingsStore.clipboardMode) {
                        UserDefaults.standard.set(settingsStore.clipboardMode.rawValue, forKey: "ClipboardVisibilityMode")
                        ClipboardWindowManager.shared.setVisibilityMode(settingsStore.clipboardMode)
                        print("📋 [PREFS] Clipboard visibility mode: \(settingsStore.clipboardMode.displayName)")
                    }

                    PreferenceToggle(
                        "Auto-dim After 1 Minute",
                        subtitle: "Reduce opacity when inactive",
                        systemImage: "moon",
                        isOn: $settingsStore.autoDimmingEnabled,
                        disabled: !settingsStore.clipboardMode.allowsAutoDimming
                    )
                    .onChange(of: settingsStore.autoDimmingEnabled) {
                        UserDefaults.standard.set(settingsStore.autoDimmingEnabled, forKey: "AutoDimmingEnabled")
                        ClipboardWindowManager.shared.setAutoDimmingEnabled(settingsStore.autoDimmingEnabled)
                        print("🌙 [PREFS] Auto-dimming enabled: \(settingsStore.autoDimmingEnabled)")
                    }

                    PreferenceToggle(
                        "Auto-hide After 3 Minutes",
                        subtitle: settingsStore.clipboardMode.allowsAutoHiding ? "Hide window when inactive" : "Only available in Show mode",
                        systemImage: "eye.slash",
                        isOn: $settingsStore.autoHideEnabled,
                        disabled: !settingsStore.clipboardMode.allowsAutoHiding
                    )
                    .onChange(of: settingsStore.autoHideEnabled) {
                        UserDefaults.standard.set(settingsStore.autoHideEnabled, forKey: "AutoHideEnabled")
                        ClipboardWindowManager.shared.setAutoHideEnabled(settingsStore.autoHideEnabled)
                        print("🙈 [PREFS] Auto-hide enabled: \(settingsStore.autoHideEnabled)")
                    }

                    PreferencePicker(
                        "Window Position",
                        subtitle: "Choose which screen edge to anchor the window",
                        systemImage: "rectangle.portrait.and.arrow.right",
                        selection: $settingsStore.windowPositionEnum,
                        style: .segmented
                    )
                    .onChange(of: settingsStore.windowPositionEnum) {
                        print("📍 [PREFS] Window position changed to: \(settingsStore.windowPositionEnum.displayName)")
                        // Update clipboard window position if it's currently visible
                        if ClipboardWindowManager.shared.getClipboardWindow() != nil {
                            NotificationCenter.default.post(name: NSNotification.Name("WindowPositionChanged"), object: nil)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Screenshots View

    private var screenshotsView: some View {
        ScrollView {
            VStack(spacing: 20) {
                PreferenceSection("Capture Settings", systemImage: "camera") {
                    // Directory section with enhanced UI
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 12) {
                            Image(systemName: "folder")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.secondary)
                                .frame(width: 16)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Save Location")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(.primary)

                                Text("Choose where screenshots are saved")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()
                        }

                        DirectoryStatusView(preferencesManager: preferencesManager)

                        HStack {
                            TextField("", text: .constant(preferencesManager.screenshotSaveDirectory.path))
                                .textFieldStyle(.roundedBorder)
                                .disabled(true)

                            PreferenceButton(
                                "Choose Folder...",
                                systemImage: "folder.badge.plus",
                                style: .secondary
                            ) {
                                preferencesManager.selectNewDirectory()
                            }
                        }

                        HStack {
                            PreferenceButton(
                                "Open in Finder",
                                systemImage: "finder",
                                style: .secondary
                            ) {
                                NSWorkspace.shared.open(preferencesManager.screenshotSaveDirectory)
                            }

                            PreferenceButton(
                                "Reset to Default",
                                systemImage: "arrow.clockwise",
                                style: .secondary
                            ) {
                                let defaultDir = PreferencesManager.getDefaultScreenshotDirectory()
                                preferencesManager.updateScreenshotDirectory(defaultDir)
                            }

                            Spacer()
                        }

                        PermissionHelpView(preferencesManager: preferencesManager)
                    }

                    PreferencePicker(
                        "File Format",
                        subtitle: formatDescription(for: settingsStore.screenshotFormatEnum),
                        systemImage: "doc",
                        selection: $settingsStore.screenshotFormatEnum,
                        style: .segmented
                    )
                    .onChange(of: settingsStore.screenshotFormatEnum) {
                        preferencesManager.updateScreenshotFormat(
                            PreferencesManager.ScreenshotFormat(rawValue: settingsStore.screenshotFormatEnum.rawValue) ?? .png
                        )
                        print("🖼️ [PREFS] Screenshot format: \(settingsStore.screenshotFormatEnum.displayName)")
                    }

                    PreferenceSlider(
                        "JPEG Quality",
                        subtitle: "Higher quality produces larger files",
                        systemImage: "slider.horizontal.3",
                        value: $settingsStore.screenshotQuality,
                        in: 0.1...1.0,
                        step: 0.1
                    )
                    .opacity(settingsStore.screenshotFormatEnum == .jpeg ? 1.0 : 0.5)
                    .disabled(settingsStore.screenshotFormatEnum != .jpeg)

                    PreferenceToggle(
                        "Include Timestamp in Filename",
                        subtitle: "Add date and time to screenshot names",
                        systemImage: "clock",
                        isOn: $settingsStore.includeTimestamp
                    )
                }

                PreferenceSection("Hotkeys", systemImage: "keyboard") {
                    HStack(spacing: 12) {
                        Image(systemName: hotkeyManager.hotkeyStatusIcon)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(hotkeyManager.isHotkeyActive ? .green : .red)
                            .frame(width: 16)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Global Screenshot Hotkey")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.primary)

                            Text("⌘E: \(hotkeyManager.isHotkeyActive ? "Active" : hotkeyManager.hotkeyStatusDescription)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if hotkeyManager.isHotkeyActive {
                            PreferenceButton(
                                "Test",
                                systemImage: "play",
                                style: .primary
                            ) {
                                hotkeyManager.testHotkey()
                            }
                        } else {
                            PreferenceButton(
                                "Re-register",
                                systemImage: "arrow.clockwise",
                                style: .primary
                            ) {
                                hotkeyManager.registerHotkey()
                            }
                        }
                    }

                    PreferenceToggle(
                        "Enable Global Hotkey",
                        subtitle: "Use ⌘E to trigger screenshots from anywhere",
                        systemImage: "globe",
                        isOn: $settingsStore.screenshotHotkeyEnabled
                    )
                }
            }
        }
    }

    // MARK: - Appearance View

    private var appearanceView: some View {
        ScrollView {
            VStack(spacing: 20) {
                PreferenceSection("Visual Styling", systemImage: "paintbrush") {
                    PreferencePicker(
                        "Appearance",
                        subtitle: "Choose the app's appearance theme",
                        systemImage: "circle.lefthalf.filled",
                        selection: $settingsStore.appearanceModeEnum,
                        style: .segmented
                    )
                    .onChange(of: settingsStore.appearanceModeEnum) {
                        AppearanceManager.shared.updateAppearance(mode: settingsStore.appearanceModeEnum)
                        print("🎨 [PREFS] Appearance mode changed to: \(settingsStore.appearanceModeEnum.displayName)")
                    }

                    PreferenceColorPicker(
                        "Border Color",
                        subtitle: "Choose the clipboard window border color",
                        systemImage: "paintpalette",
                        selectedIndex: $settingsStore.selectedBorderColor,
                        colors: availableColors,
                        colorNames: colorNames
                    )
                    .onChange(of: settingsStore.selectedBorderColor) {
                        UserDefaults.standard.set(settingsStore.selectedBorderColor, forKey: "SelectedBorderColor")
                        NotificationCenter.default.post(name: NSNotification.Name("BorderColorChanged"), object: nil)
                        print("🎨 [PREFS] Border color changed to: \(colorNames[settingsStore.selectedBorderColor])")
                    }

                    PreferenceSlider(
                        "Window Opacity",
                        subtitle: "Adjust the transparency of the clipboard window",
                        systemImage: "eye",
                        value: $settingsStore.windowOpacity,
                        in: 0.3...1.0,
                        step: 0.05
                    )
                }

                PreferenceSection("Animation & Motion", systemImage: "wand.and.stars") {
                    PreferencePicker(
                        "Animation Speed",
                        subtitle: "Control the speed of window animations",
                        systemImage: "speedometer",
                        selection: $settingsStore.animationSpeedEnum,
                        style: .segmented
                    )

                    PreferenceToggle(
                        "Reduce Motion",
                        subtitle: "Minimize animations for accessibility",
                        systemImage: "accessibility",
                        isOn: $settingsStore.reduceMotion
                    )
                }
            }
        }
    }

    // MARK: - Privacy View

    private var privacyView: some View {
        ScrollView {
            VStack(spacing: 20) {
                PreferenceSection("System Permissions", systemImage: "lock.shield") {
                    HStack(spacing: 12) {
                        Image(systemName: permissionManager.isPermissionGranted ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(permissionManager.isPermissionGranted ? .green : .red)
                            .frame(width: 16)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Screen Recording")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.primary)

                            Text(permissionManager.isPermissionGranted ? "Permission granted" : "Permission required for screenshots")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if !permissionManager.isPermissionGranted {
                            PreferenceButton(
                                "Grant Permission",
                                systemImage: "plus.circle",
                                style: .primary
                            ) {
                                permissionManager.requestScreenRecordingPermission()
                            }
                        }
                    }

                    HStack(spacing: 12) {
                        Image(systemName: hotkeyManager.isHotkeyActive ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(hotkeyManager.isHotkeyActive ? .green : .red)
                            .frame(width: 16)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Accessibility")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.primary)

                            Text(hotkeyManager.isHotkeyActive ? "Permission granted for global hotkeys" : "Permission required for hotkeys")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()
                    }
                }

                PreferenceSection("Data & Analytics", systemImage: "chart.bar") {
                    PreferenceToggle(
                        "Usage Analytics",
                        subtitle: "Share anonymous usage data to help improve Cub",
                        systemImage: "chart.line.uptrend.xyaxis",
                        isOn: $settingsStore.analyticsEnabled
                    )

                    PreferenceToggle(
                        "Crash Reporting",
                        subtitle: "Automatically send crash reports to help fix bugs",
                        systemImage: "exclamationmark.triangle",
                        isOn: $settingsStore.crashReportingEnabled
                    )

                    PreferenceToggle(
                        "Share Usage Data",
                        subtitle: "Help improve features by sharing how you use Cub",
                        systemImage: "square.and.arrow.up",
                        isOn: $settingsStore.shareUsageData
                    )
                }
            }
        }
    }

    // MARK: - Helper Methods

    private func setupSettings() {
        // Migrate from UserDefaults to @AppStorage
        settingsStore.migrateFromUserDefaults()

        // Update settings store with current values
        settingsStore.selectedBorderColor = UserDefaults.standard.integer(forKey: "SelectedBorderColor")

        // Sync launch at login status with system
        settingsStore.syncLaunchAtLoginWithSystem()

        print("📱 [PREFS] Settings setup completed")
    }

    private func formatDescription(for format: ScreenshotFormat) -> String {
        switch format {
        case .png:
            return "Best quality, larger file size. Supports transparency."
        case .jpeg:
            return "Smaller file size, good quality. No transparency support."
        case .tiff:
            return "Lossless quality, largest file size. Professional format."
        }
    }
}

// MARK: - Directory Status Components

struct DirectoryStatusView: View {
    @ObservedObject var preferencesManager: PreferencesManager
    @State private var directoryStatus: PreferencesManager.DirectoryAccessStatus = .accessible

    var body: some View {
        HStack {
            statusIcon
            statusText
            Spacer()
            if case .needsUserSelection = directoryStatus {
                Button("Fix") {
                    preferencesManager.selectNewDirectory()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.vertical, 4)
        .onAppear {
            updateStatus()
        }
        .onChange(of: preferencesManager.screenshotSaveDirectory) {
            updateStatus()
        }
    }

    private var statusIcon: some View {
        Group {
            switch directoryStatus {
            case .accessible:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            case .needsUserSelection:
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
            case .error:
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
            }
        }
    }

    private var statusText: some View {
        Group {
            switch directoryStatus {
            case .accessible:
                Text("Folder accessible")
                    .foregroundColor(.green)
            case .needsUserSelection:
                Text("Folder permission needed")
                    .foregroundColor(.orange)
            case .error(let message):
                Text("Error: \(message)")
                    .foregroundColor(.red)
            }
        }
        .font(.caption)
    }

    private func updateStatus() {
        directoryStatus = preferencesManager.getDirectoryAccessStatus()
    }
}

struct PermissionHelpView: View {
    @ObservedObject var preferencesManager: PreferencesManager
    @State private var directoryStatus: PreferencesManager.DirectoryAccessStatus = .accessible

    var body: some View {
        Group {
            switch directoryStatus {
            case .accessible:
                EmptyView()
            case .needsUserSelection:
                VStack(alignment: .leading, spacing: 4) {
                    Text("Permission Required")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.orange)

                    Text("This folder requires permission to save screenshots. Click 'Choose Folder...' to grant access.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 4)
            case .error(let message):
                VStack(alignment: .leading, spacing: 4) {
                    Text("Access Error")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.red)

                    Text(message)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Click 'Reset to Default' to use a safe location.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 4)
            }
        }
        .onAppear {
            updateStatus()
        }
        .onChange(of: preferencesManager.screenshotSaveDirectory) {
            updateStatus()
        }
    }

    private func updateStatus() {
        directoryStatus = preferencesManager.getDirectoryAccessStatus()
    }
}

#Preview {
    PreferencesView()
        .environmentObject(PermissionManager())
        .environmentObject(HotkeyManager())
}
