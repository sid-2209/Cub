//
//  PreferencesWindowController.swift
//  Cub
//
//  Created by sid on 17/09/25.
//

import Cocoa
import SwiftUI

class PreferencesWindowController: NSWindowController {
    private var permissionManager: PermissionManager
    private var hotkeyManager: HotkeyManager

    static var shared: PreferencesWindowController?

    init(permissionManager: PermissionManager, hotkeyManager: HotkeyManager) {
        self.permissionManager = permissionManager
        self.hotkeyManager = hotkeyManager

        // Create the window
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )

        super.init(window: window)

        setupWindow()
        setupContent()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupWindow() {
        guard let window = window else { return }

        // Window configuration
        window.title = "Cub Preferences"
        window.center()
        window.setFrameAutosaveName("PreferencesWindow")
        window.isReleasedWhenClosed = false
        window.level = .floating

        // Make window appear above all other windows when shown from menu bar
        window.hidesOnDeactivate = false

        // Set minimum and maximum size
        window.minSize = NSSize(width: 450, height: 350)
        window.maxSize = NSSize(width: 600, height: 500)

        print("🪟 [PREFS] Preferences window configured")
    }

    private func setupContent() {
        guard let window = window else { return }

        // Create SwiftUI view with environment objects
        let preferencesView = PreferencesView()
            .environmentObject(permissionManager)
            .environmentObject(hotkeyManager)

        // Create hosting view
        let hostingView = NSHostingView(rootView: preferencesView)
        window.contentView = hostingView

        print("🪟 [PREFS] SwiftUI content view configured")
    }

    func showPreferences() {
        print("🪟 [PREFS] showPreferences() called")

        // Activate the application to bring it to front
        NSApp.activate(ignoringOtherApps: true)

        // Show the window
        window?.makeKeyAndOrderFront(nil)
        window?.orderFrontRegardless()

        print("🪟 [PREFS] Preferences window shown")
    }

    func hidePreferences() {
        window?.orderOut(nil)
        print("🪟 [PREFS] Preferences window hidden")
    }

    static func createShared(permissionManager: PermissionManager, hotkeyManager: HotkeyManager) {
        if shared == nil {
            shared = PreferencesWindowController(
                permissionManager: permissionManager,
                hotkeyManager: hotkeyManager
            )
            print("🪟 [PREFS] Shared preferences window controller created")
        }
    }

    static func show() {
        guard let shared = shared else {
            print("❌ [PREFS] No shared preferences window controller available")
            return
        }
        shared.showPreferences()
    }

    static func hide() {
        shared?.hidePreferences()
    }
}
