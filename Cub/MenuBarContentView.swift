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

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Permission Status
            Group {
                HStack {
                    Image(systemName: permissionManager.isPermissionGranted ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(permissionManager.isPermissionGranted ? .green : .red)
                    Text("Screen Recording: \(permissionManager.isPermissionGranted ? "✅ Enabled" : "❌ Disabled")")
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

                if !permissionManager.isPermissionGranted {
                    Button("Grant Screen Recording Permission...") {
                        permissionManager.requestScreenRecordingPermission()
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                }
            }

            Divider()

            // Hotkey Status
            Group {
                HStack {
                    Image(systemName: hotkeyManager.hotkeyStatusIcon)
                        .foregroundColor(hotkeyManager.isHotkeyActive ? .green : .red)
                    Text("Global Hotkey (⌘E): \(hotkeyManager.isHotkeyActive ? "✅ Active" : "❌ \(hotkeyManager.hotkeyStatusDescription)")")
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

                HStack {
                    Button("Test Hotkey (⌘E)") {
                        hotkeyManager.testHotkey()
                    }
                    .disabled(!hotkeyManager.isHotkeyActive)

                    if !hotkeyManager.isHotkeyActive {
                        Button("Re-register Hotkey") {
                            hotkeyManager.registerHotkey()
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            }

            Divider()

            // Clipboard Window Mode Actions
            Group {
                Button("Show") {
                    showAction()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)

                Button("Always Show") {
                    alwaysShowAction()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)

                Button("Hide") {
                    hideAction()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)

                Button("Preferences") {
                    preferencesAction()
                }
                .keyboardShortcut(",", modifiers: .command)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
            }

            Divider()

            // Quit
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(minWidth: 280)
    }

    private func showAction() {
        print("🖱️ [MENU] Show clicked")
        print("🔄 [MENU] Setting clipboard visibility mode to Show...")
        ClipboardWindowManager.shared.setVisibilityMode(.show)
        print("✅ [MENU] Set visibility mode to Show")
    }

    private func alwaysShowAction() {
        print("🖱️ [MENU] Always Show clicked")
        print("🔄 [MENU] Setting clipboard visibility mode to Always Show...")
        ClipboardWindowManager.shared.setVisibilityMode(.alwaysShow)
        print("✅ [MENU] Set visibility mode to Always Show")
    }

    private func hideAction() {
        print("🖱️ [MENU] Hide clicked")
        print("🔄 [MENU] Setting clipboard visibility mode to Hidden...")
        ClipboardWindowManager.shared.setVisibilityMode(.hidden)
        print("✅ [MENU] Set visibility mode to Hidden")
    }

    private func preferencesAction() {
        print("🖱️ [MENU] Preferences clicked")
        PreferencesWindowController.show()
        print("✅ [MENU] Preferences window requested to show")
    }
}

#Preview {
    MenuBarContentView()
        .environmentObject(PermissionManager())
        .environmentObject(HotkeyManager())
}
