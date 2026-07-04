//
//  EnvironmentTabBar.swift
//  EnvHub
//
//  Development / Staging / Production / Other tabs, each with a status dot and the
//  total variable count for that environment.
//

import SwiftUI
import Core

struct EnvironmentTabBar: View {
    let kinds: [EnvKind]
    let counts: [EnvKind: Int]
    @Binding var selection: EnvKind?
    @Environment(\.environmentCatalog) private var catalog

    var body: some View {
        HStack(spacing: 6) {
            ForEach(kinds, id: \.self) { kind in
                let isSelected = selection == kind
                Button {
                    selection = kind
                } label: {
                    HStack(spacing: 6) {
                        Circle().fill(catalog.tint(for: kind)).frame(width: 7, height: 7)
                        Text(catalog.title(for: kind))
                            .fontWeight(isSelected ? .semibold : .regular)
                        if let count = counts[kind] {
                            Text("\(count)")
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(.quaternary, in: Capsule())
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(isSelected ? Color.accentColor.opacity(0.15) : .clear, in: Capsule())
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .foregroundStyle(isSelected ? Color.accentColor : .primary)
            }
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(.bar)
    }
}
