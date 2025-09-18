//
//  ScreenshotDataManager.swift
//  Cub
//
//  Created by sid on 17/09/25.
//

import CoreData
import Foundation
import AppKit

// MARK: - Screenshot Content Types

enum ScreenshotContentType: String, CaseIterable {
    case fullScreen = "fullscreen"
    case windowCapture = "window"
    case selection = "selection"
    case menuCapture = "menu"
    case mobileUI = "mobile"
    case webContent = "web"
    case codeEditor = "code"
    case design = "design"
    case document = "document"
    case unknown = "unknown"

    var displayName: String {
        switch self {
        case .fullScreen: return "Full Screen"
        case .windowCapture: return "Window"
        case .selection: return "Selection"
        case .menuCapture: return "Menu"
        case .mobileUI: return "Mobile UI"
        case .webContent: return "Web Content"
        case .codeEditor: return "Code"
        case .design: return "Design"
        case .document: return "Document"
        case .unknown: return "Unknown"
        }
    }

    var iconName: String {
        switch self {
        case .fullScreen: return "rectangle.inset.filled"
        case .windowCapture: return "macwindow"
        case .selection: return "rectangle.dashed"
        case .menuCapture: return "menubar.rectangle"
        case .mobileUI: return "iphone"
        case .webContent: return "globe"
        case .codeEditor: return "chevron.left.forwardslash.chevron.right"
        case .design: return "paintbrush"
        case .document: return "doc.text"
        case .unknown: return "photo"
        }
    }
}

// MARK: - Category Types

enum CategoryType: String, CaseIterable {
    case app = "app"
    case time = "time"
    case content = "content"
    case custom = "custom"

    var displayName: String {
        switch self {
        case .app: return "Source App"
        case .time: return "Time Period"
        case .content: return "Content Type"
        case .custom: return "Custom"
        }
    }
}

// MARK: - Screenshot Data Manager

class ScreenshotDataManager: ObservableObject {
    static let shared = ScreenshotDataManager()

    private let persistenceController = PersistenceController.shared

    private var context: NSManagedObjectContext {
        persistenceController.container.viewContext
    }

    private init() {
        setupDefaultCategories()
    }

    // MARK: - Screenshot Management

    func createScreenshot(from capturedImage: CapturedImage, sourceApp: (bundleID: String, name: String, icon: Data?)? = nil) -> Screenshot? {
        let screenshot = Screenshot(context: context)

        // Basic properties
        screenshot.id = UUID()
        screenshot.filePath = capturedImage.filePath
        screenshot.fileName = capturedImage.fileName
        screenshot.captureDate = capturedImage.captureDate
        screenshot.fileSize = capturedImage.fileSize
        screenshot.width = Int32(capturedImage.dimensions.width)
        screenshot.height = Int32(capturedImage.dimensions.height)
        screenshot.lastAccessDate = Date()

        // Source app information
        if let sourceApp = sourceApp {
            screenshot.sourceAppBundleID = sourceApp.bundleID
            screenshot.sourceAppName = sourceApp.name
            screenshot.sourceAppIcon = sourceApp.icon
        }

        // Analyze and set content type
        screenshot.contentType = analyzeContentType(for: capturedImage, sourceApp: sourceApp).rawValue

        // Auto-categorize
        assignCategory(to: screenshot)

        do {
            try context.save()
            print("📸 [DATA] Screenshot saved: \(screenshot.fileName ?? "unknown")")
            return screenshot
        } catch {
            print("❌ [DATA] Failed to save screenshot: \(error)")
            return nil
        }
    }

    func fetchAllScreenshots() -> [Screenshot] {
        let request: NSFetchRequest<Screenshot> = Screenshot.fetchRequest()
        request.predicate = NSPredicate(format: "isMarkedDeleted == NO")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Screenshot.captureDate, ascending: false)]

        do {
            return try context.fetch(request)
        } catch {
            print("❌ [DATA] Failed to fetch screenshots: \(error)")
            return []
        }
    }

    func fetchScreenshots(in category: Category) -> [Screenshot] {
        let request: NSFetchRequest<Screenshot> = Screenshot.fetchRequest()
        request.predicate = NSPredicate(format: "category == %@ AND isMarkedDeleted == NO", category)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Screenshot.captureDate, ascending: false)]

        do {
            return try context.fetch(request)
        } catch {
            print("❌ [DATA] Failed to fetch screenshots for category: \(error)")
            return []
        }
    }

    func fetchScreenshots(with tag: Tag) -> [Screenshot] {
        let request: NSFetchRequest<Screenshot> = Screenshot.fetchRequest()
        request.predicate = NSPredicate(format: "ANY tags == %@ AND isMarkedDeleted == NO", tag)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Screenshot.captureDate, ascending: false)]

        do {
            return try context.fetch(request)
        } catch {
            print("❌ [DATA] Failed to fetch screenshots for tag: \(error)")
            return []
        }
    }

    func searchScreenshots(query: String) -> [Screenshot] {
        guard !query.isEmpty else { return fetchAllScreenshots() }

        let request: NSFetchRequest<Screenshot> = Screenshot.fetchRequest()
        request.predicate = NSPredicate(format: "(fileName CONTAINS[cd] %@ OR sourceAppName CONTAINS[cd] %@ OR notes CONTAINS[cd] %@) AND isMarkedDeleted == NO",
                                      query, query, query)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Screenshot.lastAccessDate, ascending: false)]

        do {
            return try context.fetch(request)
        } catch {
            print("❌ [DATA] Failed to search screenshots: \(error)")
            return []
        }
    }

    func deleteScreenshot(_ screenshot: Screenshot, permanently: Bool = false) {
        if permanently {
            context.delete(screenshot)
        } else {
            screenshot.isMarkedDeleted = true
        }

        do {
            try context.save()
            print("🗑️ [DATA] Screenshot \(permanently ? "permanently deleted" : "moved to trash"): \(screenshot.fileName ?? "unknown")")
        } catch {
            print("❌ [DATA] Failed to delete screenshot: \(error)")
        }
    }

    func updateLastAccessDate(for screenshot: Screenshot) {
        screenshot.lastAccessDate = Date()

        do {
            try context.save()
        } catch {
            print("❌ [DATA] Failed to update access date: \(error)")
        }
    }

    // MARK: - Category Management

    func createCategory(name: String, type: CategoryType, color: String? = nil, icon: String? = nil) -> Category? {
        let category = Category(context: context)
        category.id = UUID()
        category.name = name
        category.type = type.rawValue
        category.colorHex = color
        category.iconName = icon
        category.isSystemCategory = false
        category.createdDate = Date()
        category.sortOrder = Int32(fetchAllCategories().count)

        do {
            try context.save()
            print("📁 [DATA] Category created: \(name)")
            return category
        } catch {
            print("❌ [DATA] Failed to create category: \(error)")
            return nil
        }
    }

    func fetchAllCategories() -> [Category] {
        let request: NSFetchRequest<Category> = Category.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \Category.isSystemCategory, ascending: false),
            NSSortDescriptor(keyPath: \Category.sortOrder, ascending: true)
        ]

        do {
            return try context.fetch(request)
        } catch {
            print("❌ [DATA] Failed to fetch categories: \(error)")
            return []
        }
    }

    func fetchCategories(ofType type: CategoryType) -> [Category] {
        let request: NSFetchRequest<Category> = Category.fetchRequest()
        request.predicate = NSPredicate(format: "type == %@", type.rawValue)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Category.sortOrder, ascending: true)]

        do {
            return try context.fetch(request)
        } catch {
            print("❌ [DATA] Failed to fetch categories of type \(type): \(error)")
            return []
        }
    }

    // MARK: - Tag Management

    func createTag(name: String, color: String? = nil) -> Tag? {
        // Check if tag already exists
        if let existingTag = fetchTag(named: name) {
            return existingTag
        }

        let tag = Tag(context: context)
        tag.id = UUID()
        tag.name = name
        tag.colorHex = color
        tag.createdDate = Date()
        tag.usageCount = 0

        do {
            try context.save()
            print("🏷️ [DATA] Tag created: \(name)")
            return tag
        } catch {
            print("❌ [DATA] Failed to create tag: \(error)")
            return nil
        }
    }

    func fetchTag(named name: String) -> Tag? {
        let request: NSFetchRequest<Tag> = Tag.fetchRequest()
        request.predicate = NSPredicate(format: "name ==[cd] %@", name)
        request.fetchLimit = 1

        do {
            return try context.fetch(request).first
        } catch {
            print("❌ [DATA] Failed to fetch tag: \(error)")
            return nil
        }
    }

    func fetchAllTags() -> [Tag] {
        let request: NSFetchRequest<Tag> = Tag.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Tag.usageCount, ascending: false)]

        do {
            return try context.fetch(request)
        } catch {
            print("❌ [DATA] Failed to fetch tags: \(error)")
            return []
        }
    }

    func addTag(_ tag: Tag, to screenshot: Screenshot) {
        screenshot.addToTags(tag)
        tag.usageCount += 1

        do {
            try context.save()
            print("🏷️ [DATA] Tag '\(tag.name ?? "unknown")' added to screenshot")
        } catch {
            print("❌ [DATA] Failed to add tag to screenshot: \(error)")
        }
    }

    // MARK: - Smart Organization

    private func analyzeContentType(for capturedImage: CapturedImage, sourceApp: (bundleID: String, name: String, icon: Data?)?) -> ScreenshotContentType {
        let dimensions = capturedImage.dimensions
        let aspectRatio = dimensions.width / dimensions.height

        print("🔍 [CONTENT-ANALYSIS] Analyzing screenshot content type...")
        print("   Dimensions: \(Int(dimensions.width))×\(Int(dimensions.height))")
        print("   Aspect ratio: \(String(format: "%.2f", aspectRatio))")
        if let sourceApp = sourceApp {
            print("   Source app: \(sourceApp.name) (\(sourceApp.bundleID))")
        }

        // Primary analysis: Source app-based detection (most reliable)
        if let bundleID = sourceApp?.bundleID.lowercased() {
            let detectedType: ScreenshotContentType?

            switch bundleID {
            // Development tools
            case let id where id.contains("xcode") || id.contains("com.apple.dt"):
                detectedType = .codeEditor
            case let id where id.contains("vscode") || id.contains("sublimetext") ||
                              id.contains("jetbrains") || id.contains("atom") ||
                              id.contains("textmate") || id.contains("brackets"):
                detectedType = .codeEditor

            // Design tools
            case let id where id.contains("figma") || id.contains("sketch") ||
                              id.contains("photoshop") || id.contains("illustrator") ||
                              id.contains("indesign") || id.contains("affinity"):
                detectedType = .design

            // Web browsers
            case let id where id.contains("safari") || id.contains("chrome") ||
                              id.contains("firefox") || id.contains("edge") ||
                              id.contains("opera") || id.contains("brave"):
                detectedType = .webContent

            // Mobile simulators and development
            case let id where id.contains("simulator") || id.contains("xcode.simulator") ||
                              id.contains("android"):
                detectedType = .mobileUI

            // Document and productivity apps
            case let id where id.contains("pages") || id.contains("word") ||
                              id.contains("google.docs") || id.contains("notion") ||
                              id.contains("bear") || id.contains("obsidian") ||
                              id.contains("typora") || id.contains("ulysses"):
                detectedType = .document

            default:
                detectedType = nil
            }

            if let type = detectedType {
                print("✅ [CONTENT-ANALYSIS] App-based detection: \(type.displayName)")
                return type
            }
        }

        // Secondary analysis: Dimension-based detection
        let screenSize = NSScreen.main?.frame.size ?? NSSize(width: 1920, height: 1080)

        // Full screen detection (within 3% tolerance for better accuracy)
        let widthTolerance = abs(dimensions.width - screenSize.width) / screenSize.width
        let heightTolerance = abs(dimensions.height - screenSize.height) / screenSize.height
        if widthTolerance < 0.03 && heightTolerance < 0.03 {
            print("✅ [CONTENT-ANALYSIS] Dimension-based detection: Full Screen")
            return .fullScreen
        }

        // Menu capture detection (small dimensions with specific characteristics)
        if dimensions.width < 400 && dimensions.height < 200 {
            print("✅ [CONTENT-ANALYSIS] Dimension-based detection: Menu Capture")
            return .menuCapture
        }

        // Mobile UI detection (portrait orientation with mobile-like dimensions)
        if aspectRatio <= 0.75 && (dimensions.width <= 600 || dimensions.height <= 1200) {
            print("✅ [CONTENT-ANALYSIS] Dimension-based detection: Mobile UI")
            return .mobileUI
        }

        // Document detection (tall, narrow aspect ratio typical of documents)
        if aspectRatio < 0.7 && dimensions.height > 800 {
            print("✅ [CONTENT-ANALYSIS] Dimension-based detection: Document")
            return .document
        }

        // Window capture detection (rectangular, reasonably sized selections)
        if aspectRatio >= 0.75 && aspectRatio <= 2.5 &&
           dimensions.width >= 400 && dimensions.height >= 300 &&
           (widthTolerance > 0.1 || heightTolerance > 0.1) {
            print("✅ [CONTENT-ANALYSIS] Dimension-based detection: Window Capture")
            return .windowCapture
        }

        // Default to selection for everything else
        print("✅ [CONTENT-ANALYSIS] Default fallback: Selection")
        return .selection
    }

    private func assignCategory(to screenshot: Screenshot) {
        // Smart categorization priority:
        // 1. Time-based categories (recent screenshots get time categories)
        // 2. App-based categories (if app source is available)
        // 3. Content-based categories (fallback)

        // First, try time-based categorization for recent screenshots
        if let timeCategory = findTimeBasedCategory(for: screenshot.captureDate) {
            screenshot.category = timeCategory
            print("📅 [CATEGORIZATION] Assigned time-based category: \(timeCategory.name ?? "unknown")")
            return
        }

        // Try to find or create an app-based category
        if let appName = screenshot.sourceAppName {
            let category = findOrCreateAppCategory(for: appName, bundleID: screenshot.sourceAppBundleID)
            screenshot.category = category
            print("📱 [CATEGORIZATION] Assigned app-based category: \(category.name ?? "unknown")")
        } else {
            // Fallback to content type category
            let contentType = ScreenshotContentType(rawValue: screenshot.contentType ?? "unknown") ?? .unknown
            let category = findOrCreateContentCategory(for: contentType)
            screenshot.category = category
            print("🏷️ [CATEGORIZATION] Assigned content-based category: \(category.name ?? "unknown")")
        }
    }

    private func findOrCreateAppCategory(for appName: String, bundleID: String?) -> Category {
        // Try to find existing category
        let request: NSFetchRequest<Category> = Category.fetchRequest()
        request.predicate = NSPredicate(format: "name == %@ AND type == %@", appName, CategoryType.app.rawValue)
        request.fetchLimit = 1

        do {
            if let existingCategory = try context.fetch(request).first {
                return existingCategory
            }
        } catch {
            print("❌ [DATA] Failed to search for existing app category: \(error)")
        }

        // Create new category
        let category = Category(context: context)
        category.id = UUID()
        category.name = appName
        category.type = CategoryType.app.rawValue
        category.isSystemCategory = true
        category.createdDate = Date()
        category.sortOrder = Int32(fetchCategories(ofType: .app).count)

        // Set icon based on app
        if let bundleID = bundleID {
            category.iconName = getIconName(for: bundleID)
        }

        do {
            try context.save()
            print("📁 [DATA] Auto-created app category: \(appName)")
        } catch {
            print("❌ [DATA] Failed to create app category: \(error)")
        }

        return category
    }

    private func findOrCreateContentCategory(for contentType: ScreenshotContentType) -> Category {
        // Try to find existing category
        let request: NSFetchRequest<Category> = Category.fetchRequest()
        request.predicate = NSPredicate(format: "name == %@ AND type == %@", contentType.displayName, CategoryType.content.rawValue)
        request.fetchLimit = 1

        do {
            if let existingCategory = try context.fetch(request).first {
                return existingCategory
            }
        } catch {
            print("❌ [DATA] Failed to search for existing content category: \(error)")
        }

        // Create new category
        let category = Category(context: context)
        category.id = UUID()
        category.name = contentType.displayName
        category.type = CategoryType.content.rawValue
        category.isSystemCategory = true
        category.createdDate = Date()
        category.iconName = contentType.iconName
        category.sortOrder = Int32(fetchCategories(ofType: .content).count)

        do {
            try context.save()
            print("📁 [DATA] Auto-created content category: \(contentType.displayName)")
        } catch {
            print("❌ [DATA] Failed to create content category: \(error)")
        }

        return category
    }

    private func getIconName(for bundleID: String) -> String {
        switch bundleID.lowercased() {
        case let id where id.contains("xcode"): return "hammer"
        case let id where id.contains("safari"): return "safari"
        case let id where id.contains("chrome"): return "globe"
        case let id where id.contains("figma"): return "pencil.and.outline"
        case let id where id.contains("sketch"): return "paintbrush"
        case let id where id.contains("simulator"): return "iphone"
        default: return "app"
        }
    }

    private func findTimeBasedCategory(for captureDate: Date?) -> Category? {
        guard let captureDate = captureDate else { return nil }

        let calendar = Calendar.current
        let now = Date()

        // Define time periods
        let timeCategory: String?
        if calendar.isDateInToday(captureDate) {
            timeCategory = "Today"
        } else if calendar.isDateInYesterday(captureDate) {
            timeCategory = "Yesterday"
        } else if calendar.isDate(captureDate, equalTo: now, toGranularity: .weekOfYear) {
            timeCategory = "This Week"
        } else if calendar.isDate(captureDate, equalTo: now, toGranularity: .month) {
            timeCategory = "This Month"
        } else {
            return nil // No time-based category for older screenshots
        }

        // Find existing time category
        let request: NSFetchRequest<Category> = Category.fetchRequest()
        request.predicate = NSPredicate(format: "name == %@ AND type == %@", timeCategory!, CategoryType.time.rawValue)
        request.fetchLimit = 1

        do {
            if let existingCategory = try context.fetch(request).first {
                return existingCategory
            }
        } catch {
            print("❌ [DATA] Failed to fetch time category: \(error)")
        }

        // Category should exist from setup, but create if missing
        return createTimeCategory(named: timeCategory!)
    }

    private func createTimeCategory(named name: String) -> Category? {
        let iconName: String
        switch name {
        case "Today": iconName = "clock"
        case "Yesterday": iconName = "clock.arrow.circlepath"
        case "This Week": iconName = "calendar"
        case "This Month": iconName = "calendar.circle"
        default: iconName = "clock"
        }

        let category = Category(context: context)
        category.id = UUID()
        category.name = name
        category.type = CategoryType.time.rawValue
        category.isSystemCategory = true
        category.iconName = iconName
        category.createdDate = Date()
        category.sortOrder = Int32(fetchCategories(ofType: .time).count)

        do {
            try context.save()
            print("📅 [DATA] Created time category: \(name)")
            return category
        } catch {
            print("❌ [DATA] Failed to create time category: \(error)")
            return nil
        }
    }

    private func setupDefaultCategories() {
        // Check if default categories already exist
        let existingCategories = fetchAllCategories()
        if !existingCategories.isEmpty {
            return
        }

        // Create default time-based categories
        let timeCategories = [
            ("Today", "clock"),
            ("Yesterday", "clock.arrow.circlepath"),
            ("This Week", "calendar"),
            ("This Month", "calendar.circle")
        ]

        for (name, icon) in timeCategories {
            let category = Category(context: context)
            category.id = UUID()
            category.name = name
            category.type = CategoryType.time.rawValue
            category.isSystemCategory = true
            category.iconName = icon
            category.createdDate = Date()
            category.sortOrder = Int32(timeCategories.firstIndex { $0.0 == name } ?? 0)
        }

        do {
            try context.save()
            print("📁 [DATA] Default categories created")
        } catch {
            print("❌ [DATA] Failed to create default categories: \(error)")
        }
    }

    // MARK: - Smart Collection Methods

    func getSmartCollections() -> [Category] {
        // Return categories that can serve as smart collections
        return fetchCategories(ofType: .time) + fetchCategories(ofType: .app) + fetchCategories(ofType: .content)
    }

    func getRecentScreenshots(limit: Int = 20) -> [Screenshot] {
        let request: NSFetchRequest<Screenshot> = Screenshot.fetchRequest()
        request.predicate = NSPredicate(format: "isMarkedDeleted == NO")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Screenshot.captureDate, ascending: false)]
        request.fetchLimit = limit

        do {
            return try context.fetch(request)
        } catch {
            print("❌ [DATA] Failed to fetch recent screenshots: \(error)")
            return []
        }
    }

    func getScreenshotsByContentType(_ contentType: ScreenshotContentType) -> [Screenshot] {
        let request: NSFetchRequest<Screenshot> = Screenshot.fetchRequest()
        request.predicate = NSPredicate(format: "contentType == %@ AND isMarkedDeleted == NO", contentType.rawValue)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Screenshot.captureDate, ascending: false)]

        do {
            return try context.fetch(request)
        } catch {
            print("❌ [DATA] Failed to fetch screenshots by content type: \(error)")
            return []
        }
    }

    func getScreenshotStats() -> (total: Int, todayCount: Int, weekCount: Int, monthCount: Int) {
        let calendar = Calendar.current
        let now = Date()

        let allRequest: NSFetchRequest<Screenshot> = Screenshot.fetchRequest()
        allRequest.predicate = NSPredicate(format: "isMarkedDeleted == NO")

        let todayRequest: NSFetchRequest<Screenshot> = Screenshot.fetchRequest()
        let startOfDay = calendar.startOfDay(for: now)
        todayRequest.predicate = NSPredicate(format: "captureDate >= %@ AND isMarkedDeleted == NO", startOfDay as NSDate)

        let weekRequest: NSFetchRequest<Screenshot> = Screenshot.fetchRequest()
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        weekRequest.predicate = NSPredicate(format: "captureDate >= %@ AND isMarkedDeleted == NO", startOfWeek as NSDate)

        let monthRequest: NSFetchRequest<Screenshot> = Screenshot.fetchRequest()
        let startOfMonth = calendar.dateInterval(of: .month, for: now)?.start ?? now
        monthRequest.predicate = NSPredicate(format: "captureDate >= %@ AND isMarkedDeleted == NO", startOfMonth as NSDate)

        do {
            let total = try context.count(for: allRequest)
            let todayCount = try context.count(for: todayRequest)
            let weekCount = try context.count(for: weekRequest)
            let monthCount = try context.count(for: monthRequest)

            return (total: total, todayCount: todayCount, weekCount: weekCount, monthCount: monthCount)
        } catch {
            print("❌ [DATA] Failed to fetch screenshot stats: \(error)")
            return (total: 0, todayCount: 0, weekCount: 0, monthCount: 0)
        }
    }
}

// MARK: - Batch Operations

extension ScreenshotDataManager {
    func deleteScreenshots(_ screenshots: [Screenshot], permanently: Bool = false) {
        for screenshot in screenshots {
            if permanently {
                context.delete(screenshot)
            } else {
                screenshot.isMarkedDeleted = true
            }
        }

        do {
            try context.save()
            print("🗑️ [DATA] \(screenshots.count) screenshots \(permanently ? "permanently deleted" : "moved to trash")")
        } catch {
            print("❌ [DATA] Failed to batch delete screenshots: \(error)")
        }
    }

    func addTag(_ tag: Tag, to screenshots: [Screenshot]) {
        for screenshot in screenshots {
            screenshot.addToTags(tag)
        }
        tag.usageCount += Int32(screenshots.count)

        do {
            try context.save()
            print("🏷️ [DATA] Tag '\(tag.name ?? "unknown")' added to \(screenshots.count) screenshots")
        } catch {
            print("❌ [DATA] Failed to batch add tag: \(error)")
        }
    }

    func moveScreenshots(_ screenshots: [Screenshot], to category: Category) {
        for screenshot in screenshots {
            screenshot.category = category
        }

        do {
            try context.save()
            print("📁 [DATA] \(screenshots.count) screenshots moved to category '\(category.name ?? "unknown")'")
        } catch {
            print("❌ [DATA] Failed to batch move screenshots: \(error)")
        }
    }
}
