//
//  SelectionOverlayWindow.swift
//  Cub
//
//  Created by sid on 15/09/25.
//

import Cocoa
import SwiftUI

protocol SelectionOverlayDelegate: AnyObject {
    func selectionCompleted(with rect: NSRect, on screen: NSScreen)
    func selectionCancelled()
}

class SelectionOverlayWindow: NSWindow {
    weak var selectionDelegate: SelectionOverlayDelegate?

    private var startPoint: NSPoint = NSPoint.zero
    private var currentPoint: NSPoint = NSPoint.zero
    private var isSelecting: Bool = false
    private var selectionView: SelectionOverlayView!

    private let minimumSelectionSize: CGFloat = 10.0

    init(for screen: NSScreen) {
        let screenFrame = screen.frame

        super.init(
            contentRect: screenFrame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        // Set the screen after initialization
        if NSScreen.screens.contains(screen) {
            setFrameOrigin(screenFrame.origin)
        }

        setupWindow()
        setupSelectionView()
        setupEventMonitoring()
    }

    private func setupWindow() {
        // Make window transparent and above all others
        backgroundColor = NSColor.clear
        isOpaque = false
        level = NSWindow.Level(Int(CGWindowLevelForKey(.maximumWindow)))
        ignoresMouseEvents = false
        acceptsMouseMovedEvents = true
        hasShadow = false
        canHide = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        // Make window appear above dock and menu bar
        hidesOnDeactivate = false

        // Remove from window list
        isExcludedFromWindowsMenu = true
    }

    private func setupSelectionView() {
        selectionView = SelectionOverlayView()
        selectionView.frame = contentView?.bounds ?? frame
        selectionView.autoresizingMask = [.width, .height]
        contentView?.addSubview(selectionView)

        // Set crosshair cursor
        contentView?.addCursorRect(contentView?.bounds ?? frame, cursor: NSCursor.crosshair)
    }

    private func setupEventMonitoring() {
        // Monitor for ESC key to cancel selection
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // ESC key
                self?.cancelSelection()
                return nil
            }
            return event
        }
    }

    // MARK: - Mouse Event Handling

    override func mouseDown(with event: NSEvent) {
        let locationInWindow = event.locationInWindow

        startPoint = locationInWindow
        currentPoint = locationInWindow
        isSelecting = true

        selectionView.startSelection(at: locationInWindow)

        // Change cursor to crosshair
        NSCursor.crosshair.set()

        print("📍 [SELECTION] Mouse down at window coords: \(locationInWindow)")
    }

    override func mouseDragged(with event: NSEvent) {
        guard isSelecting else { return }

        let locationInWindow = event.locationInWindow
        currentPoint = locationInWindow

        // Update selection rectangle in view
        selectionView.updateSelection(from: startPoint, to: locationInWindow)

        print("📐 [SELECTION] Dragging to window coords: \(locationInWindow)")
    }

    override func mouseUp(with event: NSEvent) {
        guard isSelecting else { return }

        let locationInWindow = event.locationInWindow
        currentPoint = locationInWindow
        isSelecting = false

        // Calculate final selection rectangle in window coordinates
        let selectionRect = calculateSelectionRect()

        // Check if selection is valid (minimum size)
        if selectionRect.width >= minimumSelectionSize && selectionRect.height >= minimumSelectionSize {
            print("✅ [SELECTION] Selection completed (window coords): \(selectionRect)")
            selectionDelegate?.selectionCompleted(with: selectionRect, on: screen ?? NSScreen.main!)
        } else {
            print("❌ [SELECTION] Selection too small, cancelling")
            cancelSelection()
        }

        // Clean up
        dismissOverlay()
    }

    override func rightMouseDown(with event: NSEvent) {
        // Right click cancels selection
        cancelSelection()
    }

    // MARK: - Selection Calculation

    private func calculateSelectionRect() -> NSRect {
        let minX = min(startPoint.x, currentPoint.x)
        let minY = min(startPoint.y, currentPoint.y)
        let maxX = max(startPoint.x, currentPoint.x)
        let maxY = max(startPoint.y, currentPoint.y)

        let rect = NSRect(
            x: minX,
            y: minY,
            width: maxX - minX,
            height: maxY - minY
        )

        print("🔍 [SELECTION] calculateSelectionRect:")
        print("   Start point (window): \(startPoint)")
        print("   Current point (window): \(currentPoint)")
        print("   Calculated rect (window): \(rect)")

        return rect
    }

    // MARK: - Selection Management

    private func cancelSelection() {
        print("🚫 Selection cancelled")
        isSelecting = false
        selectionDelegate?.selectionCancelled()
        dismissOverlay()
    }

    private func dismissOverlay() {
        DispatchQueue.main.async {
            self.orderOut(nil)
            self.parent?.removeChildWindow(self)
        }
    }

    // MARK: - Window Lifecycle

    override func makeKeyAndOrderFront(_ sender: Any?) {
        super.makeKeyAndOrderFront(sender)

        // Ensure we're the key window to receive events
        makeKey()
        orderFrontRegardless()

        // Set crosshair cursor
        NSCursor.crosshair.set()
    }

    override func orderOut(_ sender: Any?) {
        super.orderOut(sender)

        // Restore default cursor
        NSCursor.arrow.set()
    }
}

// MARK: - Selection Overlay View

class SelectionOverlayView: NSView {
    private var selectionRect: NSRect = NSRect.zero
    private var isDrawingSelection: Bool = false

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Fill background with semi-transparent overlay
        NSColor.black.withAlphaComponent(0.2).setFill()
        dirtyRect.fill()

        // Draw selection rectangle if active
        if isDrawingSelection && !selectionRect.isEmpty {
            drawSelectionRectangle()
        }
    }

    private func drawSelectionRectangle() {
        // Clear the selection area
        NSColor.clear.setFill()
        selectionRect.fill(using: .copy)

        // Draw selection border
        let borderPath = NSBezierPath(rect: selectionRect)
        NSColor.white.withAlphaComponent(0.8).setStroke()
        borderPath.lineWidth = 2.0
        borderPath.stroke()

        // Draw selection handles (corner indicators)
        drawSelectionHandles()

        // Draw dimensions text
        drawDimensionsText()
    }

    private func drawSelectionHandles() {
        let handleSize: CGFloat = 6.0
        let handleColor = NSColor.white

        let corners = [
            NSPoint(x: selectionRect.minX, y: selectionRect.minY),
            NSPoint(x: selectionRect.maxX, y: selectionRect.minY),
            NSPoint(x: selectionRect.minX, y: selectionRect.maxY),
            NSPoint(x: selectionRect.maxX, y: selectionRect.maxY)
        ]

        for corner in corners {
            let handleRect = NSRect(
                x: corner.x - handleSize / 2,
                y: corner.y - handleSize / 2,
                width: handleSize,
                height: handleSize
            )

            handleColor.setFill()
            NSBezierPath(ovalIn: handleRect).fill()
        }
    }

    private func drawDimensionsText() {
        let width = Int(selectionRect.width)
        let height = Int(selectionRect.height)
        let dimensionsText = "\(width) × \(height)"

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: .medium),
            .foregroundColor: NSColor.white,
            .backgroundColor: NSColor.black.withAlphaComponent(0.7)
        ]

        let attributedString = NSAttributedString(string: dimensionsText, attributes: attributes)
        let textSize = attributedString.size()

        // Position text above the selection rectangle
        let textRect = NSRect(
            x: selectionRect.midX - textSize.width / 2,
            y: selectionRect.maxY + 5,
            width: textSize.width + 8,
            height: textSize.height + 4
        )

        // Ensure text stays within view bounds
        let adjustedRect = textRect.intersection(bounds)
        if !adjustedRect.isEmpty {
            attributedString.draw(in: adjustedRect)
        }
    }

    // MARK: - Selection Methods

    func startSelection(at point: NSPoint) {
        selectionRect = NSRect(origin: point, size: NSSize.zero)
        isDrawingSelection = true
        needsDisplay = true
    }

    func updateSelection(from startPoint: NSPoint, to currentPoint: NSPoint) {
        let minX = min(startPoint.x, currentPoint.x)
        let minY = min(startPoint.y, currentPoint.y)
        let width = abs(currentPoint.x - startPoint.x)
        let height = abs(currentPoint.y - startPoint.y)

        selectionRect = NSRect(x: minX, y: minY, width: width, height: height)
        needsDisplay = true
    }

    func endSelection() {
        isDrawingSelection = false
        needsDisplay = true
    }

    override var isOpaque: Bool {
        return false
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }
}