//
//  FileInfoPopover.swift
//  EnvHub
//
//  The ⓘ popover in the editor bar: on-disk details for the open env file
//  (created / modified / size / backup), a read-only badge, and a shortcut to
//  reveal the file itself in Finder.
//

import SwiftUI
import Core

struct FileInfoPopover: View {
    let model: EnvFileEditorModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "doc.text").foregroundStyle(.secondary)
                Text(model.fileURL.lastPathComponent).monospaced().fontWeight(.semibold)
                if model.fileInfo?.isWritable == false {
                    Text("Read-only")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.orange.opacity(0.15), in: Capsule())
                        .help("You don't have permission to write to this file.")
                }
            }

            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 14, verticalSpacing: 7) {
                row("Created", dateString(model.fileInfo?.createdAt))
                row("Modified", dateString(model.fileInfo?.modifiedAt))
                row("Size", sizeString)
                row("Variables", "\(model.variableCount)")
                row("Backup", backupString)
            }
            .font(.callout)

            Divider()

            Button("Reveal in Finder", systemImage: "magnifyingglass") {
                FinderActions.reveal(model.fileURL)
            }
            .buttonStyle(.link)
            .font(.caption)
        }
        .padding(14)
        .frame(maxWidth: 340, alignment: .leading)
        .task { await model.refreshFileInfo() }
    }

    private func row(_ label: String, _ value: String) -> some View {
        GridRow {
            Text(label).foregroundStyle(.secondary).gridColumnAlignment(.trailing)
            Text(value)
        }
    }

    private func dateString(_ date: Date?) -> String {
        date?.formatted(date: .abbreviated, time: .shortened) ?? "—"
    }

    private var sizeString: String {
        model.fileInfo?.sizeBytes.map { Int64($0).formatted(.byteCount(style: .file)) } ?? "—"
    }

    /// "env.bak · 2 hours ago" when backup-on-save has run; "None yet" before the
    /// first in-app save.
    private var backupString: String {
        guard let info = model.fileInfo, let name = info.backupFileName else { return "None yet" }
        if let date = info.backupModifiedAt {
            return "\(name) · \(date.formatted(.relative(presentation: .named)))"
        }
        return name
    }
}
