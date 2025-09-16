//
//  PreferencesManager.swift
//  Cub
//
//  Created by Claude on 16/09/25.
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

    private init() {
        let defaultDirectory = PreferencesManager.getDefaultScreenshotDirectory()

        if let directoryData = userDefaults.data(forKey: screenshotDirectoryKey),
           let url = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSURL.self, from: directoryData) as URL? {
            self.screenshotSaveDirectory = url
        } else {
            self.screenshotSaveDirectory = defaultDirectory
        }

        if let formatString = userDefaults.string(forKey: screenshotFormatKey),
           let format = ScreenshotFormat(rawValue: formatString) {
            self.screenshotFormat = format
        }

        print("📁 [PREFS] Initialized with directory: \(screenshotSaveDirectory.path)")
        print("🖼️ [PREFS] Initialized with format: \(screenshotFormat.displayName)")
    }

    static func getDefaultScreenshotDirectory() -> URL {
        // Try Pictures directory first (now that we have proper entitlements)
        let picturesDirectory = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first
        let cubDirectory = picturesDirectory?.appendingPathComponent("Cub Screenshots")

        // Fallback to Documents if Pictures is not available
        if let cubDir = cubDirectory {
            return cubDir
        }

        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        return documentsDirectory?.appendingPathComponent("Cub Screenshots") ?? FileManager.default.temporaryDirectory.appendingPathComponent("Cub Screenshots")
    }

    func updateScreenshotDirectory(_ newDirectory: URL) {
        screenshotSaveDirectory = newDirectory

        do {
            let data = try NSKeyedArchiver.archivedData(withRootObject: newDirectory, requiringSecureCoding: true)
            userDefaults.set(data, forKey: screenshotDirectoryKey)
            print("✅ [PREFS] Updated screenshot directory to: \(newDirectory.path)")
        } catch {
            print("❌ [PREFS] Failed to save directory preference: \(error)")
        }
    }

    func updateScreenshotFormat(_ newFormat: ScreenshotFormat) {
        screenshotFormat = newFormat
        userDefaults.set(newFormat.rawValue, forKey: screenshotFormatKey)
        print("✅ [PREFS] Updated screenshot format to: \(newFormat.displayName)")
    }

    func ensureDirectoryExists() -> Bool {
        let fileManager = FileManager.default

        if !fileManager.fileExists(atPath: screenshotSaveDirectory.path) {
            do {
                try fileManager.createDirectory(at: screenshotSaveDirectory, withIntermediateDirectories: true, attributes: nil)
                print("📁 [PREFS] Created screenshot directory: \(screenshotSaveDirectory.path)")
                return true
            } catch {
                print("❌ [PREFS] Failed to create directory: \(error)")
                print("📁 [PREFS] Attempting fallback to Documents directory...")

                // Fallback to Documents directory
                let fallbackDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent("Cub Screenshots")

                if let fallbackDir = fallbackDirectory {
                    do {
                        try fileManager.createDirectory(at: fallbackDir, withIntermediateDirectories: true, attributes: nil)
                        screenshotSaveDirectory = fallbackDir
                        print("✅ [PREFS] Created fallback directory: \(fallbackDir.path)")
                        return true
                    } catch {
                        print("❌ [PREFS] Fallback directory creation failed: \(error)")
                    }
                }

                // Final fallback to temp directory
                let tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("Cub Screenshots")
                do {
                    try fileManager.createDirectory(at: tempDirectory, withIntermediateDirectories: true, attributes: nil)
                    screenshotSaveDirectory = tempDirectory
                    print("⚠️ [PREFS] Using temporary directory: \(tempDirectory.path)")
                    return true
                } catch {
                    print("❌ [PREFS] All directory creation attempts failed: \(error)")
                    return false
                }
            }
        }

        return true
    }

    func selectNewDirectory() {
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.allowsMultipleSelection = false
        openPanel.directoryURL = screenshotSaveDirectory
        openPanel.title = "Select Screenshot Save Directory"
        openPanel.prompt = "Choose"

        if openPanel.runModal() == .OK {
            if let selectedURL = openPanel.url {
                updateScreenshotDirectory(selectedURL)
            }
        }
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
}