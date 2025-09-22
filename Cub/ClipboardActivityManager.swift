//
//  ClipboardActivityManager.swift
//  Cub
//
//  Created by sid on 21/09/24.
//  Extracted activity tracking logic from ClipboardWindow.swift for modular architecture
//

import Cocoa
import Foundation

// MARK: - Activity Management Protocol

protocol ClipboardActivityManaging: AnyObject {
    var delegate: ClipboardActivityDelegate? { get set }
    var isDimmingEnabled: Bool { get set }
    var isAutoHideEnabled: Bool { get set }
    var visibilityMode: ClipboardVisibilityMode { get set }

    func startTracking()
    func stopTracking()
    func resetActivity()
    func loadUserPreferences()
    func saveUserPreferences()
}

// MARK: - Activity Delegate Protocol

protocol ClipboardActivityDelegate: AnyObject {
    func shouldDimWindow() -> Bool
    func shouldAutoHideWindow() -> Bool
    func dimWindowRequested()
    func autoHideWindowRequested()
    func undimWindowRequested()
}

// MARK: - Activity Manager Implementation

class ClipboardActivityManager: ClipboardActivityManaging {
    weak var delegate: ClipboardActivityDelegate?

    // User preferences
    var isDimmingEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isDimmingEnabled, forKey: "AutoDimmingEnabled")
            print("📋 [ACTIVITY] Auto-dimming enabled: \(isDimmingEnabled)")
        }
    }

    var isAutoHideEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isAutoHideEnabled, forKey: "AutoHideEnabled")
            print("📋 [ACTIVITY] Auto-hide enabled: \(isAutoHideEnabled)")
        }
    }

    var visibilityMode: ClipboardVisibilityMode {
        didSet {
            UserDefaults.standard.set(visibilityMode.rawValue, forKey: "ClipboardVisibilityMode")
            print("📋 [ACTIVITY] Visibility mode updated: \(visibilityMode.displayName)")
        }
    }

    // Activity tracking
    private var activityTracker: ActivityTracker
    private var isTracking = false

    init() {
        // Initialize with default values
        self.isDimmingEnabled = true
        self.isAutoHideEnabled = true
        self.visibilityMode = .show

        // Initialize activity tracker
        self.activityTracker = ActivityTracker()
        self.activityTracker.delegate = self

        // Load user preferences
        loadUserPreferences()

        print("📋 [ACTIVITY] Activity manager initialized")
        print("📋 [ACTIVITY] Visibility mode: \(visibilityMode.displayName)")
        print("📋 [ACTIVITY] Auto-dimming enabled: \(isDimmingEnabled)")
        print("📋 [ACTIVITY] Auto-hide enabled: \(isAutoHideEnabled)")
    }

    // MARK: - Activity Tracking Control

    func startTracking() {
        guard !isTracking else { return }

        // Only start tracking if the mode supports it
        guard visibilityMode != .hidden else { return }
        guard (isDimmingEnabled && visibilityMode.allowsAutoDimming) ||
              (isAutoHideEnabled && visibilityMode.allowsAutoHiding) else { return }

        activityTracker.startTracking()
        isTracking = true
        print("🔍 [ACTIVITY] Started activity tracking for window (mode: \(visibilityMode.displayName))")
    }

    func stopTracking() {
        guard isTracking else { return }

        activityTracker.stopTracking()
        isTracking = false
        print("🔍 [ACTIVITY] Stopped activity tracking for window")
    }

    func resetActivity() {
        activityTracker.resetActivity()
    }

    // MARK: - User Preferences Management

    func loadUserPreferences() {
        // Load visibility mode with migration support
        if let modeString = UserDefaults.standard.string(forKey: "ClipboardVisibilityMode"),
           let mode = ClipboardVisibilityMode(rawValue: modeString) {
            visibilityMode = mode
        } else {
            // Migration from old boolean preference
            let legacyAlwaysShow = UserDefaults.standard.bool(forKey: "AlwaysShowClipboard")
            visibilityMode = ClipboardVisibilityMode.fromLegacyPreference(alwaysShow: legacyAlwaysShow)
            UserDefaults.standard.set(visibilityMode.rawValue, forKey: "ClipboardVisibilityMode")
        }

        // Load dimming and auto-hide preferences
        if UserDefaults.standard.object(forKey: "AutoDimmingEnabled") != nil {
            isDimmingEnabled = UserDefaults.standard.bool(forKey: "AutoDimmingEnabled")
        } else {
            // Set defaults if first launch
            isDimmingEnabled = true
            UserDefaults.standard.set(true, forKey: "AutoDimmingEnabled")
        }

        if UserDefaults.standard.object(forKey: "AutoHideEnabled") != nil {
            isAutoHideEnabled = UserDefaults.standard.bool(forKey: "AutoHideEnabled")
        } else {
            // Set defaults if first launch
            isAutoHideEnabled = true
            UserDefaults.standard.set(true, forKey: "AutoHideEnabled")
        }

        print("📋 [ACTIVITY] User preferences loaded")
    }

    func saveUserPreferences() {
        UserDefaults.standard.set(isDimmingEnabled, forKey: "AutoDimmingEnabled")
        UserDefaults.standard.set(isAutoHideEnabled, forKey: "AutoHideEnabled")
        UserDefaults.standard.set(visibilityMode.rawValue, forKey: "ClipboardVisibilityMode")
        print("📋 [ACTIVITY] User preferences saved")
    }

    // MARK: - Behavior Logic

    private func shouldPerformDimming(at duration: TimeInterval) -> Bool {
        return duration == 60.0 && // 1 minute
               isDimmingEnabled &&
               visibilityMode.allowsAutoDimming &&
               delegate?.shouldDimWindow() == true
    }

    private func shouldPerformAutoHide(at duration: TimeInterval) -> Bool {
        return duration == 180.0 && // 3 minutes
               isAutoHideEnabled &&
               visibilityMode.allowsAutoHiding &&
               delegate?.shouldAutoHideWindow() == true
    }
}

// MARK: - ActivityTrackerDelegate Implementation

extension ClipboardActivityManager: ActivityTrackerDelegate {
    func userActivityDetected() {
        print("🔄 [ACTIVITY] User activity detected")

        // Request undimming if needed
        delegate?.undimWindowRequested()
    }

    func inactivityPeriodReached(_ duration: TimeInterval) {
        print("⏰ [ACTIVITY] Inactivity period reached: \(duration) seconds (mode: \(visibilityMode.displayName))")

        if shouldPerformDimming(at: duration) {
            print("🌙 [ACTIVITY] Requesting window dimming after \(duration)s of inactivity")
            delegate?.dimWindowRequested()
        } else if shouldPerformAutoHide(at: duration) {
            print("🙈 [ACTIVITY] Requesting window auto-hide after \(duration)s of inactivity")
            delegate?.autoHideWindowRequested()
        }
    }
}

// MARK: - Activity Manager Extensions

extension ClipboardActivityManager {

    /// Updates the visibility mode and adjusts tracking accordingly
    func setVisibilityMode(_ mode: ClipboardVisibilityMode) {
        print("📋 [ACTIVITY] Setting visibility mode to: \(mode.displayName)")

        let previousMode = visibilityMode
        visibilityMode = mode

        // Handle state transitions based on the new mode
        switch mode {
        case .hidden:
            stopTracking()

        case .show:
            // Normal mode - allow both dimming and auto-hiding
            if isTracking || (isDimmingEnabled || isAutoHideEnabled) {
                startTracking()
            }
            print("📋 [ACTIVITY] Switched to show mode from \(previousMode.displayName)")

        case .alwaysShow:
            // Always visible mode - allow dimming but no auto-hiding
            if isTracking || isDimmingEnabled {
                startTracking()
            }
            print("📋 [ACTIVITY] Switched to always show mode from \(previousMode.displayName)")
        }
    }

    /// Updates dimming preference and manages tracking state
    func setAutoDimmingEnabled(_ enabled: Bool) {
        isDimmingEnabled = enabled

        // Restart tracking if needed when preferences change
        if isTracking {
            stopTracking()
            startTracking()
        }
    }

    /// Updates auto-hide preference and manages tracking state
    func setAutoHideEnabled(_ enabled: Bool) {
        isAutoHideEnabled = enabled

        // Restart tracking if needed when preferences change
        if isTracking {
            stopTracking()
            startTracking()
        }
    }
}
