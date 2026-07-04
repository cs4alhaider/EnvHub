//
//  ScanView.swift
//  EnvHub
//
//  Sheet for discovering .env files: choose/remember folders, optional deep scan
//  (cancellable, with progress), then accept discovered projects.
//

import SwiftUI
import SwiftData
import AppKit
import Core
import Helper

struct ScanView: View {
    @Environment(\.scanService) private var scanService
    @Environment(\.modelContext) private var context
    @State private var model: ScanModel?

    var body: some View {
        Group {
            if let model {
                ScanContent(model: model)
            } else {
                ProgressView().frame(width: 560, height: 520)
            }
        }
        .task {
            if model == nil {
                model = ScanModel(scanService: scanService, deepScan: EnvHubStore.settings(in: context).deepScanDefault)
            }
        }
    }
}

private struct ScanContent: View {
    @Bindable var model: ScanModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \ScanFolderRecord.dateAdded) private var folders: [ScanFolderRecord]
    @State private var resultSearch = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            foldersSection
            Divider()
            controls
            Divider()
            resultsSection
            Divider()
            footer
        }
        // Compact before scanning; expands to make room for results.
        .frame(width: 580, height: model.isScanning || model.hasScanned ? 580 : 400)
        .animation(.snappy, value: model.hasScanned)
    }

    private var header: some View {
        HStack {
            Image(systemName: "magnifyingglass")
            Text("Scan for .env files").font(.headline)
            Spacer()
        }
        .padding(12)
    }

    private var foldersSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Folders to scan").font(.subheadline).foregroundStyle(.secondary)
                Spacer()
                Button { addFolder() } label: { Label("Add Folder", systemImage: "plus") }
            }
            if folders.isEmpty {
                Text("Add one or more folders (e.g. ~/Developer).")
                    .font(.caption).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 6)
            } else {
                ForEach(folders) { folder in
                    HStack {
                        Image(systemName: "folder")
                        Text(folder.path).lineLimit(1).truncationMode(.middle).monospaced().font(.caption)
                        Spacer()
                        Button(role: .destructive) { context.delete(folder) } label: {
                            Image(systemName: "minus.circle.fill")
                        }
                        .buttonStyle(.borderless).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(12)
    }

    private var controls: some View {
        HStack {
            Toggle("Deep scan (recurse into subfolders)", isOn: $model.deepScan)
            Spacer()
            if model.isScanning {
                Button("Cancel Scan", role: .cancel) { model.cancel() }
            } else {
                Button { runScan() } label: { Label("Scan", systemImage: "magnifyingglass") }
                    .buttonStyle(.borderedProminent)
                    .disabled(folders.isEmpty)
            }
        }
        .padding(12)
    }

    @ViewBuilder
    private var resultsSection: some View {
        if model.isScanning {
            VStack(alignment: .leading, spacing: 6) {
                ProgressView()
                Text("\(model.progress.directoriesVisited) folders · \(model.progress.filesFound) files")
                    .font(.caption).monospacedDigit()
                if let path = model.progress.currentPath {
                    Text(path).font(.caption2).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .padding()
        } else if model.results.isEmpty {
            ContentUnavailableView(
                model.hasScanned ? "No .env files found" : "Ready to scan",
                systemImage: model.hasScanned ? "doc.questionmark" : "sparkle.magnifyingglass",
                description: Text(model.hasScanned ? "Nothing matched under the chosen folders." : "Choose folders and press Scan.")
            )
            .frame(maxHeight: .infinity)
        } else {
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: "line.3.horizontal.decrease.circle").foregroundStyle(.secondary)
                    TextField("Filter results…", text: $resultSearch).textFieldStyle(.roundedBorder)
                    Button("Select All") { setSelection(filteredResults, selected: true) }
                    Button("Select None") { setSelection(filteredResults, selected: false) }
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
                Divider()
                List {
                    Section("\(filteredResults.count) shown · \(model.selected.count) selected") {
                        ForEach(filteredResults) { project in
                            Toggle(isOn: selectionBinding(project.folder)) {
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(project.name).fontWeight(.medium)
                                    Text("\(project.folder.path(percentEncoded: false)) · \(project.files.count) file\(project.files.count == 1 ? "" : "s")")
                                        .font(.caption).foregroundStyle(.secondary)
                                        .lineLimit(1).truncationMode(.middle)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var filteredResults: [DiscoveredProject] {
        let q = resultSearch.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return model.results }
        return model.results.filter {
            $0.name.lowercased().contains(q) || $0.folder.path(percentEncoded: false).lowercased().contains(q)
        }
    }

    private func setSelection(_ projects: [DiscoveredProject], selected: Bool) {
        for project in projects {
            if selected { model.selected.insert(project.folder) } else { model.selected.remove(project.folder) }
        }
    }

    private var footer: some View {
        HStack {
            Button("Close") { dismiss() }
            Spacer()
            Button("Add \(model.selected.count) Project\(model.selected.count == 1 ? "" : "s")") {
                model.addSelectedProjects(to: context)
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .disabled(model.selected.isEmpty)
        }
        .padding(12)
    }

    // MARK: Actions

    private func addFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = true
        panel.prompt = "Choose"
        guard panel.runModal() == .OK else { return }
        for url in panel.urls {
            let path = url.path(percentEncoded: false)
            if !folders.contains(where: { $0.path == path }) {
                context.insert(ScanFolderRecord(path: path))
            }
        }
    }

    private func runScan() {
        let settings = EnvHubStore.settings(in: context)
        model.run(roots: folders.map(\.url), baseConfig: settings.scanConfig)
    }

    private func selectionBinding(_ folder: URL) -> Binding<Bool> {
        Binding(
            get: { model.selected.contains(folder) },
            set: { on in
                if on { model.selected.insert(folder) } else { model.selected.remove(folder) }
            }
        )
    }
}
