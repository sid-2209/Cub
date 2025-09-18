//
//  CubApp.swift
//  Cub
//
//  Created by sid on 15/09/25.
//

import SwiftUI
import Cocoa

@main
struct CubApp: App {
    let persistenceController = PersistenceController.shared
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra("Cub", systemImage: "doc.on.clipboard") {
            MenuBarContentView()
                .environmentObject(appDelegate.permissionManager)
                .environmentObject(appDelegate.hotkeyManager)
        }

        Settings {
            PreferencesView()
                .environmentObject(appDelegate.permissionManager)
                .environmentObject(appDelegate.hotkeyManager)
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    // Manager instances - exposed for SwiftUI MenuBarExtra
    let permissionManager = PermissionManager()
    let hotkeyManager = HotkeyManager()
    private var clipboardWindow: ClipboardWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        print("🚀 [APP] applicationDidFinishLaunching - setting up connections")

        // Create clipboard window directly
        clipboardWindow = ClipboardWindow()

        print("📋 [APP] ClipboardWindow created, setting up connections...")

        // Set clipboard window reference in shared manager
        ClipboardWindowManager.shared.setWindow(clipboardWindow!)
        print("📋 [APP] ClipboardWindow set in shared manager")

        // Set up manager connections
        hotkeyManager.setPermissionManager(permissionManager)
        hotkeyManager.setClipboardWindow(clipboardWindow!)

        // Note: Preferences now handled by Settings scene in SwiftUI
        print("🪟 [APP] Settings scene will handle preferences")

        // Create shared gallery window controller
        GalleryWindowController.createShared()
        print("🖼️ [APP] Gallery window controller initialized")

        // Initialize appearance manager
        AppearanceManager.shared.initializeAppearance()
        print("🎨 [APP] Appearance manager initialized")

        // Trigger app launch handlers
        print("🔑 [APP] Calling permission and hotkey handleAppLaunch...")
        permissionManager.handleAppLaunch()
        hotkeyManager.handleAppLaunch()

        print("✅ [APP] App initialization complete")
    }

    func getClipboardWindow() -> ClipboardWindow? {
        return clipboardWindow
    }

    func applicationWillTerminate(_ notification: Notification) {
        print("🛑 [APP] Application terminating...")
        hotkeyManager.handleAppWillTerminate()
        clipboardWindow?.hideClipboard()
    }

    func applicationDidChangeScreenParameters(_ notification: Notification) {
        // Handle screen configuration changes
        clipboardWindow?.handleScreenChange()
    }
}
