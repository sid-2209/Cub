//
//  ClipboardVisibilityMode.swift
//  Cub
//
//  Created by sid on 17/09/25.
//

import Foundation

enum ClipboardVisibilityMode: String, CaseIterable {
    case hidden = "hidden"
    case show = "show"
    case alwaysShow = "alwaysShow"

    var displayName: String {
        switch self {
        case .hidden:
            return "Hide"
        case .show:
            return "Show"
        case .alwaysShow:
            return "Always Show"
        }
    }

    var description: String {
        switch self {
        case .hidden:
            return "Clipboard window disabled"
        case .show:
            return "Show when needed, auto-dim and auto-hide available"
        case .alwaysShow:
            return "Always visible, auto-dim only"
        }
    }

    var allowsAutoDimming: Bool {
        switch self {
        case .hidden:
            return false
        case .show, .alwaysShow:
            return true
        }
    }

    var allowsAutoHiding: Bool {
        switch self {
        case .hidden, .alwaysShow:
            return false
        case .show:
            return true
        }
    }

    // Migration helper from old boolean preference
    static func fromLegacyPreference(alwaysShow: Bool) -> ClipboardVisibilityMode {
        return alwaysShow ? .alwaysShow : .show
    }
}
