//
//  GalleryView.swift
//  Cub
//
//  Created by sid on 17/09/25.
//

import SwiftUI
import Cocoa
import QuickLook
import CoreData

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

struct GalleryView: View {
    @ObservedObject private var preferencesManager = PreferencesManager.shared
    @ObservedObject private var dataManager = ScreenshotDataManager.shared

    @State private var screenshots: [ScreenshotItem] = []
    @State private var selectedScreenshot: ScreenshotItem?
    @State private var selectedCategory: Category?
    @State private var isLoading = true
    @State private var searchText = ""
    @State private var sortOrder: SortOrder = .dateDescending
    @State private var selectedSidebarItem: SidebarItem = .allScreenshots
    @State private var categories: [Category] = []
    @State private var screenshotStats: (total: Int, todayCount: Int, weekCount: Int, monthCount: Int) = (0, 0, 0, 0)

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

    private let columns = [
        GridItem(.adaptive(minimum: 200, maximum: 250), spacing: 16)
    ]

    var filteredAndSortedScreenshots: [ScreenshotItem] {
        let filtered = searchText.isEmpty ?
            screenshots :
            screenshots.filter { $0.fileName.localizedCaseInsensitiveContains(searchText) }

        return filtered.sorted { first, second in
            switch sortOrder {
            case .dateDescending:
                return first.dateCreated > second.dateCreated
            case .dateAscending:
                return first.dateCreated < second.dateCreated
            case .nameAscending:
                return first.fileName.localizedCompare(second.fileName) == .orderedAscending
            case .nameDescending:
                return first.fileName.localizedCompare(second.fileName) == .orderedDescending
            case .sizeAscending:
                return first.url.fileSize < second.url.fileSize
            case .sizeDescending:
                return first.url.fileSize > second.url.fileSize
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            sidebarContent
                .navigationSplitViewColumnWidth(min: 200, ideal: 250, max: 300)
        } detail: {
            mainContent
        }
        .onAppear {
            loadData()
        }
        .refreshable {
            loadData()
        }
    }

    private var sidebarContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Search bar
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search screenshots...", text: $searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }

                // Sort options
                HStack {
                    Text("Sort by:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Picker("Sort Order", selection: $sortOrder) {
                        ForEach(SortOrder.allCases, id: \.self) { order in
                            Text(order.rawValue).tag(order)
                        }
                    }
                    .pickerStyle(.menu)
                    .controlSize(.small)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)

            Divider()

            // Smart Collections
            List(selection: $selectedSidebarItem) {
                Section("Library") {
                    SidebarRow(
                        item: .allScreenshots,
                        count: screenshotStats.total,
                        isSelected: selectedSidebarItem == .allScreenshots
                    )
                    .tag(SidebarItem.allScreenshots)

                    SidebarRow(
                        item: .recentScreenshots,
                        count: screenshotStats.todayCount,
                        isSelected: selectedSidebarItem == .recentScreenshots
                    )
                    .tag(SidebarItem.recentScreenshots)
                }

                if !categories.isEmpty {
                    Section("Categories") {
                        ForEach(categories, id: \.id) { category in
                            let sidebarItem = SidebarItem.category(category)
                            SidebarRow(
                                item: sidebarItem,
                                count: category.screenshots?.count ?? 0,
                                isSelected: selectedSidebarItem == sidebarItem
                            )
                            .tag(sidebarItem)
                        }
                    }
                }

                Section("Content Types") {
                    ForEach(ScreenshotContentType.allCases, id: \.self) { contentType in
                        let sidebarItem = SidebarItem.contentType(contentType)
                        let count = countScreenshots(for: contentType)
                        if count > 0 {
                            SidebarRow(
                                item: sidebarItem,
                                count: count,
                                isSelected: selectedSidebarItem == sidebarItem
                            )
                            .tag(sidebarItem)
                        }
                    }
                }
            }
            .listStyle(.sidebar)

            Divider()

            // Statistics and Actions
            VStack(alignment: .leading, spacing: 8) {
                Text("Statistics")
                    .font(.headline)
                    .foregroundColor(.primary)

                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("Total:")
                        Spacer()
                        Text("\(screenshotStats.total)")
                    }
                    HStack {
                        Text("Today:")
                        Spacer()
                        Text("\(screenshotStats.todayCount)")
                    }
                    HStack {
                        Text("This Week:")
                        Spacer()
                        Text("\(screenshotStats.weekCount)")
                    }
                    HStack {
                        Text("This Month:")
                        Spacer()
                        Text("\(screenshotStats.monthCount)")
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)

                Divider()
                    .padding(.vertical, 4)

                Button("Open Folder") {
                    NSWorkspace.shared.open(preferencesManager.screenshotSaveDirectory)
                }
                .buttonStyle(.plain)
                .foregroundColor(.accentColor)

                Button("Refresh") {
                    loadData()
                }
                .buttonStyle(.plain)
                .foregroundColor(.accentColor)
            }
            .padding()
        }
        .onChange(of: selectedSidebarItem) {
            loadScreenshotsForSelectedItem()
        }
    }

    private var mainContent: some View {
        VStack {
            if isLoading {
                VStack {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Loading screenshots...")
                        .font(.headline)
                        .padding(.top)
                }
            } else if filteredAndSortedScreenshots.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 64))
                        .foregroundColor(.secondary)

                    Text(searchText.isEmpty ? "No screenshots found" : "No screenshots match your search")
                        .font(.headline)
                        .foregroundColor(.secondary)

                    if searchText.isEmpty {
                        Text("Screenshots will appear here after you capture them with ⌘E")
                            .font(.subheadline)
                            .foregroundColor(Color(NSColor.tertiaryLabelColor))
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(filteredAndSortedScreenshots) { screenshot in
                            ScreenshotThumbnailView(
                                screenshot: screenshot,
                                isSelected: selectedScreenshot?.id == screenshot.id
                            ) {
                                selectedScreenshot = screenshot
                                quickLookScreenshot(screenshot)
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("Screenshots")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack {
                    Button("Refresh") {
                        loadScreenshotsForSelectedItem()
                    }

                    if let selected = selectedScreenshot {
                        Button("Quick Look") {
                            quickLookScreenshot(selected)
                        }
                    }
                }
            }
        }
    }

    private var totalFileSize: String {
        let totalBytes = screenshots.reduce(0) { sum, screenshot in
            sum + screenshot.url.fileSize
        }
        return ByteCountFormatter.string(fromByteCount: Int64(totalBytes), countStyle: .file)
    }

    private func loadData() {
        isLoading = true

        DispatchQueue.global(qos: .userInitiated).async {
            // Load categories and stats from Core Data
            let loadedCategories = self.dataManager.fetchAllCategories()
            let stats = self.dataManager.getScreenshotStats()

            DispatchQueue.main.async {
                self.categories = loadedCategories
                self.screenshotStats = stats
                print("📊 [GALLERY] Loaded \(loadedCategories.count) categories and stats: \(stats)")

                // Load screenshots for the selected sidebar item
                self.loadScreenshotsForSelectedItem()
            }
        }
    }

    private func loadScreenshotsForSelectedItem() {
        isLoading = true

        DispatchQueue.global(qos: .userInitiated).async {
            var coreDataScreenshots: [Screenshot] = []

            // Load from Core Data based on selected sidebar item
            switch self.selectedSidebarItem {
            case .allScreenshots:
                coreDataScreenshots = self.dataManager.fetchAllScreenshots()
            case .recentScreenshots:
                coreDataScreenshots = self.dataManager.getRecentScreenshots(limit: 50)
            case .category(let category):
                coreDataScreenshots = self.dataManager.fetchScreenshots(in: category)
            case .contentType(let contentType):
                coreDataScreenshots = self.dataManager.getScreenshotsByContentType(contentType)
            }

            // Convert to ScreenshotItem
            var screenshotItems = coreDataScreenshots.map { ScreenshotItem(from: $0) }

            // If no Core Data screenshots, fall back to file-based loading for backward compatibility
            if screenshotItems.isEmpty && self.selectedSidebarItem == .allScreenshots {
                screenshotItems = self.loadLegacyScreenshots()
            }

            DispatchQueue.main.async {
                self.screenshots = screenshotItems
                self.isLoading = false
                print("🖼️ [GALLERY] Loaded \(screenshotItems.count) screenshots for \(self.selectedSidebarItem.displayName)")
            }
        }
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
            print("❌ [GALLERY] Error loading legacy screenshots: \(error)")
            return []
        }
    }

    private func countScreenshots(for contentType: ScreenshotContentType) -> Int {
        return dataManager.getScreenshotsByContentType(contentType).count
    }

    private func quickLookScreenshot(_ screenshot: ScreenshotItem) {
        NSWorkspace.shared.open(screenshot.url)
    }
}

struct SidebarRow: View {
    let item: GalleryView.SidebarItem
    let count: Int
    let isSelected: Bool

    var body: some View {
        HStack {
            Image(systemName: item.iconName)
                .foregroundColor(isSelected ? .white : .accentColor)
                .frame(width: 16)

            Text(item.displayName)
                .foregroundColor(isSelected ? .white : .primary)

            Spacer()

            if count > 0 {
                Text("\(count)")
                    .font(.caption)
                    .foregroundColor(isSelected ? .white.opacity(0.7) : .secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(isSelected ? Color.white.opacity(0.2) : Color.secondary.opacity(0.2))
                    )
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.accentColor : Color.clear)
        )
    }
}

struct ScreenshotThumbnailView: View {
    let screenshot: ScreenshotItem
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Thumbnail with overlay badges
            ZStack(alignment: .topTrailing) {
                Group {
                    if let thumbnail = screenshot.thumbnail {
                        Image(nsImage: thumbnail)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.3))
                            .overlay(
                                Image(systemName: "photo")
                                    .font(.title)
                                    .foregroundColor(.secondary)
                            )
                    }
                }
                .frame(height: 150)
                .background(Color.white)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
                )

                // Content type badge
                if let contentType = screenshot.contentType,
                   let screenshotContentType = ScreenshotContentType(rawValue: contentType) {
                    HStack(spacing: 2) {
                        Image(systemName: screenshotContentType.iconName)
                            .font(.caption2)
                        Text(screenshotContentType.displayName)
                            .font(.caption2)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.black.opacity(0.7))
                    .foregroundColor(.white)
                    .cornerRadius(4)
                    .padding(4)
                }
            }

            // File info with enhanced metadata
            VStack(alignment: .leading, spacing: 2) {
                Text(screenshot.fileName)
                    .font(.caption)
                    .lineLimit(2)
                    .foregroundColor(.primary)

                HStack {
                    Text(screenshot.fileSize)
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    if screenshot.isFromCoreData {
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption2)
                            .foregroundColor(.green)
                    }
                }

                Text(screenshot.dateCreated, format: .dateTime.day().month().year().hour().minute())
                    .font(.caption2)
                    .foregroundColor(.secondary)

                // Source app info
                if let sourceApp = screenshot.sourceAppName {
                    HStack(spacing: 4) {
                        Image(systemName: "app")
                            .font(.caption2)
                        Text(sourceApp)
                            .font(.caption2)
                            .lineLimit(1)
                    }
                    .foregroundColor(.accentColor)
                }

                // Category info
                if let category = screenshot.category {
                    HStack(spacing: 4) {
                        Image(systemName: "folder")
                            .font(.caption2)
                        Text(category)
                            .font(.caption2)
                            .lineLimit(1)
                    }
                    .foregroundColor(.orange)
                }

                // Tags
                if !screenshot.tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(screenshot.tags.prefix(3), id: \.self) { tag in
                                Text(tag)
                                    .font(.caption2)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(Color.secondary.opacity(0.2))
                                    .cornerRadius(3)
                            }
                            if screenshot.tags.count > 3 {
                                Text("+\(screenshot.tags.count - 3)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .padding(8)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .onTapGesture {
            onTap()
        }
    }
}

extension URL {
    var fileSize: Int {
        do {
            let resourceValues = try self.resourceValues(forKeys: [.fileSizeKey])
            return resourceValues.fileSize ?? 0
        } catch {
            return 0
        }
    }
}
