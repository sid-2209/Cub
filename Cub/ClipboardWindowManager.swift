//
//  ClipboardWindowManager.swift
//  Cub
//
//  Created by Claude on 16/09/25.
//

import Foundation
import Cocoa

class ClipboardWindowManager {
    static let shared = ClipboardWindowManager()

    private var clipboardWindow: ClipboardWindow?

    private init() {
        print("📋 [MANAGER] ClipboardWindowManager initialized")
    }

    func setWindow(_ window: ClipboardWindow) {
        print("📋 [MANAGER] Setting clipboard window reference")
        self.clipboardWindow = window
    }

    func setAlwaysVisible(_ visible: Bool) {
        print("📋 [MANAGER] setAlwaysVisible(\(visible)) called")

        guard let clipboardWindow = clipboardWindow else {
            print("❌ [MANAGER] ClipboardWindow is nil - cannot set visibility")
            return
        }

        print("✅ [MANAGER] ClipboardWindow available, calling setAlwaysVisible(\(visible))")
        clipboardWindow.setAlwaysVisible(visible)
    }

    func hideClipboard() {
        print("📋 [MANAGER] hideClipboard() called")
        clipboardWindow?.hideClipboard()
    }

    func getClipboardWindow() -> ClipboardWindow? {
        return clipboardWindow
    }
}