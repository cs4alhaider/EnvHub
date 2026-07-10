//
//  SaveReviewSheet.swift
//  EnvHub
//
//  Shown when the user clicks Save: a key-by-key review of what will change on
//  disk (values masked by default), plus a note that saving is local-only — no
//  git commit — and that the previous version is kept as a .bak backup.
//

import SwiftUI
import Core

struct SaveReviewSheet: View {
    let fileName: String
    let backupName: String
    let changes: [EnvChange]
    let onConfirm: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var reveal = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header.padding(14)
            Divider()
            content
            Divider()
            footer.padding(12)
        }
        .frame(width: 540)
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Save \(fileName)?").font(.title3.bold())
                Text(summaryLine).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if changes.contains(where: { $0.valueChanged }) {
                Toggle(isOn: $reveal) { Image(systemName: reveal ? "eye.slash" : "eye") }
                    .toggleStyle(.button)
                    .help(reveal ? "Hide values" : "Reveal values")
            }
        }
    }

    private var summaryLine: String {
        let added = changes.filter { $0.kind == .added }.count
        let removed = changes.filter { $0.kind == .removed }.count
        let modified = changes.filter { $0.kind == .modified }.count
        var parts: [String] = []
        if added > 0 { parts.append("\(added) added") }
        if modified > 0 { parts.append("\(modified) changed") }
        if removed > 0 { parts.append("\(removed) removed") }
        return parts.isEmpty ? "Review before writing to disk" : parts.joined(separator: " · ")
    }

    // MARK: Changes

    @ViewBuilder
    private var content: some View {
        if changes.isEmpty {
            VStack(spacing: 6) {
                Image(systemName: "text.alignleft").font(.title2).foregroundStyle(.secondary)
                Text("No variable changes — only formatting, ordering, or standalone comments changed.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)
            .padding(.horizontal, 20)
        } else {
            List(changes) { change in
                changeRow(change)
            }
            .listStyle(.inset)
            .frame(height: listHeight)
        }
    }

    /// Hug small reviews, scroll big ones. A modified row showing both a value line
    /// and a comment line is taller than the rest.
    private var listHeight: CGFloat {
        let rows = changes.reduce(CGFloat(0)) { total, change in
            let hasExtraLine = change.kind == .modified && change.valueChanged && change.commentChanged
            return total + 46 + (hasExtraLine ? 22 : 0)
        }
        return min(320, max(110, rows + 16))
    }

    private func changeRow(_ change: EnvChange) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            icon(for: change.kind)
            VStack(alignment: .leading, spacing: 3) {
                Text(change.key).monospaced().fontWeight(.medium)
                switch change.kind {
                case .added:
                    valueText(change.newValue)
                case .removed:
                    valueText(change.oldValue).strikethrough()
                case .modified:
                    if change.valueChanged {
                        HStack(spacing: 6) {
                            valueText(change.oldValue)
                            Image(systemName: "arrow.right").font(.caption2).foregroundStyle(.secondary)
                            valueText(change.newValue)
                        }
                    }
                    if change.commentChanged {
                        Text(commentDescription(old: change.oldComment, new: change.newComment))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .italic()
                            .lineLimit(1)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
        .listRowBackground(rowBackground(for: change.kind))
    }

    @ViewBuilder
    private func icon(for kind: EnvChange.Kind) -> some View {
        switch kind {
        case .added: Image(systemName: "plus.circle.fill").foregroundStyle(.green)
        case .removed: Image(systemName: "minus.circle.fill").foregroundStyle(.red)
        case .modified: Image(systemName: "pencil.circle.fill").foregroundStyle(.orange)
        }
    }

    private func rowBackground(for kind: EnvChange.Kind) -> Color {
        switch kind {
        case .added: .green.opacity(0.08)
        case .removed: .red.opacity(0.08)
        case .modified: .orange.opacity(0.08)
        }
    }

    /// Values stay masked unless the eye toggle is on. Comments are plain text in
    /// the file, so they're never masked.
    private func valueText(_ value: String?) -> Text {
        guard let value, !value.isEmpty else {
            return Text("(empty)").foregroundStyle(.tertiary)
        }
        return Text(reveal ? value : ValueMasking.masked(value)).monospaced()
    }

    private func commentDescription(old: String?, new: String?) -> String {
        switch (old, new) {
        case (nil, let new?): "+ # \(new)"
        case (let old?, nil): "− # \(old)"
        case (let old?, let new?): "# \(old) → # \(new)"
        case (nil, nil): ""
        }
    }

    // MARK: Footer

    private var footer: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label {
                Text("Saving only writes this file on your Mac — nothing is committed to git. The previous version is kept as \(Text(backupName).monospaced()).")
            } icon: {
                Image(systemName: "info.circle")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") {
                    onConfirm()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
        }
    }
}
