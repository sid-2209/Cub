//
//  MenuBarModeButton.swift
//  Cub
//
//  Created by sid on 17/09/25.
//

import SwiftUI

struct MenuBarModeButton: View {
    let mode: ClipboardVisibilityMode
    let currentMode: ClipboardVisibilityMode
    let action: () -> Void

    @State private var isHovered = false

    private var isSelected: Bool {
        mode == currentMode
    }

    private var symbolName: String {
        switch mode {
        case .show:
            return "eye"
        case .alwaysShow:
            return "eye.fill"
        case .hidden:
            return "eye.slash"
        }
    }

    private var accessibilityLabel: String {
        let statusText = isSelected ? "selected" : "not selected"
        return "\(mode.displayName) mode, \(statusText)"
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: symbolName)
                    .font(.system(size: 14, weight: .medium))
                    .symbolVariant(isSelected ? .fill : .none)

                Text(mode.displayName)
                    .font(.system(size: 10, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(isSelected ? .primary : .secondary)
            .frame(minWidth: 60, minHeight: 44)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(backgroundColor)
            )
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: isHovered)
            .animation(.easeInOut(duration: 0.2), value: isSelected)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Switches clipboard window to \(mode.description)")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private var backgroundColor: Color {
        if isSelected {
            return .accentColor.opacity(0.2)
        } else if isHovered {
            return .primary.opacity(0.08)
        } else {
            return .clear
        }
    }
}

struct MenuBarModeButtonGroup: View {
    let currentMode: ClipboardVisibilityMode
    let onModeChange: (ClipboardVisibilityMode) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Clipboard Mode")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            HStack(spacing: 0) {
                MenuBarModeButton(
                    mode: .show,
                    currentMode: currentMode,
                    action: { onModeChange(.show) }
                )

                MenuBarModeButton(
                    mode: .alwaysShow,
                    currentMode: currentMode,
                    action: { onModeChange(.alwaysShow) }
                )

                MenuBarModeButton(
                    mode: .hidden,
                    currentMode: currentMode,
                    action: { onModeChange(.hidden) }
                )
            }
            .background(.regularMaterial, in: .rect(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.separator.opacity(0.5), lineWidth: 0.5)
            )
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        MenuBarModeButtonGroup(
            currentMode: .show,
            onModeChange: { _ in }
        )

        MenuBarModeButtonGroup(
            currentMode: .alwaysShow,
            onModeChange: { _ in }
        )

        MenuBarModeButtonGroup(
            currentMode: .hidden,
            onModeChange: { _ in }
        )
    }
    .padding()
    .background(.regularMaterial)
}
