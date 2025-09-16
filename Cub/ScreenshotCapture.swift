//
//  ScreenshotCapture.swift
//  Cub
//
//  Created by sid on 15/09/25.
//

import Cocoa
import CoreGraphics
import Foundation
@preconcurrency import ScreenCaptureKit

enum ScreenshotCaptureError: Error, LocalizedError {
    case invalidCoordinates
    case displayNotFound
    case capturePermissionDenied
    case captureCreationFailed
    case imageConversionFailed
    case memoryAllocationFailed
    case displayConfigurationChanged
    case unknownError(String)

    var errorDescription: String? {
        switch self {
        case .invalidCoordinates:
            return "Invalid selection coordinates provided"
        case .displayNotFound:
            return "Target display not found or disconnected"
        case .capturePermissionDenied:
            return "Screen recording permission was revoked"
        case .captureCreationFailed:
            return "Failed to create screenshot image"
        case .imageConversionFailed:
            return "Failed to convert captured image"
        case .memoryAllocationFailed:
            return "Insufficient memory for capture"
        case .displayConfigurationChanged:
            return "Display configuration changed during capture"
        case .unknownError(let message):
            return "Unknown capture error: \(message)"
        }
    }
}

struct CapturedImage {
    let image: NSImage
    let originalRect: NSRect
    let captureDate: Date
    let sourceScreen: NSScreen
    let scaleFactor: CGFloat
    let fileSize: Int64
    let filePath: URL
    let thumbnailImage: NSImage

    var dimensions: NSSize {
        return image.size
    }

    var displayDimensions: String {
        return "\(Int(dimensions.width))×\(Int(dimensions.height))"
    }

    var fileName: String {
        return filePath.lastPathComponent
    }

    var fileDirectory: String {
        return filePath.deletingLastPathComponent().path
    }
}

protocol ScreenshotCaptureDelegate: AnyObject {
    func screenshotCaptureCompleted(_ capturedImage: CapturedImage)
    func screenshotCaptureFailed(_ error: ScreenshotCaptureError)
}

class ScreenshotCapture: NSObject, ObservableObject {
    weak var delegate: ScreenshotCaptureDelegate?

    private weak var permissionManager: PermissionManager?

    @Published var isCapturing: Bool = false
    @Published var lastCapturedImage: CapturedImage?

    // High-quality capture settings (matching Apple's screenshot behavior)
    private let enableHighQualityCapture: Bool = true // Set to false only for extreme performance needs
    private let maxCaptureSize: CGFloat = 16000 // Increased limit for high-resolution displays (was 4000)
    private let compressionQuality: CGFloat = 1.0 // Highest quality (was 0.8)

    func setPermissionManager(_ manager: PermissionManager) {
        self.permissionManager = manager
    }

    // MARK: - Public Capture Methods

    func captureScreenshot(rect: NSRect, from screen: NSScreen) {
        guard !isCapturing else {
            print("⚠️ Capture already in progress, ignoring request")
            return
        }

        print("📸 Starting screenshot capture...")
        print("📏 Capture area: \(rect)")
        print("📺 Source screen: \(screen.localizedName)")

        isCapturing = true

        // Perform capture on background queue for performance
        DispatchQueue.global(qos: .userInitiated).async {
            self.performCapture(rect: rect, from: screen)
        }
    }

    // MARK: - Private Capture Implementation

    private func performCapture(rect: NSRect, from screen: NSScreen) {
        print("🔍 [CAPTURE] Starting performCapture with rect: \(rect), screen: \(screen.localizedName)")
        print("🔍 [CAPTURE] === COORDINATE TRANSFORMATION PIPELINE ===")
        do {
            // Validate permissions
            print("🔍 [CAPTURE] Step 1: Validating permissions...")
            try validatePermissions()
            print("✅ [CAPTURE] Permissions validated")

            // Validate coordinates
            print("🔍 [CAPTURE] Step 2: Validating input coordinates...")
            print("   Input rect (should be display coords from ScreenSelectionManager): \(rect)")
            try validateCoordinates(rect: rect, screen: screen)
            print("✅ [CAPTURE] Coordinates validated")

            // Get display ID for the screen
            print("🔍 [CAPTURE] Step 3: Getting display ID...")
            let displayID = try getDisplayID(for: screen)
            print("✅ [CAPTURE] Display ID: \(displayID)")

            // Convert to display-relative coordinates (should be minimal changes now)
            print("🔍 [CAPTURE] Step 4: Converting to display-relative coordinates...")
            let displayRect = convertToDisplayCoordinates(rect: rect, screen: screen)
            print("✅ [CAPTURE] Display-relative rect: \(displayRect)")

            // Log the complete coordinate pipeline
            print("📊 [CAPTURE] COORDINATE PIPELINE SUMMARY:")
            print("   Original selection (display coords): \(rect)")
            print("   Final capture rect (display-relative): \(displayRect)")
            print("   Expected output size: \(Int(displayRect.width))×\(Int(displayRect.height))")

            // Capture the image
            print("🔍 [CAPTURE] Step 5: Capturing image with ScreenCaptureKit...")
            let cgImage = try captureImage(displayID: displayID, rect: displayRect, screen: screen)
            print("✅ [CAPTURE] Image captured successfully")
            print("   Actual captured image size: \(cgImage.width)×\(cgImage.height)")

            // Verify size match
            let sizeMatch = cgImage.width == Int(displayRect.width) && cgImage.height == Int(displayRect.height)
            print("   Size verification: \(sizeMatch ? "✅ Perfect match" : "⚠️ Size mismatch")")

            // Convert to NSImage
            let nsImage = try convertToNSImage(cgImage: cgImage, originalRect: rect, screen: screen)

            // Save high-quality image file and create thumbnail
            print("💾 [CAPTURE] Saving screenshot to file and creating thumbnail...")
            let filePath = try saveImageToFile(nsImage, scaleFactor: screen.backingScaleFactor)
            let thumbnailImage = createThumbnail(from: nsImage)
            let actualFileSize = getFileSize(at: filePath)

            print("✅ [CAPTURE] File saved: \(filePath.lastPathComponent)")
            print("📁 [CAPTURE] File location: \(filePath.deletingLastPathComponent().path)")
            print("📦 [CAPTURE] Actual file size: \(formatFileSize(actualFileSize))")

            // Quality verification metrics
            logQualityMetrics(
                originalImage: nsImage,
                fileSize: actualFileSize,
                scaleFactor: screen.backingScaleFactor,
                captureRect: rect
            )

            // Create captured image structure
            let capturedImage = CapturedImage(
                image: nsImage,
                originalRect: rect,
                captureDate: Date(),
                sourceScreen: screen,
                scaleFactor: screen.backingScaleFactor,
                fileSize: actualFileSize,
                filePath: filePath,
                thumbnailImage: thumbnailImage
            )

            // Update on main queue
            DispatchQueue.main.async {
                self.isCapturing = false
                self.lastCapturedImage = capturedImage
                print("🔄 [CAPTURE] Calling delegate.screenshotCaptureCompleted - delegate: \(self.delegate != nil ? "✅ Available" : "❌ Nil")")
                self.delegate?.screenshotCaptureCompleted(capturedImage)

                print("✅ Screenshot capture completed successfully!")
                print("📱 Image size: \(capturedImage.displayDimensions)")
                print("📦 Estimated file size: \(self.formatFileSize(capturedImage.fileSize))")
            }

        } catch let error as ScreenshotCaptureError {
            handleCaptureError(error)
        } catch {
            handleCaptureError(.unknownError(error.localizedDescription))
        }
    }

    private func validatePermissions() throws {
        guard let permissionManager = permissionManager else {
            throw ScreenshotCaptureError.capturePermissionDenied
        }

        if !permissionManager.isPermissionGranted {
            throw ScreenshotCaptureError.capturePermissionDenied
        }
    }

    private func validateCoordinates(rect: NSRect, screen: NSScreen) throws {
        print("🔍 [VALIDATE] Starting coordinate validation...")
        print("   Input rect (display coords): \(rect)")
        print("   Screen frame: \(screen.frame)")

        // Check if rect has valid dimensions
        guard rect.width > 0 && rect.height > 0 else {
            print("❌ [VALIDATE] Invalid rect dimensions: \(rect)")
            throw ScreenshotCaptureError.invalidCoordinates
        }

        // Check minimum size for meaningful capture
        let minSize: CGFloat = 1.0
        guard rect.width >= minSize && rect.height >= minSize else {
            print("❌ [VALIDATE] Rect too small (min \(minSize)px): \(rect)")
            throw ScreenshotCaptureError.invalidCoordinates
        }

        // For display coordinates (top-left origin), validate against screen bounds
        let screenBounds = screen.frame

        // Display coordinates validation - ensure rect is within screen dimensions
        if rect.origin.x < 0 {
            print("⚠️ [VALIDATE] X coordinate is negative: \(rect.origin.x)")
        }
        if rect.origin.y < 0 {
            print("⚠️ [VALIDATE] Y coordinate is negative: \(rect.origin.y)")
        }
        if rect.maxX > screenBounds.width {
            print("⚠️ [VALIDATE] Rect extends beyond screen width: \(rect.maxX) > \(screenBounds.width)")
        }
        if rect.maxY > screenBounds.height {
            print("⚠️ [VALIDATE] Rect extends beyond screen height: \(rect.maxY) > \(screenBounds.height)")
        }

        // Check that the rect is reasonable for ScreenCaptureKit
        guard rect.origin.x >= 0 && rect.origin.y >= 0 &&
              rect.maxX <= screenBounds.width && rect.maxY <= screenBounds.height else {
            print("❌ [VALIDATE] Rect is outside screen bounds:")
            print("   Rect bounds: x=\(rect.origin.x) to \(rect.maxX), y=\(rect.origin.y) to \(rect.maxY)")
            print("   Screen bounds: x=0 to \(screenBounds.width), y=0 to \(screenBounds.height)")
            throw ScreenshotCaptureError.invalidCoordinates
        }

        // Additional validation for reasonable sizes
        let maxReasonableSize: CGFloat = 8192 // 8K max dimension
        if rect.width > maxReasonableSize || rect.height > maxReasonableSize {
            print("⚠️ [VALIDATE] Rect is very large: \(Int(rect.width))×\(Int(rect.height))")
        }

        print("✅ [VALIDATE] All coordinate validations passed")
        print("   Final rect for capture: \(rect)")
        print("   Rect area: \(Int(rect.width))×\(Int(rect.height)) = \(Int(rect.width * rect.height)) pixels")
    }

    private func getDisplayID(for screen: NSScreen) throws -> CGDirectDisplayID {
        // Get display ID from screen
        guard let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            print("❌ [DISPLAY] Failed to get screen number from device description")
            print("   Available keys: \(screen.deviceDescription.keys)")
            throw ScreenshotCaptureError.displayNotFound
        }

        let displayID = CGDirectDisplayID(screenNumber.uint32Value)

        // Basic validation - check if display is active
        var isValid = false
        var activeDisplayCount: UInt32 = 0
        if CGGetActiveDisplayList(0, nil, &activeDisplayCount) == CGError.success && activeDisplayCount > 0 {
            var displays = Array<CGDirectDisplayID>(repeating: 0, count: Int(activeDisplayCount))
            if CGGetActiveDisplayList(activeDisplayCount, &displays, nil) == CGError.success {
                isValid = displays.contains(displayID)
            }
        }

        if !isValid {
            print("⚠️ [DISPLAY] Display ID \(displayID) may not be active")
        }

        print("✅ [DISPLAY] Display ID: \(displayID) (valid: \(isValid))")
        return displayID
    }

    private func convertToDisplayCoordinates(rect: NSRect, screen: NSScreen) -> NSRect {
        let scaleFactor = screen.backingScaleFactor
        let screenFrame = screen.frame

        print("🔧 [CAPTURE] convertToDisplayCoordinates:")
        print("   Input rect (global coords): \(rect)")
        print("   Screen frame: \(screenFrame)")
        print("   Scale factor: \(scaleFactor)")

        // Validate that the rect intersects with the screen
        guard rect.intersects(screenFrame) else {
            print("❌ [CAPTURE] ERROR: Input rect doesn't intersect with screen frame")
            // Return the intersection if any, otherwise use the original rect
            let intersection = rect.intersection(screenFrame)
            if !intersection.isEmpty {
                return convertToDisplayCoordinates(rect: intersection, screen: screen)
            }
            return rect
        }

        // Convert from global coordinates to screen-relative coordinates
        let relativeRect = NSRect(
            x: rect.origin.x - screenFrame.origin.x,
            y: rect.origin.y - screenFrame.origin.y,
            width: rect.width,
            height: rect.height
        )

        print("   Relative rect: \(relativeRect)")

        // Validate bounds within screen
        let clampedRect = NSRect(
            x: max(0, min(relativeRect.origin.x, screenFrame.width - 1)),
            y: max(0, min(relativeRect.origin.y, screenFrame.height - 1)),
            width: max(1, min(relativeRect.width, screenFrame.width - relativeRect.origin.x)),
            height: max(1, min(relativeRect.height, screenFrame.height - relativeRect.origin.y))
        )

        if !NSEqualRects(relativeRect, clampedRect) {
            print("🔧 [CAPTURE] Clamped rect to screen bounds: \(clampedRect)")
        }

        // For ScreenCaptureKit, we use the relative coordinates directly
        // without applying scaling factor (ScreenCaptureKit handles DPI internally)
        print("   Final display-relative rect: \(clampedRect)")

        return clampedRect
    }

    private func captureImage(displayID: CGDirectDisplayID, rect: NSRect, screen: NSScreen) throws -> CGImage {
        // Use high-quality capture without downscaling (matching Apple's behavior)
        let captureRect = enableHighQualityCapture ? rect : optimizeRectForPerformance(rect)

        print("📸 [CAPTURE] High-quality mode: \(enableHighQualityCapture ? "✅ Enabled" : "❌ Disabled")")
        print("📏 [CAPTURE] Original rect: \(Int(rect.width))×\(Int(rect.height))")
        print("📏 [CAPTURE] Capture rect: \(Int(captureRect.width))×\(Int(captureRect.height))")

        if #available(macOS 14.0, *) {
            // Use newest SCScreenshotManager (macOS Sonoma+) for highest quality
            return try captureImageWithScreenshotManager(rect: captureRect, screen: screen, displayID: displayID)
        } else {
            // Use modern ScreenCaptureKit (macOS Monterey+)
            return try captureImageModern(rect: captureRect, screen: screen, displayID: displayID)
        }
    }

    @available(macOS 14.0, *)
    private func captureImageWithScreenshotManager(rect: NSRect, screen: NSScreen, displayID: CGDirectDisplayID) throws -> CGImage {
        var capturedImage: CGImage?
        var captureError: Error?
        let semaphore = DispatchSemaphore(value: 0)

        print("🆕 [CAPTURE] Using SCScreenshotManager (Apple's latest screenshot API)")

        Task { @MainActor in
            do {
                // Get available content
                let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)

                // Find the display that matches our screen
                guard let scDisplay = content.displays.first(where: { display in
                    return display.displayID == displayID
                }) else {
                    captureError = ScreenshotCaptureError.displayNotFound
                    semaphore.signal()
                    return
                }

                // Create configuration for screen capture with retina scaling
                let config = SCStreamConfiguration()
                let scaleFactor = screen.backingScaleFactor
                let pixelWidth = Int(rect.width * scaleFactor)
                let pixelHeight = Int(rect.height * scaleFactor)

                config.width = pixelWidth
                config.height = pixelHeight
                config.sourceRect = rect
                config.scalesToFit = false
                config.showsCursor = false
                config.backgroundColor = .clear
                config.pixelFormat = kCVPixelFormatType_32BGRA

                print("🚀 [SCScreenshotManager] Configuration:")
                print("   Width (pixels): \(config.width)")
                print("   Height (pixels): \(config.height)")
                print("   Scale factor: \(scaleFactor)x")
                print("   Source rect: \(config.sourceRect)")

                // Create filter
                let filter = SCContentFilter(display: scDisplay, excludingWindows: [])

                // Use SCScreenshotManager for highest quality
                let cgImage = try await SCScreenshotManager.captureImage(
                    contentFilter: filter,
                    configuration: config
                )

                capturedImage = cgImage
                print("✅ [SCScreenshotManager] Screenshot captured successfully: \(cgImage.width)×\(cgImage.height)")

            } catch {
                print("❌ [SCScreenshotManager] Screenshot capture failed: \(error)")
                captureError = ScreenshotCaptureError.captureCreationFailed
            }

            semaphore.signal()
        }

        semaphore.wait()

        if let error = captureError {
            throw error
        }

        guard let image = capturedImage else {
            throw ScreenshotCaptureError.captureCreationFailed
        }

        return image
    }

    @available(macOS 12.3, *)
    private func captureImageModern(rect: NSRect, screen: NSScreen, displayID: CGDirectDisplayID) throws -> CGImage {
        var capturedImage: CGImage?
        var captureError: Error?
        let semaphore = DispatchSemaphore(value: 0)

        Task { @MainActor in
            do {
                // Get available content
                let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)

                // Find the display that matches our screen
                guard let scDisplay = content.displays.first(where: { display in
                    // Match by display ID
                    return display.displayID == displayID
                }) else {
                    captureError = ScreenshotCaptureError.displayNotFound
                    semaphore.signal()
                    return
                }

                // Create configuration for screen capture
                let config = SCStreamConfiguration()

                // ✅ Apply retina scale factor for high-quality capture (matching Apple's behavior)
                let scaleFactor = screen.backingScaleFactor
                let pixelWidth = Int(rect.width * scaleFactor)
                let pixelHeight = Int(rect.height * scaleFactor)

                config.width = pixelWidth
                config.height = pixelHeight
                config.sourceRect = rect  // Source rect remains in points (ScreenCaptureKit handles conversion)
                config.scalesToFit = false
                config.showsCursor = false
                config.backgroundColor = .clear
                config.pixelFormat = kCVPixelFormatType_32BGRA

                print("📷 [CAPTURE] ScreenCaptureKit config (High-Quality Retina):")
                print("   Config width (retina pixels): \(config.width)")
                print("   Config height (retina pixels): \(config.height)")
                print("   Config sourceRect (logical points): \(config.sourceRect)")
                print("   Screen scale factor (applied): \(scaleFactor)")
                print("   Display ID: \(displayID)")

                // Mathematical verification
                print("🔍 [CAPTURE] High-Quality Size verification:")
                print("   Requested selection size (logical): \(Int(rect.width))×\(Int(rect.height))")
                print("   Config output size (pixels): \(config.width)×\(config.height)")
                print("   Scale factor applied: \(scaleFactor)x")
                print("   Expected pixel ratio: \(Double(config.width) / rect.width)x scaling")
                print("   Quality improvement vs Apple: \(config.width == Int(rect.width * scaleFactor) ? "✅ Matching" : "⚠️ Different")")

                // Create filter with the specific display
                let filter = SCContentFilter(display: scDisplay, excludingWindows: [])

                // Capture the screenshot
                let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
                capturedImage = image

            } catch {
                print("❌ [CAPTURE] ScreenCaptureKit error: \(error.localizedDescription)")
                print("   Error type: \(type(of: error))")

                // More detailed error classification
                let errorString = error.localizedDescription.lowercased()
                if errorString.contains("not authorized") || errorString.contains("permission") || errorString.contains("denied") {
                    captureError = ScreenshotCaptureError.capturePermissionDenied
                } else if errorString.contains("bounds") || errorString.contains("frame") || errorString.contains("rect") {
                    captureError = ScreenshotCaptureError.invalidCoordinates
                } else if errorString.contains("display") || errorString.contains("screen") {
                    captureError = ScreenshotCaptureError.displayNotFound
                } else if errorString.contains("memory") || errorString.contains("allocation") {
                    captureError = ScreenshotCaptureError.memoryAllocationFailed
                } else {
                    captureError = ScreenshotCaptureError.captureCreationFailed
                }
            }

            semaphore.signal()
        }

        // Wait for capture to complete
        semaphore.wait()

        if let error = captureError {
            throw error
        }

        guard let image = capturedImage else {
            throw ScreenshotCaptureError.captureCreationFailed
        }

        return image
    }

    private func optimizeRectForPerformance(_ rect: NSRect) -> NSRect {
        var optimizedRect = rect

        // If capture is too large, we might need to scale it down
        if rect.width > maxCaptureSize || rect.height > maxCaptureSize {
            let scaleX = rect.width > maxCaptureSize ? maxCaptureSize / rect.width : 1.0
            let scaleY = rect.height > maxCaptureSize ? maxCaptureSize / rect.height : 1.0
            let scale = min(scaleX, scaleY)

            optimizedRect = NSRect(
                x: rect.origin.x * scale,
                y: rect.origin.y * scale,
                width: rect.width * scale,
                height: rect.height * scale
            )

            print("⚡ Optimizing large capture: original(\(Int(rect.width))×\(Int(rect.height))) → optimized(\(Int(optimizedRect.width))×\(Int(optimizedRect.height)))")
        }

        return optimizedRect
    }

    private func convertToNSImage(cgImage: CGImage, originalRect: NSRect, screen: NSScreen) throws -> NSImage {
        let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: CGFloat(cgImage.width), height: CGFloat(cgImage.height)))

        // Ensure image was created successfully
        guard nsImage.isValid else {
            throw ScreenshotCaptureError.imageConversionFailed
        }

        return nsImage
    }

    // MARK: - Multi-Monitor Support

    func captureMultiMonitorSelection(rect: NSRect) {
        print("🖥️ Handling multi-monitor selection...")

        // Find all screens that intersect with the selection
        let intersectingScreens = NSScreen.screens.filter { screen in
            return rect.intersects(screen.frame)
        }

        guard !intersectingScreens.isEmpty else {
            handleCaptureError(.invalidCoordinates)
            return
        }

        if intersectingScreens.count == 1 {
            // Single screen capture
            captureScreenshot(rect: rect, from: intersectingScreens.first!)
        } else {
            // Multi-screen capture - capture from primary screen for now
            // TODO: Implement true multi-monitor stitching
            captureScreenshot(rect: rect, from: intersectingScreens.first!)
            print("📝 Note: Multi-monitor spanning detected, capturing from primary screen")
        }
    }

    // MARK: - Error Handling

    private func handleCaptureError(_ error: ScreenshotCaptureError) {
        print("❌ Screenshot capture failed: \(error.localizedDescription)")

        DispatchQueue.main.async {
            self.isCapturing = false
            self.delegate?.screenshotCaptureFailed(error)
        }
    }

    // MARK: - Helper Methods

    private func estimateImageFileSize(_ image: NSImage) -> Int64 {
        // Rough estimation based on dimensions and bit depth
        let width = Int64(image.size.width)
        let height = Int64(image.size.height)
        let bytesPerPixel: Int64 = 4 // RGBA

        return width * height * bytesPerPixel
    }

    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    // MARK: - Public Helper Methods

    var hasCapturedImage: Bool {
        return lastCapturedImage != nil
    }

    func clearLastCapture() {
        lastCapturedImage = nil
    }

    func retryLastCapture() {
        guard let lastCapture = lastCapturedImage else {
            print("⚠️ No previous capture to retry")
            return
        }

        captureScreenshot(rect: lastCapture.originalRect, from: lastCapture.sourceScreen)
    }

    // MARK: - File Saving and Thumbnail Methods

    private func saveImageToFile(_ image: NSImage, scaleFactor: CGFloat) throws -> URL {
        let preferences = PreferencesManager.shared

        // Ensure directory exists
        guard preferences.ensureDirectoryExists() else {
            throw ScreenshotCaptureError.unknownError("Failed to create screenshot directory")
        }

        // Generate filename and get full path
        let fileName = preferences.generateFileName()
        let filePath = preferences.getFilePath(for: fileName)

        // Create high-quality image data based on format preference
        let imageData: Data
        switch preferences.screenshotFormat {
        case .png:
            imageData = try createHighQualityPNGData(from: image, scaleFactor: scaleFactor)
        case .jpeg:
            imageData = try createHighQualityJPEGData(from: image, scaleFactor: scaleFactor)
        case .tiff:
            imageData = try createHighQualityTIFFData(from: image)
        }

        // Write to file
        try imageData.write(to: filePath)

        print("✅ [FILE] Screenshot saved: \(fileName)")
        print("📁 [FILE] Location: \(filePath.deletingLastPathComponent().path)")
        print("📦 [FILE] Size: \(formatFileSize(Int64(imageData.count)))")

        return filePath
    }

    private func createThumbnail(from image: NSImage, maxDimension: CGFloat = 512) -> NSImage {
        let originalSize = image.size
        let aspectRatio = originalSize.width / originalSize.height

        // Calculate thumbnail size maintaining aspect ratio
        let thumbnailSize: NSSize
        if originalSize.width > originalSize.height {
            thumbnailSize = NSSize(
                width: min(maxDimension, originalSize.width),
                height: min(maxDimension, originalSize.width) / aspectRatio
            )
        } else {
            thumbnailSize = NSSize(
                width: min(maxDimension, originalSize.height) * aspectRatio,
                height: min(maxDimension, originalSize.height)
            )
        }

        // Create thumbnail image
        let thumbnail = NSImage(size: thumbnailSize)
        thumbnail.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: thumbnailSize))
        thumbnail.unlockFocus()

        print("🖼️ [THUMBNAIL] Created: \(Int(thumbnailSize.width))×\(Int(thumbnailSize.height)) from \(Int(originalSize.width))×\(Int(originalSize.height))")

        return thumbnail
    }

    private func createHighQualityPNGData(from image: NSImage, scaleFactor: CGFloat) throws -> Data {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw ScreenshotCaptureError.unknownError("Failed to get CGImage from NSImage")
        }

        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)

        // Preserve DPI information
        let dpi = 72.0 * scaleFactor
        bitmapRep.size = NSSize(
            width: CGFloat(bitmapRep.pixelsWide) / dpi * 72.0,
            height: CGFloat(bitmapRep.pixelsHigh) / dpi * 72.0
        )

        let properties: [NSBitmapImageRep.PropertyKey: Any] = [
            .compressionFactor: 0.0,  // Lossless compression
            .gamma: 2.2,
            .interlaced: false
        ]

        guard let pngData = bitmapRep.representation(using: .png, properties: properties) else {
            throw ScreenshotCaptureError.unknownError("Failed to create PNG representation")
        }

        return pngData
    }

    private func createHighQualityJPEGData(from image: NSImage, scaleFactor: CGFloat) throws -> Data {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw ScreenshotCaptureError.unknownError("Failed to get CGImage from NSImage")
        }

        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)

        // Preserve DPI information
        let dpi = 72.0 * scaleFactor
        bitmapRep.size = NSSize(
            width: CGFloat(bitmapRep.pixelsWide) / dpi * 72.0,
            height: CGFloat(bitmapRep.pixelsHigh) / dpi * 72.0
        )

        let properties: [NSBitmapImageRep.PropertyKey: Any] = [
            .compressionFactor: compressionQuality,  // Use high-quality setting (1.0)
            .gamma: 2.2,
            .progressive: false
        ]

        guard let jpegData = bitmapRep.representation(using: .jpeg, properties: properties) else {
            throw ScreenshotCaptureError.unknownError("Failed to create JPEG representation")
        }

        return jpegData
    }

    private func createHighQualityTIFFData(from image: NSImage) throws -> Data {
        guard let tiffData = image.tiffRepresentation else {
            throw ScreenshotCaptureError.unknownError("Failed to create TIFF representation")
        }

        return tiffData
    }

    private func getFileSize(at url: URL) -> Int64 {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            return attributes[.size] as? Int64 ?? 0
        } catch {
            print("⚠️ [FILE] Failed to get file size: \(error)")
            return 0
        }
    }

    // MARK: - Quality Verification

    private func logQualityMetrics(originalImage: NSImage, fileSize: Int64, scaleFactor: CGFloat, captureRect: NSRect) {
        let imageSize = originalImage.size
        let pixelCount = Int64(imageSize.width * imageSize.height)
        let bytesPerPixel = Double(fileSize) / Double(pixelCount)

        print("📊 [QUALITY] === Screenshot Quality Metrics ===")
        print("📏 [QUALITY] Logical dimensions: \(Int(captureRect.width))×\(Int(captureRect.height))")
        print("📏 [QUALITY] Image dimensions: \(Int(imageSize.width))×\(Int(imageSize.height))")
        print("🔍 [QUALITY] Scale factor: \(scaleFactor)x")
        print("🔍 [QUALITY] Expected retina size: \(Int(captureRect.width * scaleFactor))×\(Int(captureRect.height * scaleFactor))")
        print("✅ [QUALITY] Retina scaling: \(imageSize.width == captureRect.width * scaleFactor ? "✅ Correct" : "❌ Incorrect")")
        print("📦 [QUALITY] File size: \(formatFileSize(fileSize))")
        print("🧮 [QUALITY] Total pixels: \(formatNumber(pixelCount))")
        print("💾 [QUALITY] Bytes per pixel: \(String(format: "%.2f", bytesPerPixel))")

        // Compare with Apple's typical screenshot metrics
        let expectedApplePixels = Int64(captureRect.width * scaleFactor * captureRect.height * scaleFactor)
        let qualityComparison = Double(pixelCount) / Double(expectedApplePixels)

        print("🍎 [QUALITY] vs Apple screenshot:")
        print("   Expected pixels (Apple): \(formatNumber(expectedApplePixels))")
        print("   Our pixels: \(formatNumber(pixelCount))")
        print("   Quality ratio: \(String(format: "%.2f", qualityComparison))x (\(qualityComparison >= 1.0 ? "✅ Equal/Better" : "❌ Lower"))")
        print("📊 [QUALITY] === End Quality Metrics ===")
    }

    private func formatNumber(_ number: Int64) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }
}