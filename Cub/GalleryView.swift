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

    // Batch selection state
    @State private var isInSelectionMode = false
    @State private var selectedScreenshots: Set<UUID> = []
    @State private var showingDeleteConfirmation = false

    // Search and Filter state
    @State private var showingFilterToolbar = false
    @State private var showingAdvancedFilters = false
    @State private var activeFilters = ScreenshotFilters()

    // File system monitoring
    @StateObject private var fileMonitor = FileSystemMonitor()

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

    private let columns = [
        GridItem(.adaptive(minimum: 200, maximum: 250), spacing: 16)
    ]

    var filteredAndSortedScreenshots: [ScreenshotItem] {
        let filtered = applyFilters(to: screenshots)

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
            fileMonitor.startMonitoring(directory: preferencesManager.screenshotSaveDirectory) {
                loadScreenshotsForSelectedItem()
            }
        }
        .onDisappear {
            fileMonitor.stopMonitoring()
        }
        .refreshable {
            loadData()
        }
        .confirmationDialog(
            "Delete Screenshots",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete \(selectedScreenshots.count) Screenshot(s)", role: .destructive) {
                deleteSelectedScreenshots()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This action cannot be undone. The screenshots will be permanently deleted.")
        }
    }

    private var sidebarContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Search and Filter bar
            VStack(spacing: 12) {
                // Search field with filter button
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search screenshots...", text: $activeFilters.searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())

                    Button(action: {
                        showingFilterToolbar.toggle()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "line.3.horizontal.decrease.circle" + (activeFilters.hasActiveFilters ? ".fill" : ""))
                            if activeFilters.hasActiveFilters {
                                Text("\(activeFilters.activeFilterCount)")
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                    .foregroundColor(activeFilters.hasActiveFilters ? .accentColor : .secondary)
                    .help("Advanced Filters")
                }

                // Active filter chips
                if activeFilters.hasActiveFilters {
                    ActiveFiltersView(filters: $activeFilters)
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
        VStack(spacing: 0) {
            // Inline Filter Toolbar
            if showingFilterToolbar {
                filterToolbarView
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .animation(.easeInOut(duration: 0.3), value: showingFilterToolbar)

                Divider()
            }

            // Main Content Area
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

                    Text(activeFilters.hasActiveFilters ? "No screenshots match your filters" : "No screenshots found")
                        .font(.headline)
                        .foregroundColor(.secondary)

                    if !activeFilters.hasActiveFilters {
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
                                isSelected: selectedScreenshot?.id == screenshot.id,
                                isInSelectionMode: isInSelectionMode,
                                isMultiSelected: selectedScreenshots.contains(screenshot.id),
                                onTap: {
                                    if isInSelectionMode {
                                        toggleScreenshotSelection(screenshot)
                                    } else {
                                        selectedScreenshot = screenshot
                                        quickLookScreenshot(screenshot)
                                    }
                                },
                                onSelectionToggle: {
                                    toggleScreenshotSelection(screenshot)
                                }
                            )
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle(isInSelectionMode ? "\(selectedScreenshots.count) Selected" : "Screenshots")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack {
                    if !isInSelectionMode {
                        Button("Refresh") {
                            loadScreenshotsForSelectedItem()
                        }

                        if let selected = selectedScreenshot {
                            Button("Quick Look") {
                                quickLookScreenshot(selected)
                            }
                        }

                        if !filteredAndSortedScreenshots.isEmpty {
                            Button("Select") {
                                enterSelectionMode()
                            }
                        }
                    } else {
                        Button("Done") {
                            exitSelectionMode()
                        }
                        .fontWeight(.medium)
                    }
                }
            }

            if isInSelectionMode && !selectedScreenshots.isEmpty {
                ToolbarItem(placement: .status) {
                    HStack {
                        Button(action: selectAll) {
                            Text(selectedScreenshots.count == filteredAndSortedScreenshots.count ? "Deselect All" : "Select All")
                        }

                        Spacer()

                        Button("Share") {
                            shareSelectedScreenshots()
                        }
                        .disabled(selectedScreenshots.isEmpty)

                        Button("Export") {
                            exportSelectedScreenshots()
                        }
                        .disabled(selectedScreenshots.isEmpty)

                        Button("Delete") {
                            showingDeleteConfirmation = true
                        }
                        .foregroundColor(.red)
                        .disabled(selectedScreenshots.isEmpty)
                    }
                }
            }
        }
    }

    // MARK: - Filter Toolbar View

    private var filterToolbarView: some View {
        VStack(spacing: 16) {
            // Filter Results Summary
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Filters")
                        .font(.headline)
                    Text("\(filteredAndSortedScreenshots.count) of \(screenshots.count) screenshots")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Clear All Filters Button
                if activeFilters.hasActiveFilters {
                    Button("Clear All") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            activeFilters = ScreenshotFilters()
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.accentColor)
                }
            }

            // Basic Filter Controls Row
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    // Date Range Filter
                    dateRangeFilterView

                    Divider()
                        .frame(height: 24)

                    // Source App Filter
                    if !availableSourceApps.isEmpty {
                        sourceAppFilterView

                        Divider()
                            .frame(height: 24)
                    }

                    // Content Type Filter
                    contentTypeFilterView

                    Divider()
                        .frame(height: 24)

                    // File Size Filter
                    fileSizeFilterView
                }
                .padding(.horizontal)
            }

            // Active Filter Chips
            if activeFilters.hasActiveFilters {
                activeFilterChipsView
            }

            // Advanced Filters Toggle
            HStack {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showingAdvancedFilters.toggle()
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.right")
                            .rotationEffect(.degrees(showingAdvancedFilters ? 90 : 0))
                            .animation(.easeInOut(duration: 0.2), value: showingAdvancedFilters)

                        Text("More Filters")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)

                Spacer()
            }

            // Advanced Filters Section
            if showingAdvancedFilters {
                advancedFiltersView
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    // MARK: - Computed Properties for Filters

    private var availableSourceApps: [String] {
        let apps = screenshots.compactMap { $0.sourceAppName }.filter { !$0.isEmpty }
        return Array(Set(apps)).sorted()
    }

    private var availableTags: [String] {
        let allTags = screenshots.flatMap { $0.tags }
        return Array(Set(allTags)).sorted()
    }

    private var availableCategories: [String] {
        let cats = screenshots.compactMap { $0.category }.filter { !$0.isEmpty }
        return Array(Set(cats)).sorted()
    }

    // MARK: - Filtering Methods

    private func applyFilters(to screenshots: [ScreenshotItem]) -> [ScreenshotItem] {
        return screenshots.filter { screenshot in
            // Text search (filename, tags, category, app name)
            if !activeFilters.searchText.isEmpty {
                let searchLower = activeFilters.searchText.lowercased()
                let matchesFilename = screenshot.fileName.lowercased().contains(searchLower)
                let matchesTags = screenshot.tags.contains { $0.lowercased().contains(searchLower) }
                let matchesCategory = screenshot.category?.lowercased().contains(searchLower) ?? false
                let matchesApp = screenshot.sourceAppName?.lowercased().contains(searchLower) ?? false

                if !(matchesFilename || matchesTags || matchesCategory || matchesApp) {
                    return false
                }
            }

            // Date range filter
            if let dateRange = activeFilters.dateRange {
                if screenshot.dateCreated < dateRange.start || screenshot.dateCreated > dateRange.end {
                    return false
                }
            }

            // App filter
            if !activeFilters.selectedApps.isEmpty {
                if let appName = screenshot.sourceAppName {
                    if !activeFilters.selectedApps.contains(appName) {
                        return false
                    }
                } else {
                    return false // Screenshot has no app name but filter requires specific apps
                }
            }

            // Size filter
            if let sizeRange = activeFilters.sizeRange {
                let fileSize = Int64(screenshot.url.fileSize)
                if fileSize < sizeRange.minSize || fileSize > sizeRange.maxSize {
                    return false
                }
            }

            // Content type filter
            if !activeFilters.selectedContentTypes.isEmpty {
                if let contentType = screenshot.contentType {
                    if !activeFilters.selectedContentTypes.contains(contentType) {
                        return false
                    }
                } else {
                    return false // Screenshot has no content type but filter requires specific types
                }
            }

            // Tags filter
            if !activeFilters.selectedTags.isEmpty {
                let hasMatchingTag = activeFilters.selectedTags.contains { selectedTag in
                    screenshot.tags.contains(selectedTag)
                }
                if !hasMatchingTag {
                    return false
                }
            }

            // Category filter
            if !activeFilters.selectedCategories.isEmpty {
                if let category = screenshot.category {
                    if !activeFilters.selectedCategories.contains(category) {
                        return false
                    }
                } else {
                    return false // Screenshot has no category but filter requires specific categories
                }
            }

            return true
        }
    }

    // MARK: - Individual Filter View Components

    private var dateRangeFilterView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(.accentColor)
                Text("Date")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }

            Menu {
                Button("Any Time") {
                    activeFilters.dateRange = nil
                }

                Divider()

                ForEach(DateRange.DatePreset.allCases, id: \.self) { preset in
                    Button(preset.rawValue) {
                        activeFilters.dateRange = preset.dateRange
                    }
                }
            } label: {
                HStack {
                    Text(activeFilters.dateRange?.preset?.rawValue ?? "Any Time")
                        .foregroundColor(activeFilters.dateRange != nil ? .accentColor : .primary)
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
        }
    }

    private var sourceAppFilterView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "app.badge")
                    .foregroundColor(.accentColor)
                Text("Source App")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }

            Menu {
                Button("All Apps") {
                    activeFilters.selectedApps.removeAll()
                }

                if !availableSourceApps.isEmpty {
                    Divider()

                    ForEach(availableSourceApps, id: \.self) { app in
                        Button(action: {
                            if activeFilters.selectedApps.contains(app) {
                                activeFilters.selectedApps.remove(app)
                            } else {
                                activeFilters.selectedApps.insert(app)
                            }
                        }) {
                            HStack {
                                Text(app)
                                if activeFilters.selectedApps.contains(app) {
                                    Spacer()
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }
            } label: {
                HStack {
                    Text(activeFilters.selectedApps.isEmpty ? "All Apps" : "\(activeFilters.selectedApps.count) selected")
                        .foregroundColor(activeFilters.selectedApps.isEmpty ? .primary : .accentColor)
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
        }
    }

    private var contentTypeFilterView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "photo.on.rectangle")
                    .foregroundColor(.accentColor)
                Text("Content Type")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }

            Menu {
                Button("All Types") {
                    activeFilters.selectedContentTypes.removeAll()
                }

                Divider()

                ForEach(["fullscreen", "window", "selection", "mobile", "web", "code", "design", "document"], id: \.self) { type in
                    Button(action: {
                        if activeFilters.selectedContentTypes.contains(type) {
                            activeFilters.selectedContentTypes.remove(type)
                        } else {
                            activeFilters.selectedContentTypes.insert(type)
                        }
                    }) {
                        HStack {
                            Text(type.capitalized)
                            if activeFilters.selectedContentTypes.contains(type) {
                                Spacer()
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack {
                    Text(activeFilters.selectedContentTypes.isEmpty ? "All Types" : "\(activeFilters.selectedContentTypes.count) selected")
                        .foregroundColor(activeFilters.selectedContentTypes.isEmpty ? .primary : .accentColor)
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
        }
    }

    private var fileSizeFilterView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "doc.text.magnifyingglass")
                    .foregroundColor(.accentColor)
                Text("File Size")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }

            Menu {
                Button("Any Size") {
                    activeFilters.sizeRange = nil
                }

                Divider()

                ForEach(SizeRange.SizePreset.allCases.filter { $0 != .custom }, id: \.self) { preset in
                    Button(preset.rawValue) {
                        activeFilters.sizeRange = preset.sizeRange
                    }
                }
            } label: {
                HStack {
                    Text(activeFilters.sizeRange?.preset?.rawValue ?? "Any Size")
                        .foregroundColor(activeFilters.sizeRange != nil ? .accentColor : .primary)
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
        }
    }

    private var activeFilterChipsView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                if activeFilters.dateRange != nil {
                    FilterChip(title: "Date: \(activeFilters.dateRange?.preset?.rawValue ?? "Custom")") {
                        activeFilters.dateRange = nil
                    }
                }

                if !activeFilters.selectedApps.isEmpty {
                    FilterChip(title: "Apps: \(activeFilters.selectedApps.count)") {
                        activeFilters.selectedApps.removeAll()
                    }
                }

                if !activeFilters.selectedContentTypes.isEmpty {
                    FilterChip(title: "Types: \(activeFilters.selectedContentTypes.count)") {
                        activeFilters.selectedContentTypes.removeAll()
                    }
                }

                if activeFilters.sizeRange != nil {
                    FilterChip(title: "Size: \(activeFilters.sizeRange?.preset?.rawValue ?? "Custom")") {
                        activeFilters.sizeRange = nil
                    }
                }

                if !activeFilters.selectedTags.isEmpty {
                    FilterChip(title: "Tags: \(activeFilters.selectedTags.count)") {
                        activeFilters.selectedTags.removeAll()
                    }
                }

                if !activeFilters.selectedCategories.isEmpty {
                    FilterChip(title: "Categories: \(activeFilters.selectedCategories.count)") {
                        activeFilters.selectedCategories.removeAll()
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    private var advancedFiltersView: some View {
        VStack(spacing: 20) {
            Divider()

            // Image Analysis Filters
            VStack(spacing: 16) {
                // File Format Section
                advancedFilterSection(
                    title: "File Format",
                    icon: "doc.text",
                    content: {
                        FlowLayout(spacing: 6) {
                            ForEach(FileFormat.allCases, id: \.self) { format in
                                TagToggleChip(
                                    title: format.displayName,
                                    isSelected: activeFilters.selectedFileFormats.contains(format)
                                ) {
                                    toggleFilter(format, in: &activeFilters.selectedFileFormats)
                                }
                            }
                        }
                    }
                )

                // Resolution Section
                advancedFilterSection(
                    title: "Resolution",
                    icon: "viewfinder",
                    content: {
                        FlowLayout(spacing: 6) {
                            ForEach(ResolutionRange.allCases, id: \.self) { resolution in
                                TagToggleChip(
                                    title: resolution.displayName,
                                    isSelected: activeFilters.selectedResolutions.contains(resolution)
                                ) {
                                    toggleFilter(resolution, in: &activeFilters.selectedResolutions)
                                }
                            }
                        }
                    }
                )

                // Orientation & Aspect Ratio Section
                HStack(alignment: .top, spacing: 24) {
                    advancedFilterSection(
                        title: "Orientation",
                        icon: "rotate.3d",
                        content: {
                            FlowLayout(spacing: 6) {
                                ForEach(ImageOrientation.allCases, id: \.self) { orientation in
                                    TagToggleChip(
                                        title: orientation.displayName,
                                        isSelected: activeFilters.selectedOrientations.contains(orientation)
                                    ) {
                                        toggleFilter(orientation, in: &activeFilters.selectedOrientations)
                                    }
                                }
                            }
                        }
                    )

                    advancedFilterSection(
                        title: "Aspect Ratio",
                        icon: "rectangle.ratio.3.to.4",
                        content: {
                            FlowLayout(spacing: 6) {
                                ForEach(AspectRatioRange.allCases, id: \.self) { ratio in
                                    TagToggleChip(
                                        title: ratio.displayName,
                                        isSelected: activeFilters.selectedAspectRatios.contains(ratio)
                                    ) {
                                        toggleFilter(ratio, in: &activeFilters.selectedAspectRatios)
                                    }
                                }
                            }
                        }
                    )
                }
            }

            Divider()

            // Content Recognition Filters
            VStack(spacing: 16) {
                // Content Analysis Section
                HStack(alignment: .top, spacing: 24) {
                    advancedFilterSection(
                        title: "Contains Text",
                        icon: "textformat",
                        content: {
                            HStack(spacing: 12) {
                                Button("Any") {
                                    activeFilters.containsText = nil
                                }
                                .buttonStyle(ToggleButtonStyle(isSelected: activeFilters.containsText == nil))

                                Button("With Text") {
                                    activeFilters.containsText = true
                                }
                                .buttonStyle(ToggleButtonStyle(isSelected: activeFilters.containsText == true))

                                Button("Without Text") {
                                    activeFilters.containsText = false
                                }
                                .buttonStyle(ToggleButtonStyle(isSelected: activeFilters.containsText == false))
                            }
                        }
                    )

                    advancedFilterSection(
                        title: "Window Type",
                        icon: "macwindow",
                        content: {
                            FlowLayout(spacing: 6) {
                                ForEach(WindowType.allCases, id: \.self) { windowType in
                                    TagToggleChip(
                                        title: windowType.displayName,
                                        isSelected: activeFilters.selectedWindowTypes.contains(windowType)
                                    ) {
                                        toggleFilter(windowType, in: &activeFilters.selectedWindowTypes)
                                    }
                                }
                            }
                        }
                    )
                }

                // Capture Type Section
                advancedFilterSection(
                    title: "Capture Type",
                    icon: "camera.viewfinder",
                    content: {
                        FlowLayout(spacing: 6) {
                            ForEach(CaptureType.allCases, id: \.self) { captureType in
                                TagToggleChip(
                                    title: captureType.displayName,
                                    isSelected: activeFilters.selectedCaptureTypes.contains(captureType)
                                ) {
                                    toggleFilter(captureType, in: &activeFilters.selectedCaptureTypes)
                                }
                            }
                        }
                    }
                )
            }

            Divider()

            // Organization Filters
            VStack(spacing: 16) {
                HStack(alignment: .top, spacing: 24) {
                    advancedFilterSection(
                        title: "Favorites",
                        icon: "heart",
                        content: {
                            HStack(spacing: 12) {
                                Button("Any") {
                                    activeFilters.isFavorited = nil
                                }
                                .buttonStyle(ToggleButtonStyle(isSelected: activeFilters.isFavorited == nil))

                                Button("Favorited") {
                                    activeFilters.isFavorited = true
                                }
                                .buttonStyle(ToggleButtonStyle(isSelected: activeFilters.isFavorited == true))

                                Button("Not Favorited") {
                                    activeFilters.isFavorited = false
                                }
                                .buttonStyle(ToggleButtonStyle(isSelected: activeFilters.isFavorited == false))
                            }
                        }
                    )

                    advancedFilterSection(
                        title: "Recently Viewed",
                        icon: "clock",
                        content: {
                            HStack(spacing: 12) {
                                Button("Any") {
                                    activeFilters.recentlyViewed = nil
                                }
                                .buttonStyle(ToggleButtonStyle(isSelected: activeFilters.recentlyViewed == nil))

                                Button("Recent") {
                                    activeFilters.recentlyViewed = true
                                }
                                .buttonStyle(ToggleButtonStyle(isSelected: activeFilters.recentlyViewed == true))
                            }
                        }
                    )
                }
            }

            // Tags and Categories Section (if available)
            if !availableTags.isEmpty || !availableCategories.isEmpty {
                Divider()

                HStack(alignment: .top, spacing: 24) {
                    if !availableTags.isEmpty {
                        advancedFilterSection(
                            title: "Tags",
                            icon: "tag",
                            content: {
                                FlowLayout(spacing: 6) {
                                    ForEach(availableTags, id: \.self) { tag in
                                        TagToggleChip(
                                            title: tag,
                                            isSelected: activeFilters.selectedTags.contains(tag)
                                        ) {
                                            if activeFilters.selectedTags.contains(tag) {
                                                activeFilters.selectedTags.remove(tag)
                                            } else {
                                                activeFilters.selectedTags.insert(tag)
                                            }
                                        }
                                    }
                                }
                            }
                        )
                    }

                    if !availableCategories.isEmpty {
                        advancedFilterSection(
                            title: "Categories",
                            icon: "folder.badge",
                            content: {
                                FlowLayout(spacing: 6) {
                                    ForEach(availableCategories, id: \.self) { category in
                                        TagToggleChip(
                                            title: category,
                                            isSelected: activeFilters.selectedCategories.contains(category)
                                        ) {
                                            if activeFilters.selectedCategories.contains(category) {
                                                activeFilters.selectedCategories.remove(category)
                                            } else {
                                                activeFilters.selectedCategories.insert(category)
                                            }
                                        }
                                    }
                                }
                            }
                        )
                    }
                }
            }
        }
    }

    // MARK: - Helper Methods for Advanced Filters

    @ViewBuilder
    private func advancedFilterSection<Content: View>(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.accentColor)
                    .frame(width: 16)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }

            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func toggleFilter<T: Hashable>(_ item: T, in set: inout Set<T>) {
        if set.contains(item) {
            set.remove(item)
        } else {
            set.insert(item)
        }
    }

    // MARK: - Batch Selection Methods

    private func enterSelectionMode() {
        isInSelectionMode = true
        selectedScreenshots.removeAll()
        selectedScreenshot = nil // Clear single selection when entering batch mode
    }

    private func exitSelectionMode() {
        isInSelectionMode = false
        selectedScreenshots.removeAll()
    }

    private func toggleScreenshotSelection(_ screenshot: ScreenshotItem) {
        if selectedScreenshots.contains(screenshot.id) {
            selectedScreenshots.remove(screenshot.id)
        } else {
            selectedScreenshots.insert(screenshot.id)
        }
    }

    private func selectAll() {
        if selectedScreenshots.count == filteredAndSortedScreenshots.count {
            // Deselect all
            selectedScreenshots.removeAll()
        } else {
            // Select all
            selectedScreenshots = Set(filteredAndSortedScreenshots.map { $0.id })
        }
    }

    private func shareSelectedScreenshots() {
        let selectedItems = filteredAndSortedScreenshots.filter { selectedScreenshots.contains($0.id) }
        let urls = selectedItems.map { $0.url }

        let sharingService = NSSharingServicePicker(items: urls)
        if let window = NSApplication.shared.keyWindow,
           let contentView = window.contentView {
            sharingService.show(relativeTo: .zero, of: contentView, preferredEdge: .minY)
        }
    }

    private func exportSelectedScreenshots() {
        let selectedItems = filteredAndSortedScreenshots.filter { selectedScreenshots.contains($0.id) }

        let savePanel = NSSavePanel()
        savePanel.canCreateDirectories = true
        savePanel.message = "Choose where to export \(selectedItems.count) screenshot(s)"
        savePanel.nameFieldLabel = "Export to:"
        savePanel.nameFieldStringValue = "Screenshots Export"

        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                exportScreenshots(selectedItems, to: url)
            }
        }
    }

    private func exportScreenshots(_ screenshots: [ScreenshotItem], to destinationURL: URL) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try FileManager.default.createDirectory(at: destinationURL, withIntermediateDirectories: true, attributes: nil)

                for screenshot in screenshots {
                    let fileName = screenshot.fileName
                    let destinationFileURL = destinationURL.appendingPathComponent(fileName)
                    try FileManager.default.copyItem(at: screenshot.url, to: destinationFileURL)
                }

                DispatchQueue.main.async {
                    // Show success notification or feedback
                    NSWorkspace.shared.open(destinationURL)
                }
            } catch {
                DispatchQueue.main.async {
                    print("❌ Export failed: \(error)")
                }
            }
        }
    }

    private func deleteSelectedScreenshots() {
        let selectedItems = filteredAndSortedScreenshots.filter { selectedScreenshots.contains($0.id) }

        for screenshot in selectedItems {
            if screenshot.isFromCoreData {
                // Find the Core Data Screenshot object by ID
                let screenshots = dataManager.fetchAllScreenshots()
                if let coreDataScreenshot = screenshots.first(where: { $0.id == screenshot.id }) {
                    dataManager.deleteScreenshot(coreDataScreenshot, permanently: true)
                }
            } else {
                // Delete file from filesystem for legacy screenshots
                try? FileManager.default.removeItem(at: screenshot.url)
            }
        }

        exitSelectionMode()
        loadScreenshotsForSelectedItem() // Refresh the view
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

            // Convert to ScreenshotItem and validate file existence
            var screenshotItems = coreDataScreenshots.compactMap { screenshot -> ScreenshotItem? in
                let item = ScreenshotItem(from: screenshot)

                // Check if the file still exists at the expected path
                if !FileManager.default.fileExists(atPath: item.url.path) {
                    print("⚠️ [GALLERY] File missing for Core Data entry: \(item.fileName)")

                    // Try to find the file by name in the screenshot directory
                    if let updatedURL = self.findMovedFile(originalName: item.fileName) {
                        print("✅ [GALLERY] Found renamed file: \(updatedURL.lastPathComponent)")
                        // Update Core Data with new path
                        self.dataManager.updateScreenshotPath(for: screenshot, newPath: updatedURL)
                        return ScreenshotItem(from: screenshot) // Return updated item
                    } else {
                        // File is completely missing, mark for cleanup
                        print("🗑️ [GALLERY] Marking missing file for cleanup: \(item.fileName)")
                        return nil
                    }
                }

                return item
            }

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
            print("❌ [GALLERY] Error searching for moved file: \(error)")
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
    let isInSelectionMode: Bool
    let isMultiSelected: Bool
    let onTap: () -> Void
    let onSelectionToggle: () -> Void

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
                        .stroke(
                            isInSelectionMode && isMultiSelected ? Color.blue :
                            isSelected && !isInSelectionMode ? Color.blue : Color.clear,
                            lineWidth: 2
                        )
                )
                .overlay(
                    // Selection overlay
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isInSelectionMode && isMultiSelected ? Color.blue.opacity(0.2) : Color.clear)
                )

                // Selection checkbox
                if isInSelectionMode {
                    VStack {
                        HStack {
                            Spacer()
                            Button(action: onSelectionToggle) {
                                Image(systemName: isMultiSelected ? "checkmark.circle.fill" : "circle")
                                    .font(.title2)
                                    .foregroundColor(isMultiSelected ? .blue : .white)
                                    .background(
                                        Circle()
                                            .fill(isMultiSelected ? Color.white : Color.black.opacity(0.5))
                                            .frame(width: 24, height: 24)
                                    )
                            }
                            .buttonStyle(.plain)
                            .padding(8)
                        }
                        Spacer()
                    }
                }

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

// MARK: - ActiveFiltersView

struct ActiveFiltersView: View {
    @Binding var filters: GalleryView.ScreenshotFilters

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if !filters.searchText.isEmpty {
                    FilterChip(
                        title: "Search: \"\(filters.searchText)\"",
                        onRemove: { filters.searchText = "" }
                    )
                }

                if let dateRange = filters.dateRange {
                    FilterChip(
                        title: dateRange.preset?.rawValue ?? "Custom Date Range",
                        onRemove: { filters.dateRange = nil }
                    )
                }

                ForEach(Array(filters.selectedApps), id: \.self) { app in
                    FilterChip(
                        title: "App: \(app)",
                        onRemove: { filters.selectedApps.remove(app) }
                    )
                }

                if let sizeRange = filters.sizeRange {
                    FilterChip(
                        title: sizeRange.preset?.rawValue ?? "Custom Size",
                        onRemove: { filters.sizeRange = nil }
                    )
                }

                ForEach(Array(filters.selectedContentTypes), id: \.self) { type in
                    FilterChip(
                        title: "Type: \(type)",
                        onRemove: { filters.selectedContentTypes.remove(type) }
                    )
                }

                ForEach(Array(filters.selectedTags), id: \.self) { tag in
                    FilterChip(
                        title: "Tag: \(tag)",
                        onRemove: { filters.selectedTags.remove(tag) }
                    )
                }

                ForEach(Array(filters.selectedCategories), id: \.self) { category in
                    FilterChip(
                        title: "Category: \(category)",
                        onRemove: { filters.selectedCategories.remove(category) }
                    )
                }

                // Clear all button
                Button("Clear All") {
                    filters.clear()
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundColor(.red)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.red.opacity(0.1))
                .cornerRadius(12)
            }
            .padding(.horizontal, 2)
        }
    }
}

// MARK: - Filter Chip Component

struct FilterChip: View {
    let title: String
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)

            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.caption2)
                    .fontWeight(.semibold)
            }
            .buttonStyle(.plain)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Color.accentColor)
        .cornerRadius(12)
    }
}

// MARK: - Tag Toggle Chip Component

struct TagToggleChip: View {
    let title: String
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(isSelected ? Color.accentColor : Color(NSColor.controlBackgroundColor))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                        .opacity(isSelected ? 0 : 1)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Flow Layout Component

struct FlowLayout: Layout {
    let spacing: CGFloat

    init(spacing: CGFloat = 8) {
        self.spacing = spacing
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions(),
            subviews: subviews,
            spacing: spacing
        )
        return result.bounds
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions(),
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: result.offsets[index], proposal: ProposedViewSize(result.sizes[index]))
        }
    }

    struct FlowResult {
        var offsets: [CGPoint] = []
        var sizes: [CGSize] = []
        var bounds = CGSize.zero

        init(in bounds: CGSize, subviews: Subviews, spacing: CGFloat) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                if currentX + size.width > bounds.width && currentX > 0 {
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }

                offsets.append(CGPoint(x: currentX, y: currentY))
                sizes.append(size)

                currentX += size.width + spacing
                lineHeight = max(lineHeight, size.height)
            }

            self.bounds = CGSize(
                width: bounds.width,
                height: currentY + lineHeight
            )
        }
    }
}

// MARK: - Toggle Button Style

struct ToggleButtonStyle: ButtonStyle {
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color.accentColor : Color(NSColor.controlBackgroundColor))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                    .opacity(isSelected ? 0 : 1)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
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
