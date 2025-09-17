//
//  ActivityTracker.swift
//  Cub
//
//  Created by sid on 17/09/25.
//

import Cocoa
import Foundation

protocol ActivityTrackerDelegate: AnyObject {
    func userActivityDetected()
    func inactivityPeriodReached(_ duration: TimeInterval)
}

class ActivityTracker {
    weak var delegate: ActivityTrackerDelegate?

    private var lastActivityTime: Date = Date()
    private var globalEventMonitor: Any?
    private var localEventMonitor: Any?
    private var inactivityTimer: Timer?
    private var isTracking: Bool = false

    // Timing constants following macOS patterns
    private let dimThreshold: TimeInterval = 60.0 // 1 minute
    private let hideThreshold: TimeInterval = 180.0 // 3 minutes
    private let checkInterval: TimeInterval = 5.0 // Check every 5 seconds

    // Throttling to prevent excessive event processing
    private var lastEventTime: Date = Date()
    private let eventThrottleInterval: TimeInterval = 0.1 // Max 10 events per second

    init() {
        print("🔍 [ACTIVITY] ActivityTracker initialized")
    }

    deinit {
        stopTracking()
        print("🔍 [ACTIVITY] ActivityTracker deinitialized")
    }

    // MARK: - Public Methods

    func startTracking() {
        guard !isTracking else {
            print("⚠️ [ACTIVITY] Already tracking activity")
            return
        }

        print("🔍 [ACTIVITY] Starting activity tracking...")
        isTracking = true
        lastActivityTime = Date()

        setupGlobalEventMonitoring()
        setupLocalEventMonitoring()
        startInactivityTimer()

        print("✅ [ACTIVITY] Activity tracking started successfully")
    }

    func stopTracking() {
        guard isTracking else { return }

        print("🔍 [ACTIVITY] Stopping activity tracking...")
        isTracking = false

        if let globalMonitor = globalEventMonitor {
            NSEvent.removeMonitor(globalMonitor)
            globalEventMonitor = nil
        }

        if let localMonitor = localEventMonitor {
            NSEvent.removeMonitor(localMonitor)
            localEventMonitor = nil
        }

        inactivityTimer?.invalidate()
        inactivityTimer = nil

        print("✅ [ACTIVITY] Activity tracking stopped")
    }

    func resetActivity() {
        lastActivityTime = Date()
        delegate?.userActivityDetected()
        print("🔄 [ACTIVITY] Activity reset - user interaction detected")
    }

    func getTimeSinceLastActivity() -> TimeInterval {
        return Date().timeIntervalSince(lastActivityTime)
    }

    var isDimThresholdReached: Bool {
        return getTimeSinceLastActivity() >= dimThreshold
    }

    var isHideThresholdReached: Bool {
        return getTimeSinceLastActivity() >= hideThreshold
    }

    // MARK: - Private Methods

    private func setupGlobalEventMonitoring() {
        // Monitor global mouse and keyboard events
        let eventMask: NSEvent.EventTypeMask = [
            .leftMouseDown, .rightMouseDown, .otherMouseDown,
            .leftMouseUp, .rightMouseUp, .otherMouseUp,
            .mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged,
            .keyDown, .keyUp, .scrollWheel
        ]

        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: eventMask) { [weak self] event in
            self?.handleGlobalEvent(event)
        }

        print("🌐 [ACTIVITY] Global event monitoring setup complete")
    }

    private func setupLocalEventMonitoring() {
        // Monitor local events for the app
        let eventMask: NSEvent.EventTypeMask = [
            .leftMouseDown, .rightMouseDown, .otherMouseDown,
            .leftMouseUp, .rightMouseUp, .otherMouseUp,
            .mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged,
            .keyDown, .keyUp, .scrollWheel, .mouseEntered, .mouseExited
        ]

        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: eventMask) { [weak self] event in
            self?.handleLocalEvent(event)
            return event
        }

        print("🏠 [ACTIVITY] Local event monitoring setup complete")
    }

    private func handleGlobalEvent(_ event: NSEvent) {
        // Only track certain global events to avoid excessive activity resets
        switch event.type {
        case .leftMouseDown, .rightMouseDown, .keyDown:
            handleActivityEvent()
        default:
            break
        }
    }

    private func handleLocalEvent(_ event: NSEvent) {
        // Track most local events as they indicate interaction with our app
        handleActivityEvent()
    }

    private func handleActivityEvent() {
        // Throttle event processing to prevent excessive resets
        let now = Date()
        guard now.timeIntervalSince(lastEventTime) >= eventThrottleInterval else {
            return
        }

        lastEventTime = now
        resetActivity()
    }

    private func startInactivityTimer() {
        inactivityTimer = Timer.scheduledTimer(withTimeInterval: checkInterval, repeats: true) { [weak self] _ in
            self?.checkInactivityStatus()
        }

        print("⏱️ [ACTIVITY] Inactivity timer started (checking every \(checkInterval)s)")
    }

    private func checkInactivityStatus() {
        let timeSinceLastActivity = getTimeSinceLastActivity()

        // Check for dim threshold
        if timeSinceLastActivity >= dimThreshold && timeSinceLastActivity < hideThreshold {
            delegate?.inactivityPeriodReached(dimThreshold)
        }
        // Check for hide threshold
        else if timeSinceLastActivity >= hideThreshold {
            delegate?.inactivityPeriodReached(hideThreshold)
        }
    }

    // MARK: - App State Handling

    func handleApplicationDidBecomeActive() {
        print("🔍 [ACTIVITY] App became active - resetting activity")
        resetActivity()
    }

    func handleApplicationDidResignActive() {
        print("🔍 [ACTIVITY] App resigned active")
        // Continue tracking but don't reset activity
    }

    func handleSystemWakeUp() {
        print("🔍 [ACTIVITY] System wake up - resetting activity")
        resetActivity()
    }
}

// MARK: - Accessibility Support

extension ActivityTracker {
    func setReducedMotionMode(_ enabled: Bool) {
        // Future implementation for respecting reduced motion preferences
        print("♿ [ACTIVITY] Reduced motion mode: \(enabled)")
    }

    func setActivityTrackingEnabled(_ enabled: Bool) {
        if enabled && !isTracking {
            startTracking()
        } else if !enabled && isTracking {
            stopTracking()
        }
    }
}
