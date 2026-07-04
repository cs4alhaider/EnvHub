//
//  EnvironmentCatalog+UI.swift
//  EnvHub
//
//  UI-only presentation for environments (kept out of the Model module): the palette
//  color mapping and the SwiftUI environment value that carries the user's catalog
//  down to every view. Injected from AppSettings at each window's root; defaults to
//  the built-in catalog so previews and detached views still render.
//

import SwiftUI
import Core

extension EnvColor {
    /// The concrete SwiftUI color for a palette slot.
    var color: Color {
        switch self {
        case .gray: .gray
        case .red: .red
        case .orange: .orange
        case .yellow: .yellow
        case .green: .green
        case .mint: .mint
        case .teal: .teal
        case .blue: .blue
        case .indigo: .indigo
        case .purple: .purple
        case .pink: .pink
        case .brown: .brown
        }
    }
}

extension EnvironmentValues {
    /// The active environment catalog (title/color/order/safe per kind). Views read it
    /// to render dots and titles; it's injected from AppSettings at each scene root.
    @Entry var environmentCatalog: EnvironmentCatalog = .builtin
}

extension EnvironmentCatalog {
    /// The status-dot color for a kind (gray for anything undefined).
    func tint(for kind: EnvKind) -> Color { color(for: kind).color }
}
