//
//  EnvKind+UI.swift
//  EnvHub
//
//  UI-only presentation for environments (kept out of the Model module).
//

import SwiftUI
import Core

extension EnvKind {
    /// Status-dot color used on environment tabs.
    var tint: Color {
        switch self {
        case .development: .green
        case .staging: .orange
        case .production: .red
        case .local: .blue
        case .example: .purple
        case .other: .gray
        }
    }
}
