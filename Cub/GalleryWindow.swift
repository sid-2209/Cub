//
//  GalleryWindow.swift
//  Cub
//
//  Created by sid on 17/09/25.
//

import Cocoa
import SwiftUI

class GalleryWindowController: NSWindowController {
    static var shared: GalleryWindowController?

    init() {
        // Create the window
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        super.init(window: window)

        setupWindow()
        setupContent()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupWindow() {
        guard let window = window else { return }

        // Window configuration
        window.title = "Screenshot Gallery"
        window.center()
        window.setFrameAutosaveName("GalleryWindow")
        window.isReleasedWhenClosed = false
        window.level = .normal

        // Set minimum and maximum size
        window.minSize = NSSize(width: 600, height: 400)
        window.maxSize = NSSize(width: 1400, height: 1000)

        // Modern window appearance
        window.titlebarAppearsTransparent = true
        window.styleMask.insert(.fullSizeContentView)

        print("🖼️ [GALLERY] Gallery window configured")
    }

    private func setupContent() {
        guard let window = window else { return }

        // Create SwiftUI view
        let galleryView = GalleryView()

        // Create hosting view
        let hostingView = NSHostingView(rootView: galleryView)
        window.contentView = hostingView

        print("🖼️ [GALLERY] SwiftUI content view configured")
    }

    func showGallery() {
        print("🖼️ [GALLERY] showGallery() called")

        // Activate the application to bring it to front
        NSApp.activate(ignoringOtherApps: true)

        // Show the window
        window?.makeKeyAndOrderFront(nil)
        window?.orderFrontRegardless()

        print("🖼️ [GALLERY] Gallery window shown")
    }

    func hideGallery() {
        window?.orderOut(nil)
        print("🖼️ [GALLERY] Gallery window hidden")
    }

    static func createShared() {
        if shared == nil {
            shared = GalleryWindowController()
            print("🖼️ [GALLERY] Shared gallery window controller created")
        }
    }

    static func show() {
        guard let shared = shared else {
            print("❌ [GALLERY] No shared gallery window controller available")
            return
        }
        shared.showGallery()
    }

    static func hide() {
        shared?.hideGallery()
    }
}
