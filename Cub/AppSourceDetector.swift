//
//  AppSourceDetector.swift
//  Cub
//
//  Created by sid on 17/09/25.
//

import Cocoa
import Foundation

struct AppSourceInfo {
    let bundleID: String
    let name: String
    let icon: Data?
    let processID: pid_t
    let windowID: CGWindowID?
}

class AppSourceDetector {
    static let shared = AppSourceDetector()

    private init() {}

    // MARK: - Public Methods

    func detectFrontmostApp() -> AppSourceInfo? {
        guard let frontmostApp = NSWorkspace.shared.frontmostApplication else {
            print("❌ [APP-DETECT] No frontmost application found")
            return nil
        }

        let bundleID = frontmostApp.bundleIdentifier ?? "unknown"
        let appName = frontmostApp.localizedName ?? "Unknown App"
        let processID = frontmostApp.processIdentifier

        print("🔍 [APP-DETECT] Frontmost app detected:")
        print("   Bundle ID: \(bundleID)")
        print("   Name: \(appName)")
        print("   Process ID: \(processID)")

        // Get app icon
        let iconData = getAppIconData(for: frontmostApp)

        // Get frontmost window ID (optional)
        let windowID = getFrontmostWindowID(for: processID)

        return AppSourceInfo(
            bundleID: bundleID,
            name: appName,
            icon: iconData,
            processID: processID,
            windowID: windowID
        )
    }

    func detectAppAtPosition(_ position: NSPoint) -> AppSourceInfo? {
        // Get window info at the specified position
        guard let windowInfo = getWindowInfo(at: position) else {
            print("❌ [APP-DETECT] No window found at position \(position)")
            return detectFrontmostApp() // Fallback to frontmost app
        }

        let processID = windowInfo.processID
        let windowID = windowInfo.windowID

        // Get running application for this process
        let runningApps = NSWorkspace.shared.runningApplications
        guard let app = runningApps.first(where: { $0.processIdentifier == processID }) else {
            print("❌ [APP-DETECT] No running application found for PID \(processID)")
            return detectFrontmostApp() // Fallback to frontmost app
        }

        let bundleID = app.bundleIdentifier ?? "unknown"
        let appName = app.localizedName ?? "Unknown App"

        print("🎯 [APP-DETECT] App detected at position \(position):")
        print("   Bundle ID: \(bundleID)")
        print("   Name: \(appName)")
        print("   Process ID: \(processID)")
        print("   Window ID: \(windowID)")

        // Get app icon
        let iconData = getAppIconData(for: app)

        return AppSourceInfo(
            bundleID: bundleID,
            name: appName,
            icon: iconData,
            processID: processID,
            windowID: windowID
        )
    }

    // MARK: - Private Methods

    private func getAppIconData(for app: NSRunningApplication) -> Data? {
        guard let icon = app.icon else {
            print("⚠️ [APP-DETECT] No icon available for \(app.localizedName ?? "unknown")")
            return nil
        }

        // Convert icon to PNG data
        guard let tiffData = icon.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            print("⚠️ [APP-DETECT] Failed to convert icon to PNG data")
            return nil
        }

        print("✅ [APP-DETECT] Icon data extracted (\(pngData.count) bytes)")
        return pngData
    }

    private func getFrontmostWindowID(for processID: pid_t) -> CGWindowID? {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }

        // Find the frontmost window for this process
        for windowInfo in windowList {
            if let windowProcessID = windowInfo[kCGWindowOwnerPID as String] as? Int32,
               windowProcessID == processID,
               let windowID = windowInfo[kCGWindowNumber as String] as? CGWindowID {
                return windowID
            }
        }

        return nil
    }

    private func getWindowInfo(at position: NSPoint) -> (processID: pid_t, windowID: CGWindowID)? {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }

        // Convert position to screen coordinates
        let screenHeight = NSScreen.main?.frame.height ?? 0
        let flippedY = screenHeight - position.y
        let screenPosition = NSPoint(x: position.x, y: flippedY)

        // Find the topmost window containing this position
        for windowInfo in windowList {
            guard let bounds = windowInfo[kCGWindowBounds as String] as? [String: Any],
                  let x = bounds["X"] as? CGFloat,
                  let y = bounds["Y"] as? CGFloat,
                  let width = bounds["Width"] as? CGFloat,
                  let height = bounds["Height"] as? CGFloat else {
                continue
            }

            let windowRect = NSRect(x: x, y: y, width: width, height: height)

            if windowRect.contains(screenPosition),
               let processID = windowInfo[kCGWindowOwnerPID as String] as? pid_t,
               let windowID = windowInfo[kCGWindowNumber as String] as? CGWindowID {
                return (processID: processID, windowID: windowID)
            }
        }

        return nil
    }
}

// MARK: - Utility Extensions

extension AppSourceDetector {
    func getAppDisplayName(for bundleID: String) -> String {
        // Provide more user-friendly names for common apps
        switch bundleID.lowercased() {
        case let id where id.contains("com.apple.dt.xcode"):
            return "Xcode"
        case let id where id.contains("com.apple.safari"):
            return "Safari"
        case let id where id.contains("com.google.chrome"):
            return "Google Chrome"
        case let id where id.contains("com.figma.desktop"):
            return "Figma"
        case let id where id.contains("com.bohemiancoding.sketch3"):
            return "Sketch"
        case let id where id.contains("com.apple.iphonesimulator"):
            return "iOS Simulator"
        case let id where id.contains("com.microsoft.vscode"):
            return "Visual Studio Code"
        case let id where id.contains("com.sublimetext"):
            return "Sublime Text"
        case let id where id.contains("com.jetbrains"):
            if id.contains("intellij") {
                return "IntelliJ IDEA"
            } else if id.contains("pycharm") {
                return "PyCharm"
            } else if id.contains("webstorm") {
                return "WebStorm"
            }
            return "JetBrains IDE"
        default:
            // Try to get the app name from the system
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID),
               let bundle = Bundle(url: url),
               let displayName = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String {
                return displayName
            } else if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID),
                      let bundle = Bundle(url: url),
                      let name = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String {
                return name
            }

            // Fallback: clean up bundle ID for display
            return bundleID.components(separatedBy: ".").last?.capitalized ?? bundleID
        }
    }
}
