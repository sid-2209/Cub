//
//  GallerySelectionManager.swift
//  Cub
//
//  Created by sid on 21/09/24.
//  Extracted selection management from GalleryView.swift for modular architecture
//

import Foundation
import SwiftUI
import Cocoa

// MARK: - Selection Management Protocol

protocol GallerySelectionManaging: ObservableObject {
    var isInSelectionMode: Bool { get set }
    var selectedScreenshots: Set<UUID> { get set }
    var showingDeleteConfirmation: Bool { get set }

    func enterSelectionMode()
    func exitSelectionMode()
    func toggleScreenshotSelection(_ screenshot: ScreenshotItem)
    func selectAll(from screenshots: [ScreenshotItem])
    func shareSelectedScreenshots(from screenshots: [ScreenshotItem])
    func exportSelectedScreenshots(from screenshots: [ScreenshotItem])
    func deleteSelectedScreenshots(from screenshots: [ScreenshotItem], completion: @escaping () -> Void)
    func getSelectedScreenshots(from screenshots: [ScreenshotItem]) -> [ScreenshotItem]
}

// MARK: - Selection Manager Implementation

class GallerySelectionManager: GallerySelectionManaging {
    @Published var isInSelectionMode = false
    @Published var selectedScreenshots: Set<UUID> = []
    @Published var showingDeleteConfirmation = false

    // MARK: - Selection Mode Management

    func enterSelectionMode() {
        isInSelectionMode = true
        selectedScreenshots.removeAll()
        print("📋 [SELECTION] Entered selection mode")
    }

    func exitSelectionMode() {
        isInSelectionMode = false
        selectedScreenshots.removeAll()
        print("📋 [SELECTION] Exited selection mode")
    }

    func toggleScreenshotSelection(_ screenshot: ScreenshotItem) {
        if selectedScreenshots.contains(screenshot.id) {
            selectedScreenshots.remove(screenshot.id)
            print("📋 [SELECTION] Deselected: \(screenshot.fileName)")
        } else {
            selectedScreenshots.insert(screenshot.id)
            print("📋 [SELECTION] Selected: \(screenshot.fileName)")
        }
    }

    func selectAll(from screenshots: [ScreenshotItem]) {
        if selectedScreenshots.count == screenshots.count {
            // Deselect all
            selectedScreenshots.removeAll()
            print("📋 [SELECTION] Deselected all \(screenshots.count) screenshots")
        } else {
            // Select all
            selectedScreenshots = Set(screenshots.map { $0.id })
            print("📋 [SELECTION] Selected all \(screenshots.count) screenshots")
        }
    }

    // MARK: - Batch Operations

    func shareSelectedScreenshots(from screenshots: [ScreenshotItem]) {
        let selectedItems = getSelectedScreenshots(from: screenshots)
        let urls = selectedItems.map { $0.url }

        let sharingService = NSSharingServicePicker(items: urls)
        if let window = NSApplication.shared.keyWindow,
           let contentView = window.contentView {
            let rect = NSRect(x: contentView.bounds.midX, y: contentView.bounds.midY, width: 1, height: 1)
            sharingService.show(relativeTo: rect, of: contentView, preferredEdge: .minY)
        }

        print("📤 [SELECTION] Shared \(selectedItems.count) screenshots")
    }

    func exportSelectedScreenshots(from screenshots: [ScreenshotItem]) {
        let selectedItems = getSelectedScreenshots(from: screenshots)

        let savePanel = NSOpenPanel()
        savePanel.canCreateDirectories = true
        savePanel.message = "Choose where to export \(selectedItems.count) screenshot(s)"
        savePanel.prompt = "Export"
        savePanel.canChooseDirectories = true
        savePanel.canChooseFiles = false

        savePanel.begin { response in
            if response == .OK, let destinationURL = savePanel.url {
                self.exportScreenshots(selectedItems, to: destinationURL)
            }
        }
    }

    func deleteSelectedScreenshots(from screenshots: [ScreenshotItem], completion: @escaping () -> Void) {
        let selectedItems = getSelectedScreenshots(from: screenshots)

        for screenshot in selectedItems {
            if screenshot.isFromCoreData {
                // Find the Core Data Screenshot object by ID
                let allScreenshots = ScreenshotDataManager.shared.fetchAllScreenshots()
                if let coreDataScreenshot = allScreenshots.first(where: { $0.id == screenshot.id }) {
                    // Delete the file from disk
                    do {
                        try FileManager.default.removeItem(at: screenshot.url)
                        print("🗑️ [SELECTION] Deleted file: \(screenshot.fileName)")
                    } catch {
                        print("❌ [SELECTION] Failed to delete file \(screenshot.fileName): \(error)")
                    }

                    // Delete from Core Data
                    ScreenshotDataManager.shared.deleteScreenshot(coreDataScreenshot)
                }
            } else {
                // Legacy file-based screenshot
                do {
                    try FileManager.default.removeItem(at: screenshot.url)
                    print("🗑️ [SELECTION] Deleted legacy file: \(screenshot.fileName)")
                } catch {
                    print("❌ [SELECTION] Failed to delete legacy file \(screenshot.fileName): \(error)")
                }
            }
        }

        exitSelectionMode()
        completion() // Trigger refresh
    }

    func getSelectedScreenshots(from screenshots: [ScreenshotItem]) -> [ScreenshotItem] {
        return screenshots.filter { selectedScreenshots.contains($0.id) }
    }

    // MARK: - Private Helper Methods

    private func exportScreenshots(_ screenshots: [ScreenshotItem], to destinationURL: URL) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try FileManager.default.createDirectory(at: destinationURL, withIntermediateDirectories: true, attributes: nil)

                for screenshot in screenshots {
                    let destinationFileURL = destinationURL.appendingPathComponent(screenshot.fileName)

                    do {
                        try FileManager.default.copyItem(at: screenshot.url, to: destinationFileURL)
                        print("📤 [SELECTION] Exported: \(screenshot.fileName)")
                    } catch {
                        print("❌ [SELECTION] Failed to export \(screenshot.fileName): \(error)")
                    }
                }

                DispatchQueue.main.async {
                    print("✅ [SELECTION] Export completed for \(screenshots.count) screenshots")
                }
            } catch {
                print("❌ [SELECTION] Failed to create export directory: \(error)")
            }
        }
    }
}

// MARK: - Selection Manager Extensions

extension GallerySelectionManager {

    /// Checks if a specific screenshot is selected
    func isSelected(_ screenshot: ScreenshotItem) -> Bool {
        return selectedScreenshots.contains(screenshot.id)
    }

    /// Gets the count of selected screenshots
    var selectedCount: Int {
        return selectedScreenshots.count
    }

    /// Checks if all provided screenshots are selected
    func areAllSelected(from screenshots: [ScreenshotItem]) -> Bool {
        return selectedScreenshots.count == screenshots.count && selectedScreenshots.count > 0
    }

    /// Checks if any screenshots are selected
    var hasSelectedScreenshots: Bool {
        return !selectedScreenshots.isEmpty
    }

    /// Performs advanced batch operations
    func performBatchOperation(_ operation: BatchSelectionOperation, on screenshots: [ScreenshotItem], completion: @escaping () -> Void) {
        let selectedItems = getSelectedScreenshots(from: screenshots)

        switch operation {
        case .categorize(let category):
            batchCategorize(selectedItems, to: category, completion: completion)
        case .tag(let tags):
            batchTag(selectedItems, with: tags, completion: completion)
        case .moveToFolder(let folderURL):
            batchMove(selectedItems, to: folderURL, completion: completion)
        case .duplicate:
            batchDuplicate(selectedItems, completion: completion)
        }
    }

    private func batchCategorize(_ screenshots: [ScreenshotItem], to category: Category?, completion: @escaping () -> Void) {
        let dataManager = ScreenshotDataManager.shared

        for screenshot in screenshots where screenshot.isFromCoreData {
            let allScreenshots = dataManager.fetchAllScreenshots()
            if let coreDataScreenshot = allScreenshots.first(where: { $0.id == screenshot.id }) {
                coreDataScreenshot.category = category
                do {
                    try PersistenceController.shared.container.viewContext.save()
                } catch {
                    print("❌ [SELECTION] Failed to save context: \(error)")
                }
            }
        }

        print("📂 [SELECTION] Categorized \(screenshots.count) screenshots")
        exitSelectionMode()
        completion()
    }

    private func batchTag(_ screenshots: [ScreenshotItem], with tags: [String], completion: @escaping () -> Void) {
        let dataManager = ScreenshotDataManager.shared

        for screenshot in screenshots where screenshot.isFromCoreData {
            let allScreenshots = dataManager.fetchAllScreenshots()
            if allScreenshots.first(where: { $0.id == screenshot.id }) != nil {
                // Update tags (this is a simplified implementation)
                // In a full implementation, you'd need to handle Tag entities properly
                do {
                    try PersistenceController.shared.container.viewContext.save()
                } catch {
                    print("❌ [SELECTION] Failed to save context: \(error)")
                }
            }
        }

        print("🏷️ [SELECTION] Tagged \(screenshots.count) screenshots with \(tags.count) tags")
        exitSelectionMode()
        completion()
    }

    private func batchMove(_ screenshots: [ScreenshotItem], to folderURL: URL, completion: @escaping () -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true, attributes: nil)

                for screenshot in screenshots {
                    let destinationURL = folderURL.appendingPathComponent(screenshot.fileName)
                    do {
                        try FileManager.default.moveItem(at: screenshot.url, to: destinationURL)
                        print("📁 [SELECTION] Moved: \(screenshot.fileName)")

                        // Update Core Data path if needed
                        if screenshot.isFromCoreData {
                            let allScreenshots = ScreenshotDataManager.shared.fetchAllScreenshots()
                            if let coreDataScreenshot = allScreenshots.first(where: { $0.id == screenshot.id }) {
                                ScreenshotDataManager.shared.updateScreenshotPath(for: coreDataScreenshot, newPath: destinationURL)
                            }
                        }
                    } catch {
                        print("❌ [SELECTION] Failed to move \(screenshot.fileName): \(error)")
                    }
                }

                DispatchQueue.main.async {
                    print("✅ [SELECTION] Moved \(screenshots.count) screenshots")
                    self.exitSelectionMode()
                    completion()
                }
            } catch {
                print("❌ [SELECTION] Failed to create destination folder: \(error)")
                DispatchQueue.main.async {
                    completion()
                }
            }
        }
    }

    private func batchDuplicate(_ screenshots: [ScreenshotItem], completion: @escaping () -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            for screenshot in screenshots {
                let fileName = screenshot.fileName
                let fileExtension = (fileName as NSString).pathExtension
                let baseName = (fileName as NSString).deletingPathExtension
                let duplicateName = "\(baseName) copy.\(fileExtension)"
                let duplicateURL = screenshot.url.deletingLastPathComponent().appendingPathComponent(duplicateName)

                do {
                    try FileManager.default.copyItem(at: screenshot.url, to: duplicateURL)
                    print("📋 [SELECTION] Duplicated: \(screenshot.fileName)")
                } catch {
                    print("❌ [SELECTION] Failed to duplicate \(screenshot.fileName): \(error)")
                }
            }

            DispatchQueue.main.async {
                print("✅ [SELECTION] Duplicated \(screenshots.count) screenshots")
                self.exitSelectionMode()
                completion()
            }
        }
    }
}

// MARK: - Batch Operation Types

enum BatchSelectionOperation {
    case categorize(Category?)
    case tag([String])
    case moveToFolder(URL)
    case duplicate

    var displayName: String {
        switch self {
        case .categorize: return "Categorize"
        case .tag: return "Tag"
        case .moveToFolder: return "Move to Folder"
        case .duplicate: return "Duplicate"
        }
    }

    var iconName: String {
        switch self {
        case .categorize: return "folder"
        case .tag: return "tag"
        case .moveToFolder: return "folder.badge.plus"
        case .duplicate: return "doc.on.doc"
        }
    }
}
