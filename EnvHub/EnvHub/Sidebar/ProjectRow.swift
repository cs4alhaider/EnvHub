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
                // Home-relative + head-truncated: the tail of the path (the folders
                // that identify the project) stays visible however narrow the sidebar.
                Text(PathDisplay.homeRelative(project.path))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.head)
                    .help(project.path)
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
