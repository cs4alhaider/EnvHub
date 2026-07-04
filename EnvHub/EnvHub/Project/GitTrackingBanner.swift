//
//  GitTrackingBanner.swift
//  EnvHub
//
//  Warning strip shown when the selected env file is tracked by git — offering the
//  one-click "Unstage & Ignore" remedy.
//

import SwiftUI

struct GitTrackingBanner: View {
    let fileURL: URL
    let onUnstageAndIgnore: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 1) {
                Text("\(fileURL.lastPathComponent) is tracked by git").fontWeight(.medium)
                Text("Secrets here could be committed. Unstage it and add it to .gitignore.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button("Unstage & Ignore", action: onUnstageAndIgnore)
                .buttonStyle(.borderedProminent)
                .tint(.orange)
        }
        .padding(10)
        .background(.orange.opacity(0.12))
    }
}
