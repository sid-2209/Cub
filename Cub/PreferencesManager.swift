//
//  PreferencesManager.swift
//  Cub
//
//  Created by sid on 16/09/25.
//

import Foundation
import Cocoa

class PreferencesManager: ObservableObject {
    static let shared = PreferencesManager()

    @Published var screenshotSaveDirectory: URL
    @Published var screenshotFormat: ScreenshotFormat = .png

    enum ScreenshotFormat: String, CaseIterable {
        case png = "png"
        case jpeg = "jpg"
        case tiff = "tiff"

        var displayName: String {
            switch self {
            case .png: return "PNG (Lossless)"
            case .jpeg: return "JPEG (Compressed)"
            case .tiff: return "TIFF (Lossless)"
            }
        }
    }

    private let userDefaults = UserDefaults.standard
    private let screenshotDirectoryKey = "screenshotSaveDirectory"
    private let screenshotFormatKey = "screenshotFormat"
    private let securityBookmarkKey = "screenshotDirectoryBookmark"

    private init() {
        let defaultDirectory = PreferencesManager.getDefaultScreenshotDirectory()

        // Initialize with default first to satisfy Swift's init requirements
        self.screenshotSaveDirectory = defaultDirectory

        // Try to restore from security scoped bookmark first
        if let bookmarkData = userDefaults.data(forKey: securityBookmarkKey) {
            do {
                var isStale = false
                let url = try URL(resolvingBookmarkData: bookmarkData,
                                options: .withSecurityScope,
                                relativeTo: nil,
                                bookmarkDataIsStale: &isStale)

                if !isStale && url.startAccessingSecurityScopedResource() {
                    if validateDirectoryAccess(url) {
                        self.screenshotSaveDirectory = url
                        print("📁 [PREFS] Restored directory from security bookmark: \(url.path)")
                    } else {
                        print("⚠️ [PREFS] Security bookmark directory not accessible, using default")
                        url.stopAccessingSecurityScopedResource()
                        migrateLegacyDirectory()
                    }
                } else {
                    print("⚠️ [PREFS] Security bookmark is stale, using default directory")
                    migrateLegacyDirectory()
                }
            } catch {
                print("❌ [PREFS] Failed to resolve security bookmark: \(error)")
                migrateLegacyDirectory()
            }
        } else if let directoryData = userDefaults.data(forKey: screenshotDirectoryKey),
                  let url = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSURL.self, from: directoryData) as URL? {
            // Handle legacy saved directory with migration
            if validateDirectoryAccess(url) {
                self.screenshotSaveDirectory = url
                print("📁 [PREFS] Restored directory from legacy storage: \(url.path)")

                // Try to upgrade to security bookmark for future use
                migrateLegacyToSecurityBookmark(url)
            } else {
                print("🔄 [PREFS] Legacy directory not accessible, migrating to default")
                migrateLegacyDirectory()
            }
        }

        if let formatString = userDefaults.string(forKey: screenshotFormatKey),
           let format = ScreenshotFormat(rawValue: formatString) {
            self.screenshotFormat = format
        }

        print("📁 [PREFS] Initialized with directory: \(screenshotSaveDirectory.path)")
        print("🖼️ [PREFS] Initialized with format: \(screenshotFormat.displayName)")
    }

    static func getDefaultScreenshotDirectory() -> URL {
        // For sandboxed apps, Apple recommends using Documents directory by default
        // Users can then choose a different location via file picker which grants access
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        let cubDirectory = documentsDirectory?.appendingPathComponent("Cub Screenshots")

        if let cubDir = cubDirectory {
            return cubDir
        }

        // Final fallback to application support directory (always accessible in sandbox)
        let appSupportDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        let fallbackDirectory = appSupportDirectory?.appendingPathComponent("Cub/Screenshots")

        return fallbackDirectory ?? FileManager.default.temporaryDirectory.appendingPathComponent("Cub Screenshots")
    }

    func updateScreenshotDirectory(_ newDirectory: URL) {
        // Stop accessing previous security scoped resource
        screenshotSaveDirectory.stopAccessingSecurityScopedResource()

        // Ensure the new directory exists and is accessible
        guard ensureDirectoryExistsAt(newDirectory) else {
            print("❌ [PREFS] Cannot create or access new directory: \(newDirectory.path)")
            return
        }

        screenshotSaveDirectory = newDirectory

        // Try to create security scoped bookmark (only works for user-selected directories)
        saveDirectoryWithSecurityBookmark(newDirectory)

        // Ensure the directory will be accessible for future saves
        _ = ensureDirectoryExists()
    }

    private func ensureDirectoryExistsAt(_ directory: URL) -> Bool {
        let fileManager = FileManager.default

        if !fileManager.fileExists(atPath: directory.path) {
            do {
                try fileManager.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
                print("📁 [PREFS] Created directory: \(directory.path)")
            } catch {
                print("❌ [PREFS] Failed to create directory: \(directory.path) - \(error)")
                return false
            }
        }

        return validateDirectoryAccess(directory)
    }

    private func saveDirectoryWithSecurityBookmark(_ directory: URL) {
        do {
            // Create security scoped bookmark for sandboxed access
            let bookmarkData = try directory.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )

            // Save the security scoped bookmark
            userDefaults.set(bookmarkData, forKey: securityBookmarkKey)

            // Also save legacy format for compatibility
            let legacyData = try NSKeyedArchiver.archivedData(withRootObject: directory, requiringSecureCoding: true)
            userDefaults.set(legacyData, forKey: screenshotDirectoryKey)

            print("✅ [PREFS] Saved directory with security bookmark: \(directory.path)")

            // Test that we can restore the bookmark
            testSecurityBookmarkRestore()

        } catch {
            print("❌ [PREFS] Failed to create security bookmark: \(error)")

            // Fallback to legacy save method
            do {
                let legacyData = try NSKeyedArchiver.archivedData(withRootObject: directory, requiringSecureCoding: true)
                userDefaults.set(legacyData, forKey: screenshotDirectoryKey)
                print("✅ [PREFS] Saved directory using legacy method: \(directory.path)")
            } catch {
                print("❌ [PREFS] Failed to save directory preference: \(error)")
            }
        }
    }

    private func testSecurityBookmarkRestore() {
        guard let bookmarkData = userDefaults.data(forKey: securityBookmarkKey) else {
            print("⚠️ [PREFS] No bookmark data to test")
            return
        }

        do {
            var isStale = false
            let restoredURL = try URL(resolvingBookmarkData: bookmarkData,
                                    options: .withSecurityScope,
                                    relativeTo: nil,
                                    bookmarkDataIsStale: &isStale)

            if !isStale {
                print("✅ [PREFS] Security bookmark test successful: \(restoredURL.path)")
            } else {
                print("⚠️ [PREFS] Security bookmark is stale during test")
            }
        } catch {
            print("❌ [PREFS] Security bookmark test failed: \(error)")
        }
    }

    func updateScreenshotFormat(_ newFormat: ScreenshotFormat) {
        screenshotFormat = newFormat
        userDefaults.set(newFormat.rawValue, forKey: screenshotFormatKey)
        print("✅ [PREFS] Updated screenshot format to: \(newFormat.displayName)")
    }

    func ensureDirectoryExists() -> Bool {
        // First validate current directory access
        if !validateCurrentDirectoryAccess() {
            print("⚠️ [PREFS] Current directory not accessible, attempting fallback")
            return fallbackToAccessibleDirectory()
        }

        let fileManager = FileManager.default

        if !fileManager.fileExists(atPath: screenshotSaveDirectory.path) {
            do {
                try fileManager.createDirectory(at: screenshotSaveDirectory, withIntermediateDirectories: true, attributes: nil)
                print("📁 [PREFS] Created screenshot directory: \(screenshotSaveDirectory.path)")

                // Validate that we can actually write to the created directory
                if !validateCurrentDirectoryAccess() {
                    print("⚠️ [PREFS] Created directory but cannot write to it, falling back")
                    return fallbackToAccessibleDirectory()
                }

                return true
            } catch {
                print("❌ [PREFS] Failed to create directory: \(error)")
                return fallbackToAccessibleDirectory()
            }
        }

        return true
    }

    private func fallbackToAccessibleDirectory() -> Bool {
        let fileManager = FileManager.default

        // Try Documents directory first
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent("Cub Screenshots")

        if let documentsDir = documentsDirectory {
            do {
                try fileManager.createDirectory(at: documentsDir, withIntermediateDirectories: true, attributes: nil)

                if validateDirectoryAccess(documentsDir) {
                    // Stop accessing current security scoped resource
                    screenshotSaveDirectory.stopAccessingSecurityScopedResource()
                    screenshotSaveDirectory = documentsDir
                    print("✅ [PREFS] Fallback to Documents directory successful: \(documentsDir.path)")

                    // Clear any existing bookmarks since we're falling back
                    userDefaults.removeObject(forKey: securityBookmarkKey)
                    userDefaults.removeObject(forKey: screenshotDirectoryKey)

                    return true
                }
            } catch {
                print("❌ [PREFS] Documents directory fallback failed: \(error)")
            }
        }

        // Final fallback to temp directory
        let tempDirectory = fileManager.temporaryDirectory.appendingPathComponent("Cub Screenshots")
        do {
            try fileManager.createDirectory(at: tempDirectory, withIntermediateDirectories: true, attributes: nil)

            if validateDirectoryAccess(tempDirectory) {
                // Stop accessing current security scoped resource
                screenshotSaveDirectory.stopAccessingSecurityScopedResource()
                screenshotSaveDirectory = tempDirectory
                print("⚠️ [PREFS] Using temporary directory: \(tempDirectory.path)")
                return true
            }
        } catch {
            print("❌ [PREFS] All directory fallback attempts failed: \(error)")
        }

        return false
    }

    func selectNewDirectory() {
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.allowsMultipleSelection = false
        openPanel.directoryURL = screenshotSaveDirectory
        openPanel.title = "Choose Screenshot Save Folder"
        openPanel.message = "Select a folder where Cub can save your screenshots. This will grant Cub permission to access this location."
        openPanel.prompt = "Trust This Folder"

        print("📁 [PREFS] Opening directory selection panel...")

        if openPanel.runModal() == .OK {
            if let selectedURL = openPanel.url {
                print("📁 [PREFS] User selected directory: \(selectedURL.path)")

                // Test access to the selected directory
                if validateDirectoryAccess(selectedURL) {
                    // Update with the user-selected directory (this creates security bookmark)
                    updateScreenshotDirectory(selectedURL)
                    print("✅ [PREFS] Successfully configured new screenshot directory")
                } else {
                    print("❌ [PREFS] Selected directory is not accessible")
                    // Note: This shouldn't happen since NSOpenPanel grants access, but handle gracefully
                    showDirectoryAccessError()
                }
            }
        } else {
            print("📁 [PREFS] User cancelled directory selection")
        }
    }

    private func showDirectoryAccessError() {
        // This will be enhanced when we add user feedback UI
        print("❌ [PREFS] Directory access error - user should be notified")
    }

    func generateFileName(format: ScreenshotFormat? = nil) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        let dateString = dateFormatter.string(from: Date())
        let formatToUse = format ?? screenshotFormat
        return "Screenshot \(dateString).\(formatToUse.rawValue)"
    }

    func getFilePath(for fileName: String) -> URL {
        return screenshotSaveDirectory.appendingPathComponent(fileName)
    }

    // MARK: - Directory Access Validation

    private func validateDirectoryAccess(_ directory: URL) -> Bool {
        // Test if we can actually write to the directory
        let testFile = directory.appendingPathComponent(".cub_access_test")
        do {
            try "test".write(to: testFile, atomically: true, encoding: .utf8)
            try FileManager.default.removeItem(at: testFile)
            print("✅ [PREFS] Directory access validated: \(directory.path)")
            return true
        } catch {
            print("❌ [PREFS] Directory not accessible: \(directory.path) - \(error)")
            return false
        }
    }

    func validateCurrentDirectoryAccess() -> Bool {
        return validateDirectoryAccess(screenshotSaveDirectory)
    }

    // MARK: - Migration Helpers

    private func migrateLegacyDirectory() {
        // Clear legacy storage to prevent future loading of inaccessible paths
        userDefaults.removeObject(forKey: screenshotDirectoryKey)
        print("🔄 [PREFS] Cleared legacy directory storage")
    }

    private func migrateLegacyToSecurityBookmark(_ legacyURL: URL) {
        // This won't work for directories not selected by user, but we try anyway
        // Real security bookmarks can only be created when user selects via NSOpenPanel
        print("🔄 [PREFS] Legacy directory accessible but cannot create security bookmark without user selection")
        print("💡 [PREFS] User will need to reselect directory in preferences for full sandbox compatibility")
    }

    // MARK: - Directory Status

    enum DirectoryAccessStatus {
        case accessible
        case needsUserSelection
        case error(String)
    }

    func getDirectoryAccessStatus() -> DirectoryAccessStatus {
        if validateCurrentDirectoryAccess() {
            return .accessible
        } else {
            // Check if we're using a directory that needs user selection
            let defaultDirectory = PreferencesManager.getDefaultScreenshotDirectory()
            if screenshotSaveDirectory.path != defaultDirectory.path {
                return .needsUserSelection
            } else {
                return .error("Cannot access default directory")
            }
        }
    }

    deinit {
        // Stop accessing security scoped resource when manager is deallocated
        screenshotSaveDirectory.stopAccessingSecurityScopedResource()
    }
}
