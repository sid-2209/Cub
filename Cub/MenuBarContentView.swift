//
//  MenuBarContentView.swift
//  Cub
//
//  Created by sid on 16/09/25.
//

import SwiftUI

struct MenuBarContentView: View {
    @EnvironmentObject var permissionManager: PermissionManager
    @EnvironmentObject var hotkeyManager: HotkeyManager
    @Environment(\.openSettings) private var openSettings

    @State private var currentClipboardMode: ClipboardVisibilityMode = .show

    private func loadCurrentMode() {
        if let modeString = UserDefaults.standard.string(forKey: "ClipboardVisibilityMode"),
           let mode = ClipboardVisibilityMode(rawValue: modeString) {
            currentClipboardMode = mode
        } else {
            // Migration from old boolean preference
            let legacyAlwaysShow = UserDefaults.standard.bool(forKey: "AlwaysShowClipboard")
            currentClipboardMode = ClipboardVisibilityMode.fromLegacyPreference(alwaysShow: legacyAlwaysShow)
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            // Compact Status Section
            CompactStatusSection()
                .environmentObject(permissionManager)
                .environmentObject(hotkeyManager)

            // Clipboard Mode Selection
            MenuBarModeButtonGroup(
                currentMode: currentClipboardMode,
                onModeChange: handleModeChange
            )

            // Action Buttons
            MenuBarActionSection(
                onPreferences: preferencesAction,
                onQuit: quitAction
            )
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .frame(minWidth: 240)
        .onAppear {
            loadCurrentMode()
        }
    }

    private func handleModeChange(_ mode: ClipboardVisibilityMode) {
        print("🖱️ [MENU] Mode changed to: \(mode.displayName)")
        currentClipboardMode = mode
        ClipboardWindowManager.shared.setVisibilityMode(mode)
        print("✅ [MENU] Set visibility mode to \(mode.displayName)")
    }

    private func preferencesAction() {
        print("🖱️ [MENU] Preferences clicked")
        openSettings()
        print("✅ [MENU] Settings scene opened")
    }

    private func quitAction() {
        print("🛑 [MENU] Quit clicked")
        NSApplication.shared.terminate(nil)
    }
}

#Preview {
    MenuBarContentView()
        .environmentObject(PermissionManager())
        .environmentObject(HotkeyManager())
}
