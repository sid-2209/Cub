//
//  CompactStatusIndicator.swift
//  Cub
//
//  Created by sid on 17/09/25.
//

import SwiftUI

enum StatusIndicatorState {
    case active
    case inactive
    case warning
    case error

    var color: Color {
        switch self {
        case .active:
            return .green
        case .inactive:
            return .secondary
        case .warning:
            return .orange
        case .error:
            return .red
        }
    }

    var symbolVariant: SymbolVariants {
        switch self {
        case .active:
            return .fill
        case .inactive, .warning, .error:
            return .none
        }
    }
}

struct StatusIndicator: View {
    let title: String
    let systemImage: String
    let state: StatusIndicatorState
    let detail: String?
    let action: (() -> Void)?

    @State private var isHovered = false
    @State private var showTooltip = false

    init(
        title: String,
        systemImage: String,
        state: StatusIndicatorState,
        detail: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.systemImage = systemImage
        self.state = state
        self.detail = detail
        self.action = action
    }

    var body: some View {
        Group {
            if let action = action {
                Button(action: action) {
                    indicatorContent
                }
                .buttonStyle(.plain)
            } else {
                indicatorContent
            }
        }
        .onHover { hovering in
            isHovered = hovering
            if hovering && detail != nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    if isHovered {
                        showTooltip = true
                    }
                }
            } else {
                showTooltip = false
            }
        }
        .help(detail ?? "")
        .accessibilityLabel("\(title): \(state == .active ? "Active" : "Inactive")")
        .accessibilityHint(detail ?? "")
    }

    private var indicatorContent: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .medium))
                .symbolVariant(state.symbolVariant)
                .foregroundStyle(state.color)

            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(state == .active ? .primary : .secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(backgroundColor)
        )
        .scaleEffect(isHovered && action != nil ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.12), value: isHovered)
    }

    private var backgroundColor: Color {
        if action != nil && isHovered {
            return state.color.opacity(0.1)
        }
        return .clear
    }
}

struct CompactStatusSection: View {
    @EnvironmentObject var permissionManager: PermissionManager
    @EnvironmentObject var hotkeyManager: HotkeyManager

    var body: some View {
        HStack(spacing: 12) {
            StatusIndicator(
                title: "Screen Recording",
                systemImage: "video",
                state: permissionManager.isPermissionGranted ? .active : .error,
                detail: permissionManager.isPermissionGranted
                    ? "Screen recording permission granted"
                    : "Screen recording permission required. Click to grant.",
                action: permissionManager.isPermissionGranted ? nil : {
                    permissionManager.requestScreenRecordingPermission()
                }
            )

            StatusIndicator(
                title: "Hotkey",
                systemImage: "keyboard",
                state: hotkeyStatusState,
                detail: hotkeyDetailText,
                action: hotkeyManager.isHotkeyActive ? {
                    hotkeyManager.testHotkey()
                } : {
                    hotkeyManager.registerHotkey()
                }
            )
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(.regularMaterial, in: .rect(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(.separator.opacity(0.3), lineWidth: 0.5)
        )
    }

    private var hotkeyStatusState: StatusIndicatorState {
        switch hotkeyManager.hotkeyStatus {
        case .registered:
            return .active
        case .notRegistered:
            return .inactive
        case .permissionRequired:
            return .warning
        case .failed(_):
            return .error
        }
    }

    private var hotkeyDetailText: String {
        let shortcut = "⌘E"
        switch hotkeyManager.hotkeyStatus {
        case .registered:
            return "Global hotkey \(shortcut) is active. Click to test."
        case .notRegistered:
            return "Global hotkey \(shortcut) not registered. Click to register."
        case .permissionRequired:
            return "Accessibility permission required for hotkey \(shortcut)."
        case .failed(let error):
            return "Hotkey \(shortcut) failed: \(error.localizedDescription)"
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        // Individual indicators
        HStack {
            StatusIndicator(
                title: "Active",
                systemImage: "checkmark.shield",
                state: .active,
                detail: "Everything is working correctly"
            )

            StatusIndicator(
                title: "Warning",
                systemImage: "exclamationmark.triangle",
                state: .warning,
                detail: "Attention required"
            )

            StatusIndicator(
                title: "Error",
                systemImage: "xmark.circle",
                state: .error,
                detail: "Action needed to resolve issue",
                action: { print("Error action") }
            )
        }

        Divider()

        // Compact status section with mock data
        HStack(spacing: 12) {
            StatusIndicator(
                title: "Screen Recording",
                systemImage: "video",
                state: .active,
                detail: "Screen recording permission granted"
            )

            StatusIndicator(
                title: "Hotkey",
                systemImage: "keyboard",
                state: .active,
                detail: "Global hotkey ⌘E is active. Click to test.",
                action: { print("Test hotkey") }
            )
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(.regularMaterial, in: .rect(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(.separator.opacity(0.3), lineWidth: 0.5)
        )
    }
    .padding()
    .background(.regularMaterial)
}
