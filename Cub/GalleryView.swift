//
//  GalleryView.swift
//  Cub
//
//  Created by sid on 17/09/25.
//

import SwiftUI
import Cocoa
import QuickLook

struct ScreenshotItem: Identifiable {
    let id = UUID()
    let url: URL
    let fileName: String
    let fileSize: String
    let dateCreated: Date
    let thumbnail: NSImage?

    init(url: URL) {
        self.url = url
        self.fileName = url.lastPathComponent

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
    @State private var screenshots: [ScreenshotItem] = []
    @State private var selectedScreenshot: ScreenshotItem?
    @State private var isLoading = true
    @State private var searchText = ""
    @State private var sortOrder: SortOrder = .dateDescending

    enum SortOrder: String, CaseIterable {
        case dateDescending = "Date (Newest First)"
        case dateAscending = "Date (Oldest First)"
        case nameAscending = "Name (A-Z)"
        case nameDescending = "Name (Z-A)"
        case sizeAscending = "Size (Smallest First)"
        case sizeDescending = "Size (Largest First)"
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
            loadScreenshots()
        }
        .refreshable {
            loadScreenshots()
        }
    }

    private var sidebarContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search screenshots...", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }

            // Sort options
            VStack(alignment: .leading, spacing: 8) {
                Text("Sort by")
                    .font(.headline)
                    .foregroundColor(.primary)

                Picker("Sort Order", selection: $sortOrder) {
                    ForEach(SortOrder.allCases, id: \.self) { order in
                        Text(order.rawValue).tag(order)
                    }
                }
                .pickerStyle(.menu)
            }

            // Statistics
            VStack(alignment: .leading, spacing: 4) {
                Text("Statistics")
                    .font(.headline)
                    .foregroundColor(.primary)

                Text("\(screenshots.count) screenshots")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("Total size: \(totalFileSize)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Actions
            VStack(alignment: .leading, spacing: 8) {
                Text("Actions")
                    .font(.headline)
                    .foregroundColor(.primary)

                Button("Open Folder") {
                    NSWorkspace.shared.open(preferencesManager.screenshotSaveDirectory)
                }

                Button("Refresh") {
                    loadScreenshots()
                }
            }

            Spacer()
        }
        .padding()
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
                        loadScreenshots()
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

    private func loadScreenshots() {
        isLoading = true

        DispatchQueue.global(qos: .userInitiated).async {
            let directory = preferencesManager.screenshotSaveDirectory

            guard FileManager.default.fileExists(atPath: directory.path) else {
                DispatchQueue.main.async {
                    self.screenshots = []
                    self.isLoading = false
                }
                return
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

                let screenshotItems = screenshotURLs.map { ScreenshotItem(url: $0) }

                DispatchQueue.main.async {
                    self.screenshots = screenshotItems
                    self.isLoading = false
                    print("🖼️ [GALLERY] Loaded \(screenshotItems.count) screenshots")
                }
            } catch {
                print("❌ [GALLERY] Error loading screenshots: \(error)")
                DispatchQueue.main.async {
                    self.screenshots = []
                    self.isLoading = false
                }
            }
        }
    }

    private func quickLookScreenshot(_ screenshot: ScreenshotItem) {
        NSWorkspace.shared.open(screenshot.url)
    }
}

struct ScreenshotThumbnailView: View {
    let screenshot: ScreenshotItem
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Thumbnail
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

            // File info
            VStack(alignment: .leading, spacing: 2) {
                Text(screenshot.fileName)
                    .font(.caption)
                    .lineLimit(2)
                    .foregroundColor(.primary)

                Text(screenshot.fileSize)
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Text(screenshot.dateCreated, format: .dateTime.day().month().year().hour().minute())
                    .font(.caption2)
                    .foregroundColor(.secondary)
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
