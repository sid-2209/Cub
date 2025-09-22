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

struct GalleryView: View {
    @StateObject private var dataController = GalleryDataController()
    @StateObject private var filterManager = GalleryFilterSystem()
    @StateObject private var selectionManager = GallerySelectionManager()

    @State private var selectedScreenshot: ScreenshotItem?
    @State private var sortOrder: SortOrder = .dateDescending
    @State private var selectedSidebarItem: SidebarItem = .allScreenshots

    // UI state
    @State private var showingFilterToolbar = false
    @State private var showingAdvancedFilters = false

    // File system monitoring
    @StateObject private var fileMonitor = FileSystemMonitor()

    private let columns = [
        GridItem(.adaptive(minimum: 200, maximum: 250), spacing: 16)
    ]

    var filteredAndSortedScreenshots: [ScreenshotItem] {
        let filtered = filterManager.applyFilters(to: dataController.screenshots)

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
            dataController.loadData()
            fileMonitor.startMonitoring(directory: PreferencesManager.shared.screenshotSaveDirectory) {
                dataController.loadScreenshots(for: selectedSidebarItem)
            }
        }
        .onDisappear {
            fileMonitor.stopMonitoring()
        }
        .refreshable {
            dataController.refreshData()
        }
        .confirmationDialog(
            "Delete Screenshots",
            isPresented: $selectionManager.showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete \(selectionManager.selectedCount) Screenshot(s)", role: .destructive) {
                selectionManager.deleteSelectedScreenshots(from: dataController.screenshots) {
                    dataController.loadScreenshots(for: selectedSidebarItem)
                }
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
                    TextField("Search screenshots...", text: $filterManager.filters.searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())

                    Button(action: {
                        showingFilterToolbar.toggle()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "line.3.horizontal.decrease.circle" + (filterManager.filters.hasActiveFilters ? ".fill" : ""))
                            if filterManager.filters.hasActiveFilters {
                                Text("\(filterManager.filters.activeFilterCount)")
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                    .foregroundColor(filterManager.filters.hasActiveFilters ? .accentColor : .secondary)
                    .help("Advanced Filters")
                }

                // Active filter chips
                if filterManager.filters.hasActiveFilters {
                    ActiveFiltersView(filters: $filterManager.filters)
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
                        count: dataController.screenshotStats.total,
                        isSelected: selectedSidebarItem == .allScreenshots
                    )
                    .tag(SidebarItem.allScreenshots)

                    SidebarRow(
                        item: .recentScreenshots,
                        count: dataController.screenshotStats.todayCount,
                        isSelected: selectedSidebarItem == .recentScreenshots
                    )
                    .tag(SidebarItem.recentScreenshots)
                }

                if !dataController.categories.isEmpty {
                    Section("Categories") {
                        ForEach(dataController.categories, id: \.id) { category in
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
                        let count = dataController.countScreenshots(for: contentType)
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
            GalleryStatsView(stats: dataController.screenshotStats)

            Divider()
                .padding(.vertical, 4)

            Button("Open Folder") {
                NSWorkspace.shared.open(PreferencesManager.shared.screenshotSaveDirectory)
            }
            .buttonStyle(.plain)
            .foregroundColor(.accentColor)

            Button("Refresh") {
                dataController.refreshData()
            }
            .buttonStyle(.plain)
            .foregroundColor(.accentColor)
            .padding()
        }
        .onChange(of: selectedSidebarItem) {
            dataController.loadScreenshots(for: selectedSidebarItem)
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
            if dataController.isLoading {
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

                    Text(filterManager.filters.hasActiveFilters ? "No screenshots match your filters" : "No screenshots found")
                        .font(.headline)
                        .foregroundColor(.secondary)

                    if !filterManager.filters.hasActiveFilters {
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
                                isInSelectionMode: selectionManager.isInSelectionMode,
                                isMultiSelected: selectionManager.isSelected(screenshot),
                                onTap: {
                                    if selectionManager.isInSelectionMode {
                                        selectionManager.toggleScreenshotSelection(screenshot)
                                    } else {
                                        selectedScreenshot = screenshot
                                        dataController.quickLookScreenshot(screenshot)
                                    }
                                },
                                onSelectionToggle: {
                                    selectionManager.toggleScreenshotSelection(screenshot)
                                }
                            )
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle(selectionManager.isInSelectionMode ? "\(selectionManager.selectedCount) Selected" : "Screenshots")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack {
                    if !selectionManager.isInSelectionMode {
                        Button("Refresh") {
                            dataController.loadScreenshots(for: selectedSidebarItem)
                        }

                        if let selected = selectedScreenshot {
                            Button("Quick Look") {
                                dataController.quickLookScreenshot(selected)
                            }
                        }

                        if !filteredAndSortedScreenshots.isEmpty {
                            Button("Select") {
                                selectionManager.enterSelectionMode()
                            }
                        }
                    } else {
                        Button("Done") {
                            selectionManager.exitSelectionMode()
                        }
                        .fontWeight(.medium)
                    }
                }
            }

            if selectionManager.isInSelectionMode && selectionManager.hasSelectedScreenshots {
                ToolbarItem(placement: .status) {
                    HStack {
                        Button(action: {
                            selectionManager.selectAll(from: filteredAndSortedScreenshots)
                        }) {
                            Text(selectionManager.areAllSelected(from: filteredAndSortedScreenshots) ? "Deselect All" : "Select All")
                        }

                        Spacer()

                        Button("Share") {
                            selectionManager.shareSelectedScreenshots(from: dataController.screenshots)
                        }
                        .disabled(!selectionManager.hasSelectedScreenshots)

                        Button("Export") {
                            selectionManager.exportSelectedScreenshots(from: dataController.screenshots)
                        }
                        .disabled(!selectionManager.hasSelectedScreenshots)

                        Button("Delete") {
                            selectionManager.showingDeleteConfirmation = true
                        }
                        .foregroundColor(.red)
                        .disabled(!selectionManager.hasSelectedScreenshots)
                    }
                }
            }
        }
    }

    // MARK: - Filter Toolbar View

    private var filterToolbarView: some View {
        GalleryFilterToolbar(
            filterSystem: filterManager,
            showingAdvancedFilters: $showingAdvancedFilters,
            screenshotCount: dataController.screenshots.count,
            filteredCount: filteredAndSortedScreenshots.count
        )
    }








}









