//
//  GalleryModels.swift
//  Cub
//
//  Created by sid on 21/09/24.
//  Extracted data models from GalleryView.swift for modular architecture
//

import Foundation
import SwiftUI
import Cocoa

// MARK: - Core Data Models

struct ScreenshotItem: Identifiable {
    let id: UUID
    let url: URL
    let fileName: String
    let fileSize: String
    let dateCreated: Date
    let thumbnail: NSImage?
    let sourceAppName: String?
    let contentType: String?
    let category: String?
    let tags: [String]
    let isFromCoreData: Bool

    // Core Data initializer
    init(from screenshot: Screenshot) {
        self.id = screenshot.id ?? UUID()
        self.url = screenshot.filePath ?? URL(fileURLWithPath: "/tmp/unknown")
        self.fileName = screenshot.fileName ?? "Unknown"
        self.dateCreated = screenshot.captureDate ?? Date()
        self.sourceAppName = screenshot.sourceAppName
        self.contentType = screenshot.contentType
        self.category = screenshot.category?.name
        self.tags = (screenshot.tags?.allObjects as? [Tag])?.compactMap { $0.name } ?? []
        self.isFromCoreData = true

        // Format file size
        self.fileSize = ByteCountFormatter.string(fromByteCount: screenshot.fileSize, countStyle: .file)

        // Generate thumbnail
        self.thumbnail = Self.generateThumbnail(for: self.url)
    }

    // File-based initializer (for backward compatibility)
    init(url: URL) {
        self.id = UUID()
        self.url = url
        self.fileName = url.lastPathComponent
        self.sourceAppName = nil
        self.contentType = nil
        self.category = nil
        self.tags = []
        self.isFromCoreData = false

        // Get file attributes
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        self.dateCreated = attributes?[.creationDate] as? Date ?? Date()

        // Format file size
        if let fileSize = attributes?[.size] as? Int64 {
            self.fileSize = ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
        } else {
            self.fileSize = "Unknown"
        }

        // Generate thumbnail
        self.thumbnail = Self.generateThumbnail(for: url)
    }

    private static func generateThumbnail(for url: URL) -> NSImage? {
        guard let image = NSImage(contentsOf: url) else { return nil }

        let thumbnailSize = NSSize(width: 200, height: 150)
        let thumbnail = NSImage(size: thumbnailSize)

        thumbnail.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: thumbnailSize),
                  from: NSRect(origin: .zero, size: image.size),
                  operation: .copy,
                  fraction: 1.0)
        thumbnail.unlockFocus()

        return thumbnail
    }
}

// MARK: - Gallery Navigation Models

enum SortOrder: String, CaseIterable {
    case dateDescending = "Date (Newest First)"
    case dateAscending = "Date (Oldest First)"
    case nameAscending = "Name (A-Z)"
    case nameDescending = "Name (Z-A)"
    case sizeAscending = "Size (Smallest First)"
    case sizeDescending = "Size (Largest First)"
}

enum SidebarItem: Hashable {
    case allScreenshots
    case recentScreenshots
    case category(Category)
    case contentType(ScreenshotContentType)

    var displayName: String {
        switch self {
        case .allScreenshots:
            return "All Screenshots"
        case .recentScreenshots:
            return "Recent"
        case .category(let category):
            return category.name ?? "Unknown Category"
        case .contentType(let contentType):
            return contentType.displayName
        }
    }

    var iconName: String {
        switch self {
        case .allScreenshots:
            return "photo.on.rectangle.angled"
        case .recentScreenshots:
            return "clock"
        case .category(let category):
            return category.iconName ?? "folder"
        case .contentType(let contentType):
            return contentType.iconName
        }
    }
}

// MARK: - Filter Data Structures

struct ScreenshotFilters {
    var searchText: String = ""
    var dateRange: DateRange?
    var selectedApps: Set<String> = []
    var sizeRange: SizeRange?
    var selectedContentTypes: Set<String> = []
    var selectedTags: Set<String> = []
    var selectedCategories: Set<String> = []

    // Advanced Image Analysis Filters
    var selectedFileFormats: Set<FileFormat> = []
    var selectedResolutions: Set<ResolutionRange> = []
    var selectedOrientations: Set<ImageOrientation> = []
    var selectedAspectRatios: Set<AspectRatioRange> = []

    // Content Recognition Filters
    var containsText: Bool? = nil
    var selectedWindowTypes: Set<WindowType> = []
    var selectedCaptureTypes: Set<CaptureType> = []

    // Organization Filters
    var isFavorited: Bool? = nil
    var recentlyViewed: Bool? = nil

    var hasActiveFilters: Bool {
        !searchText.isEmpty ||
        dateRange != nil ||
        !selectedApps.isEmpty ||
        sizeRange != nil ||
        !selectedContentTypes.isEmpty ||
        !selectedTags.isEmpty ||
        !selectedCategories.isEmpty ||
        !selectedFileFormats.isEmpty ||
        !selectedResolutions.isEmpty ||
        !selectedOrientations.isEmpty ||
        !selectedAspectRatios.isEmpty ||
        containsText != nil ||
        !selectedWindowTypes.isEmpty ||
        !selectedCaptureTypes.isEmpty ||
        isFavorited != nil ||
        recentlyViewed != nil
    }

    var activeFilterCount: Int {
        var count = 0
        if !searchText.isEmpty { count += 1 }
        if dateRange != nil { count += 1 }
        if !selectedApps.isEmpty { count += 1 }
        if sizeRange != nil { count += 1 }
        if !selectedContentTypes.isEmpty { count += 1 }
        if !selectedTags.isEmpty { count += 1 }
        if !selectedCategories.isEmpty { count += 1 }
        if !selectedFileFormats.isEmpty { count += 1 }
        if !selectedResolutions.isEmpty { count += 1 }
        if !selectedOrientations.isEmpty { count += 1 }
        if !selectedAspectRatios.isEmpty { count += 1 }
        if containsText != nil { count += 1 }
        if !selectedWindowTypes.isEmpty { count += 1 }
        if !selectedCaptureTypes.isEmpty { count += 1 }
        if isFavorited != nil { count += 1 }
        if recentlyViewed != nil { count += 1 }
        return count
    }

    mutating func clear() {
        searchText = ""
        dateRange = nil
        selectedApps.removeAll()
        sizeRange = nil
        selectedContentTypes.removeAll()
        selectedTags.removeAll()
        selectedCategories.removeAll()
        selectedFileFormats.removeAll()
        selectedResolutions.removeAll()
        selectedOrientations.removeAll()
        selectedAspectRatios.removeAll()
        containsText = nil
        selectedWindowTypes.removeAll()
        selectedCaptureTypes.removeAll()
        isFavorited = nil
        recentlyViewed = nil
    }
}

// MARK: - Date Range Models

struct DateRange {
    let start: Date
    let end: Date
    let preset: DatePreset?

    enum DatePreset: String, CaseIterable {
        case today = "Today"
        case yesterday = "Yesterday"
        case thisWeek = "This Week"
        case lastWeek = "Last Week"
        case thisMonth = "This Month"
        case lastMonth = "Last Month"
        case last7Days = "Last 7 Days"
        case last30Days = "Last 30 Days"
        case custom = "Custom Range"

        var dateRange: DateRange? {
            let calendar = Calendar.current
            let now = Date()

            switch self {
            case .today:
                let startOfDay = calendar.startOfDay(for: now)
                let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? now
                return DateRange(start: startOfDay, end: endOfDay, preset: self)
            case .yesterday:
                let yesterday = calendar.date(byAdding: .day, value: -1, to: now) ?? now
                let startOfDay = calendar.startOfDay(for: yesterday)
                let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? now
                return DateRange(start: startOfDay, end: endOfDay, preset: self)
            case .thisWeek:
                let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
                let endOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.end ?? now
                return DateRange(start: startOfWeek, end: endOfWeek, preset: self)
            case .lastWeek:
                let lastWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: now) ?? now
                let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: lastWeek)?.start ?? now
                let endOfWeek = calendar.dateInterval(of: .weekOfYear, for: lastWeek)?.end ?? now
                return DateRange(start: startOfWeek, end: endOfWeek, preset: self)
            case .thisMonth:
                let startOfMonth = calendar.dateInterval(of: .month, for: now)?.start ?? now
                let endOfMonth = calendar.dateInterval(of: .month, for: now)?.end ?? now
                return DateRange(start: startOfMonth, end: endOfMonth, preset: self)
            case .lastMonth:
                let lastMonth = calendar.date(byAdding: .month, value: -1, to: now) ?? now
                let startOfMonth = calendar.dateInterval(of: .month, for: lastMonth)?.start ?? now
                let endOfMonth = calendar.dateInterval(of: .month, for: lastMonth)?.end ?? now
                return DateRange(start: startOfMonth, end: endOfMonth, preset: self)
            case .last7Days:
                let start = calendar.date(byAdding: .day, value: -7, to: now) ?? now
                return DateRange(start: start, end: now, preset: self)
            case .last30Days:
                let start = calendar.date(byAdding: .day, value: -30, to: now) ?? now
                return DateRange(start: start, end: now, preset: self)
            case .custom:
                return nil // Will be handled separately
            }
        }
    }
}

// MARK: - Size Range Models

struct SizeRange {
    let minSize: Int64
    let maxSize: Int64
    let preset: SizePreset?

    enum SizePreset: String, CaseIterable {
        case tiny = "Tiny (< 100 KB)"
        case small = "Small (100 KB - 1 MB)"
        case medium = "Medium (1 MB - 10 MB)"
        case large = "Large (10 MB - 100 MB)"
        case huge = "Huge (> 100 MB)"
        case custom = "Custom Range"

        var sizeRange: SizeRange? {
            switch self {
            case .tiny:
                return SizeRange(minSize: 0, maxSize: 100 * 1024, preset: self) // < 100 KB
            case .small:
                return SizeRange(minSize: 100 * 1024, maxSize: 1024 * 1024, preset: self) // 100 KB - 1 MB
            case .medium:
                return SizeRange(minSize: 1024 * 1024, maxSize: 10 * 1024 * 1024, preset: self) // 1 MB - 10 MB
            case .large:
                return SizeRange(minSize: 10 * 1024 * 1024, maxSize: 100 * 1024 * 1024, preset: self) // 10 MB - 100 MB
            case .huge:
                return SizeRange(minSize: 100 * 1024 * 1024, maxSize: Int64.max, preset: self) // > 100 MB
            case .custom:
                return nil // Will be handled separately
            }
        }
    }
}


// MARK: - Advanced Filter Enums

enum FileFormat: String, CaseIterable, DisplayNameProvider {
    case png = "PNG"
    case jpeg = "JPEG"
    case gif = "GIF"
    case tiff = "TIFF"
    case bmp = "BMP"
    case webp = "WebP"

    var displayName: String { rawValue }
}

enum ResolutionRange: String, CaseIterable, DisplayNameProvider {
    case sd = "SD (< 720p)"
    case hd = "HD (720p)"
    case fullHD = "Full HD (1080p)"
    case quadHD = "Quad HD (1440p)"
    case fourK = "4K (2160p)"
    case retina = "Retina"
    case ultraWide = "Ultra Wide"

    var displayName: String { rawValue }

    var minPixels: Int {
        switch self {
        case .sd: return 0
        case .hd: return 921_600  // 1280x720
        case .fullHD: return 2_073_600  // 1920x1080
        case .quadHD: return 3_686_400  // 2560x1440
        case .fourK: return 8_294_400  // 3840x2160
        case .retina: return 4_000_000  // Approximate
        case .ultraWide: return 3_440_000  // 3440x1440
        }
    }
}

enum ImageOrientation: String, CaseIterable, DisplayNameProvider {
    case landscape = "Landscape"
    case portrait = "Portrait"
    case square = "Square"

    var displayName: String { rawValue }
}

enum AspectRatioRange: String, CaseIterable, DisplayNameProvider {
    case square = "Square (1:1)"
    case standard = "Standard (4:3)"
    case widescreen = "Widescreen (16:9)"
    case ultrawide = "Ultrawide (21:9)"
    case portrait = "Portrait (3:4)"
    case mobile = "Mobile (9:16)"

    var displayName: String { rawValue }

    var targetRatio: Double {
        switch self {
        case .square: return 1.0
        case .standard: return 4.0/3.0
        case .widescreen: return 16.0/9.0
        case .ultrawide: return 21.0/9.0
        case .portrait: return 3.0/4.0
        case .mobile: return 9.0/16.0
        }
    }
}

enum WindowType: String, CaseIterable, DisplayNameProvider {
    case browser = "Web Browser"
    case terminal = "Terminal"
    case codeEditor = "Code Editor"
    case designTool = "Design Tool"
    case textEditor = "Text Editor"
    case systemApp = "System App"
    case thirdParty = "Third Party"

    var displayName: String { rawValue }
}

enum CaptureType: String, CaseIterable, DisplayNameProvider {
    case fullScreen = "Full Screen"
    case windowCapture = "Window"
    case regionCapture = "Region"
    case menuCapture = "Menu"

    var displayName: String { rawValue }
}

// MARK: - Statistics Models

struct ScreenshotStats {
    let total: Int
    let todayCount: Int
    let weekCount: Int
    let monthCount: Int

    static let empty = ScreenshotStats(total: 0, todayCount: 0, weekCount: 0, monthCount: 0)
}

// MARK: - File Extensions

extension URL {
    var fileSize: Int64 {
        do {
            let resourceValues = try resourceValues(forKeys: [.fileSizeKey])
            return Int64(resourceValues.fileSize ?? 0)
        } catch {
            return 0
        }
    }
}

// MARK: - File System Monitor

class FileSystemMonitor: ObservableObject {
    private var fileSystemMonitor: DispatchSourceFileSystemObject?
    private var changeHandler: (() -> Void)?

    func startMonitoring(directory: URL, onChange: @escaping () -> Void) {
        changeHandler = onChange

        guard FileManager.default.fileExists(atPath: directory.path) else {
            print("📁 [MONITOR] Directory doesn't exist: \(directory.path)")
            return
        }

        let fileDescriptor = open(directory.path, O_EVTONLY)
        guard fileDescriptor >= 0 else {
            print("❌ [MONITOR] Failed to open directory for monitoring")
            return
        }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .delete, .rename],
            queue: DispatchQueue.global(qos: .utility)
        )

        source.setEventHandler { [weak self] in
            DispatchQueue.main.async {
                print("📁 [MONITOR] File system change detected, refreshing...")
                self?.changeHandler?()
            }
        }

        source.setCancelHandler {
            close(fileDescriptor)
        }

        fileSystemMonitor = source
        source.resume()

        print("📁 [MONITOR] Started monitoring directory: \(directory.path)")
    }

    func stopMonitoring() {
        fileSystemMonitor?.cancel()
        fileSystemMonitor = nil
        changeHandler = nil
        print("📁 [MONITOR] Stopped file system monitoring")
    }

    deinit {
        stopMonitoring()
    }
}
