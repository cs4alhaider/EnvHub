//
//  ProjectRow.swift
//  EnvHub
//
//  One sidebar row: pin indicator, name, path, and an env-file count badge.
//

import SwiftUI
import Core

struct ProjectRow: View {
    let project: ProjectRecord
    let fileCount: Int

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "folder.fill")
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    if project.isPinned {
                        Image(systemName: "pin.fill").font(.caption2).foregroundStyle(.orange)
                    }
                    Text(project.name).lineLimit(1)
                }
                Text(project.path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: 4)
            if fileCount > 0 {
                Text("\(fileCount)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(.quaternary, in: Capsule())
            }
        }
    }
}
