//
//  PreferenceComponents.swift
//  Cub
//
//  Created by sid on 17/09/25.
//

import SwiftUI
import Foundation

// MARK: - Preference Section Container

struct PreferenceSection<Content: View>: View {
    let title: String
    let systemImage: String?
    let content: () -> Content

    init(
        _ title: String,
        systemImage: String? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.systemImage = systemImage
        self.content = content
    }

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 16) {
                // Section Header
                HStack(spacing: 8) {
                    if let systemImage = systemImage {
                        Image(systemName: systemImage)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 20)
                    }

                    Text(title)
                        .font(.headline)
                        .dynamicTypeSize(.large...)
                        .foregroundStyle(.primary)

                    Spacer()
                }
                .accessibilityAddTraits(.isHeader)

                // Section Content
                VStack(alignment: .leading, spacing: 12) {
                    content()
                }
            }
            .padding()
        }
    }
}

// MARK: - Preference Row Components

struct PreferenceToggle: View {
    let title: String
    let subtitle: String?
    @Binding var isOn: Bool
    let systemImage: String?
    let disabled: Bool

    init(
        _ title: String,
        subtitle: String? = nil,
        systemImage: String? = nil,
        isOn: Binding<Bool>,
        disabled: Bool = false
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self._isOn = isOn
        self.disabled = disabled
    }

    var body: some View {
        HStack(spacing: 12) {
            if let systemImage = systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(disabled ? .tertiary : .secondary)
                    .frame(width: 16)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .dynamicTypeSize(.small...)
                    .foregroundStyle(disabled ? .tertiary : .primary)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .dynamicTypeSize(.xSmall...)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .disabled(disabled)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityHint(subtitle ?? "")
        .accessibilityValue(isOn ? "On" : "Off")
    }
}

struct PreferencePicker<T: Hashable & CaseIterable & RawRepresentable>: View where T.RawValue == String {
    let title: String
    let subtitle: String?
    let systemImage: String?
    @Binding var selection: T
    let options: [T]
    let style: PickerStyle

    enum PickerStyle {
        case segmented
        case menu
        case inline
    }

    init(
        _ title: String,
        subtitle: String? = nil,
        systemImage: String? = nil,
        selection: Binding<T>,
        options: [T] = Array(T.allCases),
        style: PickerStyle = .segmented
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self._selection = selection
        self.options = options
        self.style = style
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                if let systemImage = systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 16)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.primary)

                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer()
            }

            pickerView
                .accessibilityLabel(title)
                .accessibilityHint(subtitle ?? "")
        }
    }

    @ViewBuilder
    private var pickerView: some View {
        switch style {
        case .segmented:
            segmentedPicker
        case .menu:
            menuPicker
        case .inline:
            inlinePicker
        }
    }

    private var segmentedPicker: some View {
        Picker(title, selection: $selection) {
            ForEach(options, id: \.self) { option in
                Text(displayName(for: option)).tag(option)
            }
        }
        .pickerStyle(.segmented)
    }

    private var menuPicker: some View {
        Picker(title, selection: $selection) {
            ForEach(options, id: \.self) { option in
                Text(displayName(for: option)).tag(option)
            }
        }
        .pickerStyle(.menu)
    }

    private var inlinePicker: some View {
        Picker(title, selection: $selection) {
            ForEach(options, id: \.self) { option in
                Text(displayName(for: option)).tag(option)
            }
        }
        .pickerStyle(.inline)
    }

    private func displayName(for option: T) -> String {
        if let displayable = option as? any DisplayNameProvider {
            return displayable.displayName
        }
        return String(describing: option)
    }
}

// MARK: - Specialized Components

struct PreferenceSlider: View {
    let title: String
    let subtitle: String?
    let systemImage: String?
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let formatter: NumberFormatter?

    init(
        _ title: String,
        subtitle: String? = nil,
        systemImage: String? = nil,
        value: Binding<Double>,
        in range: ClosedRange<Double>,
        step: Double = 0.1,
        formatter: NumberFormatter? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self._value = value
        self.range = range
        self.step = step
        self.formatter = formatter
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                if let systemImage = systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 16)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(title)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.primary)

                        Spacer()

                        Text(formattedValue)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }

                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            Slider(value: $value, in: range, step: step)
                .accessibilityLabel(title)
                .accessibilityValue(formattedValue)
                .accessibilityHint(subtitle ?? "")
        }
    }

    private var formattedValue: String {
        if let formatter = formatter {
            return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
        }
        return String(format: "%.1f", value)
    }
}

struct PreferenceColorPicker: View {
    let title: String
    let subtitle: String?
    let systemImage: String?
    @Binding var selectedIndex: Int
    let colors: [Color]
    let colorNames: [String]

    init(
        _ title: String,
        subtitle: String? = nil,
        systemImage: String? = nil,
        selectedIndex: Binding<Int>,
        colors: [Color],
        colorNames: [String]
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self._selectedIndex = selectedIndex
        self.colors = colors
        self.colorNames = colorNames
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerSection
            colorGrid
            selectedColorText
        }
    }

    private var headerSection: some View {
        HStack(spacing: 12) {
            if let systemImage = systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 16)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer()
        }
    }

    private var colorGrid: some View {
        let columns = Array(repeating: GridItem(.flexible()), count: min(colors.count, 5))

        return LazyVGrid(columns: columns, spacing: 12) {
            ForEach(0..<colors.count, id: \.self) { index in
                ColorButton(
                    color: colors[index],
                    isSelected: selectedIndex == index,
                    accessibilityLabel: colorNames[safe: index] ?? "Color \(index + 1)"
                ) {
                    selectedIndex = index
                }
            }
        }
    }

    @ViewBuilder
    private var selectedColorText: some View {
        if selectedIndex < colorNames.count {
            Text("Selected: \(colorNames[selectedIndex])")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Color Button Component

private struct ColorButton: View {
    let color: Color
    let isSelected: Bool
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            colorShape
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private var colorShape: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(color)
            .frame(width: 32, height: 32)
            .overlay(strokeOverlay)
            .scaleEffect(isSelected ? 1.1 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: isSelected)
    }

    private var strokeOverlay: some View {
        RoundedRectangle(cornerRadius: 8)
            .stroke(strokeColor, lineWidth: 2)
    }

    private var strokeColor: Color {
        isSelected ? .primary : .clear
    }
}

struct PreferenceButton: View {
    let title: String
    let subtitle: String?
    let systemImage: String?
    let action: () -> Void
    let style: ButtonStyle

    enum ButtonStyle {
        case primary
        case secondary
        case destructive
    }

    init(
        _ title: String,
        subtitle: String? = nil,
        systemImage: String? = nil,
        style: ButtonStyle = .secondary,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.style = style
        self.action = action
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let subtitle = subtitle {
                VStack(alignment: .leading, spacing: 2) {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Button(action: action) {
                HStack(spacing: 8) {
                    if let systemImage = systemImage {
                        Image(systemName: systemImage)
                            .font(.system(size: 13, weight: .medium))
                    }

                    Text(title)
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundStyle(foregroundColor)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(backgroundColor, in: .rect(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(title)
            .accessibilityHint(subtitle ?? "")
        }
    }

    private var foregroundColor: Color {
        switch style {
        case .primary:
            return .white
        case .secondary:
            return .primary
        case .destructive:
            return .red
        }
    }

    private var backgroundColor: Color {
        switch style {
        case .primary:
            return .accentColor
        case .secondary:
            return .primary.opacity(0.1)
        case .destructive:
            return .red.opacity(0.1)
        }
    }
}

// MARK: - Supporting Protocols

protocol DisplayNameProvider {
    var displayName: String { get }
}

// MARK: - Array Extension for Safe Access

extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
