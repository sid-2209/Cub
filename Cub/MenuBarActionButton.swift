//
//  MenuBarActionButton.swift
//  Cub
//
//  Created by sid on 17/09/25.
//

import SwiftUI

struct MenuBarActionButton: View {
    let title: String
    let systemImage: String
    let keyboardShortcut: KeyEquivalent?
    let modifiers: EventModifiers
    let destructive: Bool
    let action: () -> Void

    @State private var isHovered = false

    init(
        title: String,
        systemImage: String,
        keyboardShortcut: KeyEquivalent? = nil,
        modifiers: EventModifiers = [],
        destructive: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.keyboardShortcut = keyboardShortcut
        self.modifiers = modifiers
        self.destructive = destructive
        self.action = action
    }

    private var shortcutText: String? {
        guard let shortcut = keyboardShortcut else { return nil }

        var components: [String] = []

        if modifiers.contains(.command) {
            components.append("⌘")
        }
        if modifiers.contains(.option) {
            components.append("⌥")
        }
        if modifiers.contains(.control) {
            components.append("⌃")
        }
        if modifiers.contains(.shift) {
            components.append("⇧")
        }

        components.append(String(shortcut.character).uppercased())
        return components.joined()
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .medium))
                    .symbolVariant(.fill)
                    .frame(width: 16)

                Text(title)
                    .font(.system(size: 13, weight: .medium))

                Spacer()

                if let shortcut = shortcutText {
                    Text(shortcut)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }
            }
            .foregroundStyle(destructive ? .red : .primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(backgroundColor)
            )
            .scaleEffect(isHovered ? 1.01 : 1.0)
            .animation(.easeInOut(duration: 0.12), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
        .accessibilityLabel(title)
        .accessibilityHint(accessibilityHint)
        .if(keyboardShortcut != nil) { view in
            view.keyboardShortcut(keyboardShortcut!, modifiers: modifiers)
        }
    }

    private var backgroundColor: Color {
        if destructive && isHovered {
            return .red.opacity(0.1)
        } else if isHovered {
            return .primary.opacity(0.08)
        } else {
            return .clear
        }
    }

    private var accessibilityHint: String {
        if let shortcut = shortcutText {
            return "Keyboard shortcut: \(shortcut)"
        }
        return ""
    }
}

// Helper extension for conditional view modification
extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

struct MenuBarActionSection: View {
    let onPreferences: () -> Void
    let onQuit: () -> Void

    var body: some View {
        VStack(spacing: 4) {
            MenuBarActionButton(
                title: "Preferences",
                systemImage: "gear",
                keyboardShortcut: ",",
                modifiers: .command,
                action: onPreferences
            )

            MenuBarActionButton(
                title: "Quit Cub",
                systemImage: "power",
                keyboardShortcut: "q",
                modifiers: .command,
                destructive: true,
                action: onQuit
            )
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        MenuBarActionButton(
            title: "Preferences",
            systemImage: "gear",
            keyboardShortcut: ",",
            modifiers: .command,
            action: { }
        )

        MenuBarActionButton(
            title: "Test Hotkey",
            systemImage: "keyboard",
            keyboardShortcut: "e",
            modifiers: .command,
            action: { }
        )

        MenuBarActionButton(
            title: "Quit Cub",
            systemImage: "power",
            keyboardShortcut: "q",
            modifiers: .command,
            destructive: true,
            action: { }
        )

        Divider()

        MenuBarActionSection(
            onPreferences: { },
            onQuit: { }
        )
    }
    .padding()
    .frame(width: 200)
    .background(.regularMaterial)
}
