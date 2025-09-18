# Cub

Cub (Clip Utility Board) is a streamlined clipboard utility for macOS that stays pinned to your screen. With a quick ⌘E shortcut, simply drag to select an area, and Cub instantly captures and stores the screenshot in its clipboard window. It also provides robust organization and filtering tools to keep your captures neatly managed.

---

## Demo

<a href="assets/club_demo2.mov">
  <img src="assets/Cub_Thumbnail.png" alt="Click to watch Demo" width="600">
</a>

---

## Core Features

- **Professional Gallery**: Core Data-powered screenshot management with persistent storage
- **Advanced Filtering**: 40+ filter options across 10+ categories (date, app, size, format, resolution, orientation)
- **Batch Operations**: Multi-selection for bulk delete, export, and share operations
- **Smart Organization**: Auto-categorization by app source and content type detection
- **Real-time Search**: Instant filtering with comprehensive metadata search
- **Native Integration**: MenuBarExtra app with translucent materials following Apple HIG
- **Quick Capture**: Customizable hotkeys (default `⌘E`) with pixel-perfect area selection
- **Multi-Format Support**: PNG, JPEG, TIFF, GIF, BMP, WebP export capabilities
- **File System Monitoring**: Real-time detection of external file changes and renames

## Architecture

- **Frontend**: SwiftUI with native macOS design patterns
- **Data Layer**: Core Data for persistent screenshot metadata storage
- **Capture Engine**: ScreenCaptureKit integration for high-quality capture
- **Design System**: Apple Human Interface Guidelines compliance with material design

## Workflow

1. **Capture**: Press `⌘E` for area selection or use floating clipboard window
2. **Organize**: Auto-categorization by source app with manual tagging support
3. **Filter**: Advanced search across metadata, content type, and file properties
4. **Manage**: Batch operations for professional screenshot workflow management
5. **Export**: Multi-format export with metadata preservation

## Requirements

- **macOS 15.3+**
- **Screen Recording Permission** (requested on first launch)
- **File System Access** (for screenshot storage and organization)

## Technical Stack

Built with **Swift**, **SwiftUI**, **Core Data**, and **ScreenCaptureKit** for native macOS performance and integration.
