//
//  ClipboardAnimationController.swift
//  Cub
//
//  Created by sid on 21/09/24.
//  Extracted animation logic from ClipboardWindow.swift for modular architecture
//

import Cocoa
import Foundation

// MARK: - Animation Protocol

protocol ClipboardAnimating: AnyObject {
    func dimWindow(_ window: NSWindow, completion: (() -> Void)?)
    func undimWindow(_ window: NSWindow, completion: (() -> Void)?)
    func hideWindowWithAnimation(_ window: NSWindow, completion: (() -> Void)?)
    func showWindowWithAnimation(_ window: NSWindow, completion: (() -> Void)?)
    func fadeInWindow(_ window: NSWindow, completion: (() -> Void)?)
    func fadeOutWindow(_ window: NSWindow, completion: (() -> Void)?)
    func showFeedbackAnimation(_ window: NSWindow, style: FeedbackAnimationStyle)
}

// MARK: - Animation Styles

enum FeedbackAnimationStyle {
    case noScreenshot
    case chatPlaceholder
    case actionFeedback

    var alphaValue: CGFloat {
        switch self {
        case .noScreenshot: return 0.7
        case .chatPlaceholder: return 0.8
        case .actionFeedback: return 0.9
        }
    }

    var duration: TimeInterval {
        switch self {
        case .noScreenshot: return 0.2
        case .chatPlaceholder: return 0.15
        case .actionFeedback: return 0.1
        }
    }
}

// MARK: - Animation Controller Implementation

class ClipboardAnimationController: ClipboardAnimating {

    // MARK: - Window State Animations

    func dimWindow(_ window: NSWindow, completion: (() -> Void)? = nil) {
        print("🌙 [ANIMATION] Dimming window to 50% opacity")

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.4
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window.animator().alphaValue = 0.5
        } completionHandler: {
            print("✅ [ANIMATION] Window dimmed successfully")
            completion?()
        }
    }

    func undimWindow(_ window: NSWindow, completion: (() -> Void)? = nil) {
        print("☀️ [ANIMATION] Undimming window to full opacity")

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().alphaValue = 1.0
        } completionHandler: {
            print("✅ [ANIMATION] Window undimmed successfully")
            completion?()
        }
    }

    func hideWindowWithAnimation(_ window: NSWindow, completion: (() -> Void)? = nil) {
        print("🙈 [ANIMATION] Hiding window with fade out animation")

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.5
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            window.animator().alphaValue = 0.0
        }) {
            window.orderOut(nil)
            print("✅ [ANIMATION] Window hidden successfully")
            completion?()
        }
    }

    func showWindowWithAnimation(_ window: NSWindow, completion: (() -> Void)? = nil) {
        print("👁️ [ANIMATION] Showing window with fade in animation")

        window.alphaValue = 0.0
        window.orderFront(nil)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.4
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().alphaValue = 1.0
        } completionHandler: {
            print("✅ [ANIMATION] Window shown successfully")
            completion?()
        }
    }

    // MARK: - Standard Fade Animations

    func fadeInWindow(_ window: NSWindow, completion: (() -> Void)? = nil) {
        print("📋 [ANIMATION] Starting fade-in animation...")

        window.alphaValue = 0.0
        window.orderFront(nil)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().alphaValue = 1.0
        } completionHandler: {
            print("✅ [ANIMATION] Fade-in animation completed")
            completion?()
        }
    }

    func fadeOutWindow(_ window: NSWindow, completion: (() -> Void)? = nil) {
        print("📋 [ANIMATION] Starting fade-out animation...")

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            window.animator().alphaValue = 0.0
        }) {
            window.orderOut(nil)
            print("✅ [ANIMATION] Fade-out animation completed")
            completion?()
        }
    }

    // MARK: - Feedback Animations

    func showFeedbackAnimation(_ window: NSWindow, style: FeedbackAnimationStyle) {
        print("💡 [ANIMATION] Showing \(style) feedback animation")

        let originalAlpha = window.alphaValue

        NSAnimationContext.runAnimationGroup { context in
            context.duration = style.duration
            context.allowsImplicitAnimation = true
            window.alphaValue = style.alphaValue
        } completionHandler: {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = style.duration
                context.allowsImplicitAnimation = true
                window.alphaValue = originalAlpha
            } completionHandler: {
                print("✅ [ANIMATION] Feedback animation completed")
            }
        }
    }
}

// MARK: - Animation Helper Extensions

extension ClipboardAnimationController {

    /// Performs a quick pulse animation for user feedback
    func pulseWindow(_ window: NSWindow, intensity: CGFloat = 0.8, completion: (() -> Void)? = nil) {
        let originalAlpha = window.alphaValue

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.1
            window.animator().alphaValue = intensity
        } completionHandler: {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.15
                window.animator().alphaValue = originalAlpha
            } completionHandler: {
                completion?()
            }
        }
    }

    /// Performs a gentle glow animation
    func glowWindow(_ window: NSWindow, duration: TimeInterval = 0.5, completion: (() -> Void)? = nil) {
        let originalAlpha = window.alphaValue

        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration / 2
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window.animator().alphaValue = min(originalAlpha * 1.2, 1.0)
        } completionHandler: {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = duration / 2
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                window.animator().alphaValue = originalAlpha
            } completionHandler: {
                completion?()
            }
        }
    }

    /// Scales window slightly for emphasis
    func emphasisScale(_ window: NSWindow, completion: (() -> Void)? = nil) {
        let originalFrame = window.frame
        let scaleFactor: CGFloat = 1.02

        let scaledFrame = NSRect(
            x: originalFrame.origin.x - (originalFrame.width * (scaleFactor - 1)) / 2,
            y: originalFrame.origin.y - (originalFrame.height * (scaleFactor - 1)) / 2,
            width: originalFrame.width * scaleFactor,
            height: originalFrame.height * scaleFactor
        )

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.1
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().setFrame(scaledFrame, display: true)
        } completionHandler: {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.15
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                window.animator().setFrame(originalFrame, display: true)
            } completionHandler: {
                completion?()
            }
        }
    }
}
