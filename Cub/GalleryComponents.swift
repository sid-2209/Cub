//
//  GalleryComponents.swift
//  Cub
//
//  Created by sid on 21/09/24.
//  Extracted UI components from GalleryView.swift for modular architecture
//

import SwiftUI
import Cocoa

// MARK: - Sidebar Components

struct SidebarRow: View {
    let item: SidebarItem
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

// MARK: - Screenshot Thumbnail Component

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

// MARK: - Filter Components

struct ActiveFiltersView: View {
    @Binding var filters: ScreenshotFilters

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

// MARK: - Layout Components

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

// MARK: - Button Styles

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

// MARK: - Statistics Component

struct GalleryStatsView: View {
    let stats: ScreenshotStats

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Statistics")
                .font(.headline)
                .foregroundColor(.primary)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Total:")
                    Spacer()
                    Text("\(stats.total)")
                }
                HStack {
                    Text("Today:")
                    Spacer()
                    Text("\(stats.todayCount)")
                }
                HStack {
                    Text("This Week:")
                    Spacer()
                    Text("\(stats.weekCount)")
                }
                HStack {
                    Text("This Month:")
                    Spacer()
                    Text("\(stats.monthCount)")
                }
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
    }
}
