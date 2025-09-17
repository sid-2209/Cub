//
//  PreferencesView.swift
//  Cub
//
//  Created by sid on 17/09/25.
//

import SwiftUI
import Cocoa

struct PreferencesView: View {
    @ObservedObject var preferencesManager = PreferencesManager.shared
    @EnvironmentObject var permissionManager: PermissionManager
    @EnvironmentObject var hotkeyManager: HotkeyManager

    @State private var showingDirectoryPicker = false
    @State private var selectedColorIndex = UserDefaults.standard.integer(forKey: "SelectedBorderColor")
    @State private var showMenuBarIcon = UserDefaults.standard.bool(forKey: "ShowMenuBarIcon")
    @State private var clipboardVisibilityMode: ClipboardVisibilityMode = .show
    @State private var autoDimmingEnabled = UserDefaults.standard.bool(forKey: "AutoDimmingEnabled")
    @State private var autoHideEnabled = UserDefaults.standard.bool(forKey: "AutoHideEnabled")

    private let availableColors: [Color] = [
        .red, .blue, .green, .orange, .purple
    ]

    private let colorNames = [
        "Red", "Blue", "Green", "Orange", "Purple"
    ]

    var body: some View {
        TabView {
            generalTab
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            screenshotsTab
                .tabItem {
                    Label("Screenshots", systemImage: "camera")
                }

            appearanceTab
                .tabItem {
                    Label("Appearance", systemImage: "paintbrush")
                }
        }
        .frame(width: 500, height: 400)
        .onAppear {
            loadSettings()
        }
    }

    private var generalTab: some View {
        Form {
            Section {
                GroupBox("Application") {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("Show menu bar icon", isOn: $showMenuBarIcon)
                            .help("Show or hide the Cub icon in the menu bar")
                            .onChange(of: showMenuBarIcon) {
                                UserDefaults.standard.set(showMenuBarIcon, forKey: "ShowMenuBarIcon")
                                print("🎯 [PREFS] Menu bar icon setting: \(showMenuBarIcon)")
                            }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Clipboard Window Mode")
                                .font(.headline)

                            Picker("Clipboard Mode", selection: $clipboardVisibilityMode) {
                                ForEach(ClipboardVisibilityMode.allCases, id: \.self) { mode in
                                    Text(mode.displayName).tag(mode)
                                }
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            .onChange(of: clipboardVisibilityMode) {
                                UserDefaults.standard.set(clipboardVisibilityMode.rawValue, forKey: "ClipboardVisibilityMode")
                                ClipboardWindowManager.shared.setVisibilityMode(clipboardVisibilityMode)
                                print("📋 [PREFS] Clipboard visibility mode: \(clipboardVisibilityMode.displayName)")
                            }

                            Text(clipboardVisibilityMode.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Divider()

                        Toggle("Auto-dim clipboard after 1 minute", isOn: $autoDimmingEnabled)
                            .help("Automatically reduce clipboard window opacity after 1 minute of inactivity")
                            .disabled(!clipboardVisibilityMode.allowsAutoDimming)
                            .onChange(of: autoDimmingEnabled) {
                                UserDefaults.standard.set(autoDimmingEnabled, forKey: "AutoDimmingEnabled")
                                ClipboardWindowManager.shared.setAutoDimmingEnabled(autoDimmingEnabled)
                                print("🌙 [PREFS] Auto-dimming enabled: \(autoDimmingEnabled)")
                            }

                        Toggle("Auto-hide clipboard after 3 minutes", isOn: $autoHideEnabled)
                            .help("Automatically hide clipboard window after 3 minutes of inactivity")
                            .disabled(!clipboardVisibilityMode.allowsAutoHiding)
                            .onChange(of: autoHideEnabled) {
                                UserDefaults.standard.set(autoHideEnabled, forKey: "AutoHideEnabled")
                                ClipboardWindowManager.shared.setAutoHideEnabled(autoHideEnabled)
                                print("🙈 [PREFS] Auto-hide enabled: \(autoHideEnabled)")
                            }

                        if !clipboardVisibilityMode.allowsAutoHiding {
                            Text("Auto-hide is only available in 'Show' mode")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                }

                GroupBox("Permissions") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: permissionManager.isPermissionGranted ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(permissionManager.isPermissionGranted ? .green : .red)
                            Text("Screen Recording: \(permissionManager.isPermissionGranted ? "Enabled" : "Disabled")")
                        }

                        if !permissionManager.isPermissionGranted {
                            Button("Grant Screen Recording Permission") {
                                permissionManager.requestScreenRecordingPermission()
                            }
                        }
                    }
                    .padding()
                }

                GroupBox("Hotkeys") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: hotkeyManager.hotkeyStatusIcon)
                                .foregroundColor(hotkeyManager.isHotkeyActive ? .green : .red)
                            Text("Global Hotkey (⌘E): \(hotkeyManager.isHotkeyActive ? "Active" : hotkeyManager.hotkeyStatusDescription)")
                        }

                        HStack {
                            Button("Test Hotkey") {
                                hotkeyManager.testHotkey()
                            }
                            .disabled(!hotkeyManager.isHotkeyActive)

                            if !hotkeyManager.isHotkeyActive {
                                Button("Re-register Hotkey") {
                                    hotkeyManager.registerHotkey()
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .padding()
    }

    private var screenshotsTab: some View {
        Form {
            Section {
                GroupBox("Save Location") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Screenshots saved to:")
                                .foregroundColor(.secondary)
                            Spacer()
                        }

                        // Directory access status indicator
                        DirectoryStatusView(preferencesManager: preferencesManager)

                        HStack {
                            TextField("", text: .constant(preferencesManager.screenshotSaveDirectory.path))
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .disabled(true)

                            Button("Choose Folder...") {
                                preferencesManager.selectNewDirectory()
                            }
                        }

                        HStack {
                            Button("Open in Finder") {
                                NSWorkspace.shared.open(preferencesManager.screenshotSaveDirectory)
                            }

                            Button("Reset to Default") {
                                let defaultDir = PreferencesManager.getDefaultScreenshotDirectory()
                                preferencesManager.updateScreenshotDirectory(defaultDir)
                            }

                            Spacer()
                        }

                        // Permission help text
                        PermissionHelpView(preferencesManager: preferencesManager)
                    }
                    .padding()
                }

                GroupBox("File Format") {
                    VStack(alignment: .leading, spacing: 12) {
                        Picker("Format:", selection: $preferencesManager.screenshotFormat) {
                            ForEach(PreferencesManager.ScreenshotFormat.allCases, id: \.self) { format in
                                Text(format.displayName).tag(format)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .onChange(of: preferencesManager.screenshotFormat) {
                            preferencesManager.updateScreenshotFormat(preferencesManager.screenshotFormat)
                        }

                        Text(formatDescription(for: preferencesManager.screenshotFormat))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                }
            }
        }
        .padding()
    }

    private var appearanceTab: some View {
        Form {
            Section {
                GroupBox("Clipboard Window") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Border Color")
                            .font(.headline)

                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 10) {
                            ForEach(0..<availableColors.count, id: \.self) { index in
                                Button(action: {
                                    selectedColorIndex = index
                                    UserDefaults.standard.set(index, forKey: "SelectedBorderColor")
                                    NotificationCenter.default.post(name: NSNotification.Name("BorderColorChanged"), object: nil)
                                    print("🎨 [PREFS] Border color changed to: \(colorNames[index])")
                                }) {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(availableColors[index])
                                        .frame(width: 40, height: 40)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(selectedColorIndex == index ? Color.primary : Color.clear, lineWidth: 3)
                                        )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }

                        Text("Selected: \(colorNames[selectedColorIndex])")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                }

                GroupBox("Window Behavior") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Window positioning and visibility preferences")
                            .font(.headline)

                        Text("The clipboard window automatically positions itself at the right edge of your screen and can be configured to remain always visible or show only when needed.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding()
                }
            }
        }
        .padding()
    }

    private func loadSettings() {
        selectedColorIndex = UserDefaults.standard.integer(forKey: "SelectedBorderColor")
        showMenuBarIcon = UserDefaults.standard.bool(forKey: "ShowMenuBarIcon")

        // Load clipboard visibility mode with migration
        loadClipboardVisibilityMode()

        autoDimmingEnabled = UserDefaults.standard.bool(forKey: "AutoDimmingEnabled")
        autoHideEnabled = UserDefaults.standard.bool(forKey: "AutoHideEnabled")

        // Set defaults if first launch
        if UserDefaults.standard.object(forKey: "AutoDimmingEnabled") == nil {
            autoDimmingEnabled = true
            autoHideEnabled = true
            UserDefaults.standard.set(true, forKey: "AutoDimmingEnabled")
            UserDefaults.standard.set(true, forKey: "AutoHideEnabled")
        }
    }

    private func loadClipboardVisibilityMode() {
        // Check if we have the new preference
        if let modeString = UserDefaults.standard.string(forKey: "ClipboardVisibilityMode"),
           let mode = ClipboardVisibilityMode(rawValue: modeString) {
            clipboardVisibilityMode = mode
            print("📋 [PREFS] Loaded clipboard visibility mode: \(mode.displayName)")
        } else {
            // Migration from old boolean preference
            let legacyAlwaysShow = UserDefaults.standard.bool(forKey: "AlwaysShowClipboard")
            clipboardVisibilityMode = ClipboardVisibilityMode.fromLegacyPreference(alwaysShow: legacyAlwaysShow)

            // Save new preference and remove old one
            UserDefaults.standard.set(clipboardVisibilityMode.rawValue, forKey: "ClipboardVisibilityMode")
            UserDefaults.standard.removeObject(forKey: "AlwaysShowClipboard")

            print("📋 [PREFS] Migrated from legacy preference to: \(clipboardVisibilityMode.displayName)")
        }
    }

    private func formatDescription(for format: PreferencesManager.ScreenshotFormat) -> String {
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
