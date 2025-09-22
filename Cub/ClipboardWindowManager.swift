//
//  ClipboardWindowManager.swift
//  Cub
//
//  Created by sid on 16/09/25.
//  Refactored for modular architecture by Claude on 21/09/24
//

import Foundation
import Cocoa

// MARK: - Window State Management

enum ClipboardWindowState {
    case hidden
    case visible
    case dimmed
    case alwaysVisible

    var rawValue: String {
        switch self {
        case .hidden: return "hidden"
        case .visible: return "visible"
        case .dimmed: return "dimmed"
        case .alwaysVisible: return "alwaysVisible"
        }
    }

    init?(rawValue: String) {
        switch rawValue {
        case "hidden": self = .hidden
        case "visible": self = .visible
        case "dimmed": self = .dimmed
        case "alwaysVisible": self = .alwaysVisible
        default: return nil
        }
    }
}

// MARK: - Window Management Protocol

protocol ClipboardWindowManaging: AnyObject {
    func positionWindow(_ window: NSWindow)
    func saveWindowState(_ state: ClipboardWindowState)
    func loadWindowState() -> ClipboardWindowState
    func handleScreenChange(for window: NSWindow)
    var windowDimensions: (width: CGFloat, height: CGFloat) { get }
}

// MARK: - Window Manager Implementation

class ClipboardWindowManager: ClipboardWindowManaging {
    static let shared = ClipboardWindowManager()

    private var clipboardWindow: ClipboardWindow?

    // Window dimensions
    private let windowWidth: CGFloat = 280
    private let windowHeight: CGFloat = 450
    private let edgeMargin: CGFloat = 15
    private let topMargin: CGFloat = 80

    var windowDimensions: (width: CGFloat, height: CGFloat) {
        return (windowWidth, windowHeight)
    }

    private init() {
        print("📋 [MANAGER] ClipboardWindowManager initialized")
    }

    // MARK: - Window Reference Management

    func setWindow(_ window: ClipboardWindow) {
        print("📋 [MANAGER] Setting clipboard window reference")
        self.clipboardWindow = window
    }

    func getClipboardWindow() -> ClipboardWindow? {
        return clipboardWindow
    }

    // MARK: - Window Positioning Protocol Implementation

    func positionWindow(_ window: NSWindow) {
        positionWindowAtEdge(window)
    }

    func saveWindowState(_ state: ClipboardWindowState) {
        UserDefaults.standard.set(state.rawValue, forKey: "ClipboardWindowState")
        print("📋 [MANAGER] Saved window state: \(state.rawValue)")
    }

    func loadWindowState() -> ClipboardWindowState {
        let savedState = UserDefaults.standard.string(forKey: "ClipboardWindowState") ?? "hidden"
        print("📋 [MANAGER] Loading window state: \(savedState)")

        return ClipboardWindowState(rawValue: savedState) ?? .hidden
    }

    func handleScreenChange(for window: NSWindow) {
        positionWindowAtEdge(window)
    }

    // MARK: - Legacy Delegation Methods (for backwards compatibility)

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

    func setAutoDimmingEnabled(_ enabled: Bool) {
        print("📋 [MANAGER] setAutoDimmingEnabled(\(enabled)) called")
        clipboardWindow?.setAutoDimmingEnabled(enabled)
    }

    func setAutoHideEnabled(_ enabled: Bool) {
        print("📋 [MANAGER] setAutoHideEnabled(\(enabled)) called")
        clipboardWindow?.setAutoHideEnabled(enabled)
    }

    func setVisibilityMode(_ mode: ClipboardVisibilityMode) {
        print("📋 [MANAGER] setVisibilityMode(\(mode.displayName)) called")
        clipboardWindow?.setVisibilityMode(mode)
    }

    // MARK: - Private Implementation

    private func positionWindowAtEdge(_ window: NSWindow) {
        print("📍 [MANAGER] Starting window positioning...")

        var screen = NSScreen.main
        print("📍 [MANAGER] Main screen: \(screen != nil ? "✅ Available" : "❌ Nil")")

        // Fallback to first available screen if main is unavailable
        if screen == nil {
            screen = NSScreen.screens.first
            print("⚠️ [MANAGER] Main screen unavailable, using first available screen")
        }

        guard let validScreen = screen else {
            print("❌ [MANAGER] No screens available for positioning")
            return
        }

        let visibleFrame = validScreen.visibleFrame
        print("📍 [MANAGER] Screen visible frame: \(visibleFrame)")

        // Get user's preferred window position
        let windowPosition = SettingsStore.shared.windowPositionEnum
        print("📍 [MANAGER] User preference: \(windowPosition.displayName)")

        // Ensure window fits within screen bounds with stricter constraints
        let maxWidth = visibleFrame.width * 0.25 // Maximum 25% of screen width
        let maxHeight = visibleFrame.height - topMargin * 2

        let adjustedWidth = min(windowWidth, min(maxWidth, visibleFrame.width - edgeMargin * 2))
        let adjustedHeight = min(windowHeight, maxHeight)

        print("📍 [MANAGER] Adjusted dimensions: \(adjustedWidth) x \(adjustedHeight)")

        // Calculate X position based on user preference
        let xPosition: CGFloat
        switch windowPosition {
        case .left:
            xPosition = visibleFrame.minX + edgeMargin
            print("📍 [MANAGER] Positioning at left edge")
        case .right:
            xPosition = visibleFrame.maxX - adjustedWidth - edgeMargin
            print("📍 [MANAGER] Positioning at right edge")
        }

        let newFrame = NSRect(
            x: xPosition,
            y: visibleFrame.minY + topMargin,
            width: adjustedWidth,
            height: adjustedHeight
        )

        print("📍 [MANAGER] Calculated new frame: \(newFrame)")
        print("📍 [MANAGER] Screen visible frame: \(visibleFrame)")
        print("📍 [MANAGER] Window size adjusted: \(adjustedWidth)×\(adjustedHeight)")
        print("📍 [MANAGER] Original window size: \(windowWidth)×\(windowHeight)")
        print("📍 [MANAGER] Max width allowed: \(maxWidth)")

        window.setFrame(newFrame, display: true, animate: false)

        // Force constrain the window after setting frame
        let actualFrame = window.frame
        print("📍 [MANAGER] Actual window frame after setFrame: \(actualFrame)")

        // If the window is still too wide, force it smaller
        if actualFrame.width > adjustedWidth + 10 { // 10px tolerance
            let correctedFrame = NSRect(
                x: actualFrame.origin.x,
                y: actualFrame.origin.y,
                width: adjustedWidth,
                height: adjustedHeight
            )
            print("🔧 [MANAGER] Correcting oversized window from \(actualFrame.width) to \(adjustedWidth)")
            window.setFrame(correctedFrame, display: true, animate: false)
        }
    }
}
