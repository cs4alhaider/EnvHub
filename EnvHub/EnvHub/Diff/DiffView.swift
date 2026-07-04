//
//  DiffView.swift
//  EnvHub
//
//  Read-only side-by-side comparison of two environments in a project.
//

import SwiftUI
import Core

struct DiffView: View {
    let files: [EnvFile]
    @Environment(\.dismiss) private var dismiss

    @State private var leftURL: URL?
    @State private var rightURL: URL?
    @State private var reveal = false
    @State private var entries: [EnvDiffEntry] = []

    var body: some View {
        VStack(spacing: 0) {
            controls
            Divider()
            columnHeaders
            Divider()
            diffList
            Divider()
            footer
        }
        .frame(width: 760, height: 560)
        .onAppear(perform: setDefaults)
        .task(id: pairKey) { recompute() }
    }

    private var controls: some View {
        HStack(spacing: 12) {
            filePicker("Left", selection: $leftURL)
            Image(systemName: "arrow.left.arrow.right").foregroundStyle(.secondary)
            filePicker("Right", selection: $rightURL)
            Spacer()
            Toggle(isOn: $reveal) { Image(systemName: reveal ? "eye.slash" : "eye") }
                .toggleStyle(.button)
                .help(reveal ? "Hide values" : "Reveal values")
        }
        .padding(12)
    }

    private func filePicker(_ label: String, selection: Binding<URL?>) -> some View {
        Picker(label, selection: selection) {
            ForEach(files) { file in
                Text("\(file.kind.title) · \(file.fileName)").tag(Optional(file.path))
            }
        }
        .frame(maxWidth: 260)
    }

    private var columnHeaders: some View {
        HStack {
            Text("Key").frame(width: 200, alignment: .leading)
            Text(leftURL?.lastPathComponent ?? "—").frame(maxWidth: .infinity, alignment: .leading)
            Text(rightURL?.lastPathComponent ?? "—").frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.caption).foregroundStyle(.secondary).monospaced()
        .padding(.horizontal, 12).padding(.vertical, 4)
    }

    @ViewBuilder
    private var diffList: some View {
        if entries.isEmpty {
            ContentUnavailableView("Nothing to Compare", systemImage: "equal.square",
                description: Text("Pick two files to see their differences."))
        } else {
            List(entries) { entry in
                HStack(alignment: .top, spacing: 8) {
                    Text(entry.key)
                        .monospaced().frame(width: 200, alignment: .leading)
                    value(entry.leftValue, absent: entry.state == .rightOnly)
                    value(entry.rightValue, absent: entry.state == .leftOnly)
                    icon(for: entry.state)
                }
                .listRowBackground(background(for: entry.state))
            }
        }
    }

    private func value(_ text: String?, absent: Bool) -> some View {
        Group {
            if absent || text == nil {
                Text("—").foregroundStyle(.tertiary)
            } else {
                Text(reveal ? (text ?? "") : ValueMasking.masked(text ?? ""))
                    .foregroundStyle(.primary)
            }
        }
        .monospaced()
        .frame(maxWidth: .infinity, alignment: .leading)
        .textSelection(.enabled)
    }

    @ViewBuilder
    private func icon(for state: EnvDiffEntry.State) -> some View {
        switch state {
        case .same: Image(systemName: "equal").foregroundStyle(.secondary)
        case .different: Image(systemName: "notequal").foregroundStyle(.orange)
        case .leftOnly: Image(systemName: "arrow.left").foregroundStyle(.red)
        case .rightOnly: Image(systemName: "arrow.right").foregroundStyle(.red)
        }
    }

    private func background(for state: EnvDiffEntry.State) -> Color {
        switch state {
        case .same: .clear
        case .different: .orange.opacity(0.10)
        case .leftOnly, .rightOnly: .red.opacity(0.08)
        }
    }

    private var footer: some View {
        let s = EnvDiff.summary(entries)
        return HStack(spacing: 14) {
            legend(".same", count: s.same, color: .secondary)
            legend("differ", count: s.different, color: .orange)
            legend("only left", count: s.leftOnly, color: .red)
            legend("only right", count: s.rightOnly, color: .red)
            Spacer()
            Button("Done") { dismiss() }.keyboardShortcut(.defaultAction)
        }
        .font(.caption)
        .padding(12)
    }

    private func legend(_ label: String, count: Int, color: Color) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text("\(count) \(label)").foregroundStyle(.secondary)
        }
    }

    // MARK: Helpers

    private var pairKey: String { "\(leftURL?.path ?? "")|\(rightURL?.path ?? "")" }

    private func setDefaults() {
        if leftURL == nil { leftURL = files.first?.path }
        if rightURL == nil { rightURL = (files.count > 1 ? files.last : files.first)?.path }
    }

    private func recompute() {
        guard let l = leftURL, let r = rightURL else { entries = []; return }
        let lv = (try? EnvFileService.load(l))?.variables ?? []
        let rv = (try? EnvFileService.load(r))?.variables ?? []
        entries = EnvDiff.compare(left: lv, right: rv)
    }
}
