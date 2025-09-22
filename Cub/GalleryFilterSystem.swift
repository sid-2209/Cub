//
//  GalleryFilterSystem.swift
//  Cub
//
//  Created by sid on 21/09/24.
//  Extracted filtering system from GalleryView.swift for modular architecture
//

import SwiftUI
import Foundation

// MARK: - Filter System Protocol

protocol GalleryFilterManaging: ObservableObject {
    var filters: ScreenshotFilters { get set }
    var availableSourceApps: [String] { get }
    var availableTags: [String] { get }
    var availableCategories: [String] { get }

    func applyFilters(to screenshots: [ScreenshotItem]) -> [ScreenshotItem]
    func clearAllFilters()
    func toggleFilter<T: Hashable>(_ item: T, in set: inout Set<T>)
}

// MARK: - Filter System Implementation

class GalleryFilterSystem: GalleryFilterManaging {
    @Published var filters = ScreenshotFilters()
    @Published var availableSourceApps: [String] = []
    @Published var availableTags: [String] = []
    @Published var availableCategories: [String] = []

    init() {
        updateAvailableOptions()
    }

    // MARK: - Core Filtering Logic

    func applyFilters(to screenshots: [ScreenshotItem]) -> [ScreenshotItem] {
        return screenshots.filter { screenshot in
            // Text search (filename, tags, category, app name)
            if !filters.searchText.isEmpty {
                let searchLower = filters.searchText.lowercased()
                let matchesFilename = screenshot.fileName.lowercased().contains(searchLower)
                let matchesTags = screenshot.tags.contains { $0.lowercased().contains(searchLower) }
                let matchesCategory = screenshot.category?.lowercased().contains(searchLower) ?? false
                let matchesApp = screenshot.sourceAppName?.lowercased().contains(searchLower) ?? false

                if !(matchesFilename || matchesTags || matchesCategory || matchesApp) {
                    return false
                }
            }

            // Date range filter
            if let dateRange = filters.dateRange {
                if screenshot.dateCreated < dateRange.start || screenshot.dateCreated > dateRange.end {
                    return false
                }
            }

            // App filter
            if !filters.selectedApps.isEmpty {
                if let appName = screenshot.sourceAppName {
                    if !filters.selectedApps.contains(appName) {
                        return false
                    }
                } else {
                    return false // Screenshot has no app name but filter requires specific apps
                }
            }

            // Size filter
            if let sizeRange = filters.sizeRange {
                let fileSize = Int64(screenshot.url.fileSize)
                if fileSize < sizeRange.minSize || fileSize > sizeRange.maxSize {
                    return false
                }
            }

            // Content type filter
            if !filters.selectedContentTypes.isEmpty {
                if let contentType = screenshot.contentType {
                    if !filters.selectedContentTypes.contains(contentType) {
                        return false
                    }
                } else {
                    return false // Screenshot has no content type but filter requires specific types
                }
            }

            // Tags filter
            if !filters.selectedTags.isEmpty {
                let hasMatchingTag = filters.selectedTags.contains { selectedTag in
                    screenshot.tags.contains(selectedTag)
                }
                if !hasMatchingTag {
                    return false
                }
            }

            // Category filter
            if !filters.selectedCategories.isEmpty {
                if let category = screenshot.category {
                    if !filters.selectedCategories.contains(category) {
                        return false
                    }
                } else {
                    return false // Screenshot has no category but filter requires specific categories
                }
            }

            // Advanced image analysis filters
            if !filters.selectedFileFormats.isEmpty {
                let fileExtension = screenshot.url.pathExtension.lowercased()
                let matchesFormat = filters.selectedFileFormats.contains { format in
                    format.rawValue.lowercased() == fileExtension ||
                    (format == .jpeg && (fileExtension == "jpg" || fileExtension == "jpeg"))
                }
                if !matchesFormat {
                    return false
                }
            }

            // Add more advanced filtering logic here as needed...

            return true
        }
    }

    func clearAllFilters() {
        filters.clear()
    }

    func toggleFilter<T: Hashable>(_ item: T, in set: inout Set<T>) {
        if set.contains(item) {
            set.remove(item)
        } else {
            set.insert(item)
        }
    }

    // MARK: - Data Management

    func updateAvailableOptions(from screenshots: [ScreenshotItem] = []) {
        // Extract unique source apps
        availableSourceApps = Array(Set(screenshots.compactMap { $0.sourceAppName })).sorted()

        // Extract unique tags
        availableTags = Array(Set(screenshots.flatMap { $0.tags })).sorted()

        // Extract unique categories
        availableCategories = Array(Set(screenshots.compactMap { $0.category })).sorted()
    }
}

// MARK: - Filter UI Components

struct GalleryFilterToolbar: View {
    @ObservedObject var filterSystem: GalleryFilterSystem
    @Binding var showingAdvancedFilters: Bool
    let screenshotCount: Int
    let filteredCount: Int

    var body: some View {
        VStack(spacing: 16) {
            // Filter Results Summary
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Filters")
                        .font(.headline)
                    Text("\(filteredCount) of \(screenshotCount) screenshots")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Clear all filters button
                if filterSystem.filters.hasActiveFilters {
                    Button("Clear All") {
                        filterSystem.clearAllFilters()
                    }
                    .foregroundColor(.accentColor)
                    .font(.caption)
                }

                // Toggle advanced filters
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showingAdvancedFilters.toggle()
                    }
                }) {
                    HStack(spacing: 4) {
                        Text("Advanced")
                        Image(systemName: showingAdvancedFilters ? "chevron.up" : "chevron.down")
                            .font(.caption)
                    }
                }
                .foregroundColor(.accentColor)
                .font(.caption)
            }

            // Basic Filter Controls in a horizontal layout
            HStack(spacing: 16) {
                DateRangeFilterView(filters: $filterSystem.filters)
                SourceAppFilterView(
                    filters: $filterSystem.filters,
                    availableApps: filterSystem.availableSourceApps
                )
                ContentTypeFilterView(filters: $filterSystem.filters)
                FileSizeFilterView(filters: $filterSystem.filters)
            }

            // Active filter chips
            if filterSystem.filters.hasActiveFilters {
                ActiveFilterChipsView(filters: $filterSystem.filters)
            }

            // Advanced filters section
            if showingAdvancedFilters {
                AdvancedFiltersView(filters: $filterSystem.filters)
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
}

// MARK: - Individual Filter Components

struct DateRangeFilterView: View {
    @Binding var filters: ScreenshotFilters

    var body: some View {
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
                    filters.dateRange = nil
                }

                Divider()

                ForEach(DateRange.DatePreset.allCases, id: \.self) { preset in
                    Button(preset.rawValue) {
                        filters.dateRange = preset.dateRange
                    }
                }
            } label: {
                HStack {
                    Text(filters.dateRange?.preset?.rawValue ?? "Any Time")
                        .foregroundColor(filters.dateRange != nil ? .accentColor : .primary)
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
}

struct SourceAppFilterView: View {
    @Binding var filters: ScreenshotFilters
    let availableApps: [String]

    var body: some View {
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
                    filters.selectedApps.removeAll()
                }

                if !availableApps.isEmpty {
                    Divider()

                    ForEach(availableApps, id: \.self) { app in
                        Button(action: {
                            if filters.selectedApps.contains(app) {
                                filters.selectedApps.remove(app)
                            } else {
                                filters.selectedApps.insert(app)
                            }
                        }) {
                            HStack {
                                Text(app)
                                if filters.selectedApps.contains(app) {
                                    Spacer()
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }
            } label: {
                HStack {
                    Text(filters.selectedApps.isEmpty ? "All Apps" : "\(filters.selectedApps.count) selected")
                        .foregroundColor(filters.selectedApps.isEmpty ? .primary : .accentColor)
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
}

struct ContentTypeFilterView: View {
    @Binding var filters: ScreenshotFilters

    private let availableContentTypes = ["fullscreen", "window", "selection", "mobile", "web", "code", "design", "document"]

    var body: some View {
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
                    filters.selectedContentTypes.removeAll()
                }

                Divider()

                ForEach(availableContentTypes, id: \.self) { type in
                    Button(action: {
                        if filters.selectedContentTypes.contains(type) {
                            filters.selectedContentTypes.remove(type)
                        } else {
                            filters.selectedContentTypes.insert(type)
                        }
                    }) {
                        HStack {
                            Text(type.capitalized)
                            if filters.selectedContentTypes.contains(type) {
                                Spacer()
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack {
                    Text(filters.selectedContentTypes.isEmpty ? "All Types" : "\(filters.selectedContentTypes.count) selected")
                        .foregroundColor(filters.selectedContentTypes.isEmpty ? .primary : .accentColor)
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
}

struct FileSizeFilterView: View {
    @Binding var filters: ScreenshotFilters

    var body: some View {
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
                    filters.sizeRange = nil
                }

                Divider()

                ForEach(SizeRange.SizePreset.allCases.filter { $0 != .custom }, id: \.self) { preset in
                    Button(preset.rawValue) {
                        filters.sizeRange = preset.sizeRange
                    }
                }
            } label: {
                HStack {
                    Text(filters.sizeRange?.preset?.rawValue ?? "Any Size")
                        .foregroundColor(filters.sizeRange != nil ? .accentColor : .primary)
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
}

struct ActiveFilterChipsView: View {
    @Binding var filters: ScreenshotFilters

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                if filters.dateRange != nil {
                    FilterChip(title: "Date: \(filters.dateRange?.preset?.rawValue ?? "Custom")") {
                        filters.dateRange = nil
                    }
                }

                if !filters.selectedApps.isEmpty {
                    FilterChip(title: "Apps: \(filters.selectedApps.count)") {
                        filters.selectedApps.removeAll()
                    }
                }

                if !filters.selectedContentTypes.isEmpty {
                    FilterChip(title: "Types: \(filters.selectedContentTypes.count)") {
                        filters.selectedContentTypes.removeAll()
                    }
                }

                if filters.sizeRange != nil {
                    FilterChip(title: "Size: \(filters.sizeRange?.preset?.rawValue ?? "Custom")") {
                        filters.sizeRange = nil
                    }
                }

                if !filters.selectedTags.isEmpty {
                    FilterChip(title: "Tags: \(filters.selectedTags.count)") {
                        filters.selectedTags.removeAll()
                    }
                }

                if !filters.selectedCategories.isEmpty {
                    FilterChip(title: "Categories: \(filters.selectedCategories.count)") {
                        filters.selectedCategories.removeAll()
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }
}

struct AdvancedFiltersView: View {
    @Binding var filters: ScreenshotFilters

    var body: some View {
        VStack(spacing: 20) {
            Divider()

            // Image Analysis Filters
            VStack(spacing: 16) {
                // File Format Section
                AdvancedFilterSection(
                    title: "File Format",
                    icon: "doc.text"
                ) {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                        ForEach(FileFormat.allCases, id: \.self) { format in
                            FilterToggleButton(
                                title: format.displayName,
                                isSelected: filters.selectedFileFormats.contains(format)
                            ) {
                                if filters.selectedFileFormats.contains(format) {
                                    filters.selectedFileFormats.remove(format)
                                } else {
                                    filters.selectedFileFormats.insert(format)
                                }
                            }
                        }
                    }
                }

                // Resolution Section
                AdvancedFilterSection(
                    title: "Resolution",
                    icon: "rectangle.3.group"
                ) {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                        ForEach(ResolutionRange.allCases, id: \.self) { resolution in
                            FilterToggleButton(
                                title: resolution.displayName,
                                isSelected: filters.selectedResolutions.contains(resolution)
                            ) {
                                if filters.selectedResolutions.contains(resolution) {
                                    filters.selectedResolutions.remove(resolution)
                                } else {
                                    filters.selectedResolutions.insert(resolution)
                                }
                            }
                        }
                    }
                }

                // Orientation Section
                AdvancedFilterSection(
                    title: "Orientation",
                    icon: "crop.rotate"
                ) {
                    HStack(spacing: 8) {
                        ForEach(ImageOrientation.allCases, id: \.self) { orientation in
                            FilterToggleButton(
                                title: orientation.displayName,
                                isSelected: filters.selectedOrientations.contains(orientation)
                            ) {
                                if filters.selectedOrientations.contains(orientation) {
                                    filters.selectedOrientations.remove(orientation)
                                } else {
                                    filters.selectedOrientations.insert(orientation)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

struct AdvancedFilterSection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.accentColor)
                    .frame(width: 16)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
            }
            content
        }
    }
}

struct FilterToggleButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(isSelected ? Color.accentColor : Color(NSColor.controlBackgroundColor))
                .cornerRadius(4)
        }
        .buttonStyle(.plain)
    }
}
