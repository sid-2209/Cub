//
//  GalleryDataController.swift
//  Cub
//
//  Created by sid on 21/09/24.
//  Extracted data management logic from GalleryView.swift for modular architecture
//

import Foundation
import SwiftUI
import CoreData

// MARK: - Data Management Protocol

protocol GalleryDataManaging: ObservableObject {
    var screenshots: [ScreenshotItem] { get }
    var categories: [Category] { get }
    var screenshotStats: ScreenshotStats { get }
    var isLoading: Bool { get }

    func loadData()
    func loadScreenshots(for sidebarItem: SidebarItem)
    func refreshData()
    func deleteScreenshots(_ screenshots: [ScreenshotItem])
    func exportScreenshots(_ screenshots: [ScreenshotItem], to destinationURL: URL)
}

// MARK: - Data Controller Implementation

class GalleryDataController: GalleryDataManaging {
    @Published var screenshots: [ScreenshotItem] = []
    @Published var categories: [Category] = []
    @Published var screenshotStats = ScreenshotStats.empty
    @Published var isLoading = true

    private let dataManager = ScreenshotDataManager.shared
    private let preferencesManager = PreferencesManager.shared

    init() {
        loadData()
    }

    // MARK: - Core Data Loading

    func loadData() {
        isLoading = true

        DispatchQueue.global(qos: .userInitiated).async {
            // Load categories and stats from Core Data
            let loadedCategories = self.dataManager.fetchAllCategories()
            let statsData = self.dataManager.getScreenshotStats()
            let stats = ScreenshotStats(
                total: statsData.total,
                todayCount: statsData.todayCount,
                weekCount: statsData.weekCount,
                monthCount: statsData.monthCount
            )

            DispatchQueue.main.async {
                self.categories = loadedCategories
                self.screenshotStats = stats
                print("📊 [DATA] Loaded \(loadedCategories.count) categories and stats: \(stats)")
            }
        }
    }

    func loadScreenshots(for sidebarItem: SidebarItem) {
        isLoading = true

        DispatchQueue.global(qos: .userInitiated).async {
            var coreDataScreenshots: [Screenshot] = []

            // Load from Core Data based on selected sidebar item
            switch sidebarItem {
            case .allScreenshots:
                coreDataScreenshots = self.dataManager.fetchAllScreenshots()
            case .recentScreenshots:
                coreDataScreenshots = self.dataManager.getRecentScreenshots(limit: 50)
            case .category(let category):
                coreDataScreenshots = self.dataManager.fetchScreenshots(in: category)
            case .contentType(let contentType):
                coreDataScreenshots = self.dataManager.getScreenshotsByContentType(contentType)
            }

            // Convert to ScreenshotItem and validate file existence
            var screenshotItems = coreDataScreenshots.compactMap { screenshot -> ScreenshotItem? in
                let item = ScreenshotItem(from: screenshot)

                // Check if the file still exists at the expected path
                if !FileManager.default.fileExists(atPath: item.url.path) {
                    print("⚠️ [DATA] File missing for Core Data entry: \(item.fileName)")

                    // Try to find the file by name in the screenshot directory
                    if let updatedURL = self.findMovedFile(originalName: item.fileName) {
                        print("✅ [DATA] Found renamed file: \(updatedURL.lastPathComponent)")
                        // Update Core Data with new path
                        self.dataManager.updateScreenshotPath(for: screenshot, newPath: updatedURL)
                        return ScreenshotItem(from: screenshot) // Return updated item
                    } else {
                        // File is completely missing, mark for cleanup
                        print("🗑️ [DATA] Marking missing file for cleanup: \(item.fileName)")
                        return nil
                    }
                }

                return item
            }

            // If no Core Data screenshots, fall back to file-based loading for backward compatibility
            if screenshotItems.isEmpty && sidebarItem == .allScreenshots {
                screenshotItems = self.loadLegacyScreenshots()
            }

            DispatchQueue.main.async {
                self.screenshots = screenshotItems
                self.isLoading = false
                print("🖼️ [DATA] Loaded \(screenshotItems.count) screenshots for \(sidebarItem.displayName)")
            }
        }
    }

    func refreshData() {
        loadData()
    }

    // MARK: - File Management

    private func findMovedFile(originalName: String) -> URL? {
        let directory = preferencesManager.screenshotSaveDirectory

        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.creationDateKey],
                options: [.skipsHiddenFiles]
            )

            // Look for files with similar names or same base name
            let baseName = (originalName as NSString).deletingPathExtension

            for url in fileURLs {
                let fileName = url.lastPathComponent
                let fileBaseName = (fileName as NSString).deletingPathExtension

                // Check if the base name matches (handles renamed files)
                if fileBaseName.contains(baseName) || baseName.contains(fileBaseName) {
                    return url
                }
            }
        } catch {
            print("❌ [DATA] Error searching for moved file: \(error)")
        }

        return nil
    }

    private func loadLegacyScreenshots() -> [ScreenshotItem] {
        let directory = preferencesManager.screenshotSaveDirectory

        guard FileManager.default.fileExists(atPath: directory.path) else {
            return []
        }

        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.creationDateKey, .fileSizeKey],
                options: [.skipsHiddenFiles]
            )

            let screenshotURLs = fileURLs.filter { url in
                let pathExtension = url.pathExtension.lowercased()
                return ["png", "jpg", "jpeg", "tiff", "gif", "bmp"].contains(pathExtension)
            }

            return screenshotURLs.map { ScreenshotItem(url: $0) }
        } catch {
            print("❌ [DATA] Error loading legacy screenshots: \(error)")
            return []
        }
    }

    // MARK: - Screenshot Operations

    func deleteScreenshots(_ screenshots: [ScreenshotItem]) {
        for screenshot in screenshots {
            if screenshot.isFromCoreData {
                // Find the Core Data Screenshot object by ID
                let allScreenshots = dataManager.fetchAllScreenshots()
                if let coreDataScreenshot = allScreenshots.first(where: { $0.id == screenshot.id }) {
                    // Delete the file from disk
                    do {
                        try FileManager.default.removeItem(at: screenshot.url)
                        print("🗑️ [DATA] Deleted file: \(screenshot.fileName)")
                    } catch {
                        print("❌ [DATA] Failed to delete file \(screenshot.fileName): \(error)")
                    }

                    // Delete from Core Data
                    dataManager.deleteScreenshot(coreDataScreenshot)
                }
            } else {
                // Legacy file-based screenshot
                do {
                    try FileManager.default.removeItem(at: screenshot.url)
                    print("🗑️ [DATA] Deleted legacy file: \(screenshot.fileName)")
                } catch {
                    print("❌ [DATA] Failed to delete legacy file \(screenshot.fileName): \(error)")
                }
            }
        }

        // Remove deleted screenshots from local array
        self.screenshots.removeAll { screenshot in
            screenshots.contains { $0.id == screenshot.id }
        }

        // Update stats
        let statsData = dataManager.getScreenshotStats()
        self.screenshotStats = ScreenshotStats(
            total: statsData.total,
            todayCount: statsData.todayCount,
            weekCount: statsData.weekCount,
            monthCount: statsData.monthCount
        )
    }

    func exportScreenshots(_ screenshots: [ScreenshotItem], to destinationURL: URL) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try FileManager.default.createDirectory(at: destinationURL, withIntermediateDirectories: true, attributes: nil)

                for screenshot in screenshots {
                    let destinationFileURL = destinationURL.appendingPathComponent(screenshot.fileName)

                    do {
                        try FileManager.default.copyItem(at: screenshot.url, to: destinationFileURL)
                        print("📤 [DATA] Exported: \(screenshot.fileName)")
                    } catch {
                        print("❌ [DATA] Failed to export \(screenshot.fileName): \(error)")
                    }
                }

                DispatchQueue.main.async {
                    print("✅ [DATA] Export completed for \(screenshots.count) screenshots")
                }
            } catch {
                print("❌ [DATA] Failed to create export directory: \(error)")
            }
        }
    }

    // MARK: - Statistics and Utilities

    func countScreenshots(for contentType: ScreenshotContentType) -> Int {
        return dataManager.getScreenshotsByContentType(contentType).count
    }

    func getAvailableSourceApps() -> [String] {
        let apps = screenshots.compactMap { $0.sourceAppName }.filter { !$0.isEmpty }
        return Array(Set(apps)).sorted()
    }

    func getAvailableTags() -> [String] {
        let tags = screenshots.flatMap { $0.tags }.filter { !$0.isEmpty }
        return Array(Set(tags)).sorted()
    }

    func getAvailableCategories() -> [String] {
        return categories.compactMap { $0.name }.sorted()
    }

    // MARK: - File System Monitoring

    func handleFileSystemChange() {
        // Reload screenshots when file system changes are detected
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Add a small delay to allow file operations to complete
            self.refreshData()
        }
    }
}

// MARK: - Data Controller Extensions

extension GalleryDataController {

    /// Shares screenshots using the system sharing service
    func shareScreenshots(_ screenshots: [ScreenshotItem]) {
        let urls = screenshots.map { $0.url }

        let sharingService = NSSharingServicePicker(items: urls)
        if let window = NSApplication.shared.keyWindow,
           let contentView = window.contentView {
            let rect = NSRect(x: contentView.bounds.midX, y: contentView.bounds.midY, width: 1, height: 1)
            sharingService.show(relativeTo: rect, of: contentView, preferredEdge: .minY)
        }
    }

    /// Quick Look preview for a screenshot
    func quickLookScreenshot(_ screenshot: ScreenshotItem) {
        NSWorkspace.shared.open(screenshot.url)
    }

    /// Updates screenshot metadata
    func updateScreenshotMetadata(_ screenshot: ScreenshotItem, category: Category?, tags: [String]) {
        guard screenshot.isFromCoreData else {
            return
        }

        let allScreenshots = dataManager.fetchAllScreenshots()
        guard let coreDataScreenshot = allScreenshots.first(where: { $0.id == screenshot.id }) else {
            return
        }

        // Update category
        coreDataScreenshot.category = category

        // Save the context
        do {
            try PersistenceController.shared.container.viewContext.save()
        } catch {
            print("❌ [DATA] Failed to save context: \(error)")
        }

        // Refresh the local data
        refreshData()
    }

    /// Bulk operations for screenshots
    func performBulkOperation(_ operation: BulkOperation, on screenshots: [ScreenshotItem]) {
        switch operation {
        case .delete:
            deleteScreenshots(screenshots)
        case .export(let destination):
            exportScreenshots(screenshots, to: destination)
        case .share:
            shareScreenshots(screenshots)
        case .categorize(let category):
            bulkCategorize(screenshots, to: category)
        case .tag(let tags):
            bulkTag(screenshots, with: tags)
        }
    }

    private func bulkCategorize(_ screenshots: [ScreenshotItem], to category: Category?) {
        let allScreenshots = dataManager.fetchAllScreenshots()
        for screenshot in screenshots where screenshot.isFromCoreData {
            if let coreDataScreenshot = allScreenshots.first(where: { $0.id == screenshot.id }) {
                coreDataScreenshot.category = category
            }
        }
        do {
            try PersistenceController.shared.container.viewContext.save()
        } catch {
            print("❌ [DATA] Failed to save context: \(error)")
        }
        refreshData()
    }

    private func bulkTag(_ screenshots: [ScreenshotItem], with tags: [String]) {
        let allScreenshots = dataManager.fetchAllScreenshots()
        for screenshot in screenshots where screenshot.isFromCoreData {
            if allScreenshots.first(where: { $0.id == screenshot.id }) != nil {
                // Note: Tag updating would require proper Tag entity handling
                // This is a simplified implementation
            }
        }
        do {
            try PersistenceController.shared.container.viewContext.save()
        } catch {
            print("❌ [DATA] Failed to save context: \(error)")
        }
        refreshData()
    }
}

// MARK: - Bulk Operations

enum BulkOperation {
    case delete
    case export(URL)
    case share
    case categorize(Category?)
    case tag([String])

    var displayName: String {
        switch self {
        case .delete: return "Delete"
        case .export: return "Export"
        case .share: return "Share"
        case .categorize: return "Categorize"
        case .tag: return "Tag"
        }
    }
}
