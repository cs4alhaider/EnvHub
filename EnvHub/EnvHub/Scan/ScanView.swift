//
//  ScanView.swift
//  EnvHub
//
//  Sheet for discovering .env files: choose/remember folders, optional deep scan
//  (parallel, cancellable with Stop & Review), already-added results are marked and
//  skipped, and accepted projects can land straight in a workspace.
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
                // Match ScanContent's initial (compact) size so the sheet doesn't jump
                // when the model finishes loading.
                ProgressView().frame(width: 580, height: 400)
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
    @Query private var projects: [ProjectRecord]
    @Query private var workspaceRows: [WorkspaceRecord]
    @State private var resultSearch = ""
    @State private var destinationWorkspaceID: UUID?

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
                Button { model.stop() } label: { Label("Stop & Review", systemImage: "stop.circle") }
                    .help("Stop the scan and review what has been found so far")
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
                    Button("Select All") { setSelection(selectableResults, selected: true) }
                    Button("Select None") { setSelection(filteredResults, selected: false) }
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
                Divider()
                List {
                    Section(resultsSummary) {
                        ForEach(filteredResults) { project in
                            resultRow(project)
                        }
                    }
                }
            }
        }
    }

    private func resultRow(_ project: DiscoveredProject) -> some View {
        let added = model.isAlreadyAdded(project)
        return Toggle(isOn: selectionBinding(project.folder)) {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(project.name).fontWeight(.medium)
                    Text(project.folder.path(percentEncoded: false))
                        .font(.caption).foregroundStyle(.secondary)
                        .lineLimit(1).truncationMode(.middle)
                    Text(project.files.map(\.lastPathComponent).joined(separator: " · "))
                        .font(.caption2).foregroundStyle(.tertiary).monospaced()
                        .lineLimit(1).truncationMode(.tail)
                }
                Spacer(minLength: 8)
                if added {
                    Text("Added")
                        .font(.caption2.weight(.medium))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(.quaternary, in: Capsule())
                        .foregroundStyle(.secondary)
                        .help("Already in your sidebar — re-importing is skipped")
                }
            }
        }
        .disabled(added)
    }

    /// "42 found · 3 already added · 2.4s" — the after-scan summary in the list header.
    private var resultsSummary: String {
        var parts = ["\(filteredResults.count) shown", "\(model.selected.count) selected"]
        if !model.alreadyAdded.isEmpty {
            parts.append("\(model.alreadyAdded.count) already added")
        }
        if let duration = model.scanDuration {
            let seconds = Double(duration.components.seconds)
                + Double(duration.components.attoseconds) / 1e18
            parts.append(String(format: "%.1fs", seconds))
        }
        return parts.joined(separator: " · ")
    }

    private var filteredResults: [DiscoveredProject] {
        let q = resultSearch.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return model.results }
        return model.results.filter {
            $0.name.lowercased().contains(q) || $0.folder.path(percentEncoded: false).lowercased().contains(q)
        }
    }

    /// What "Select All" targets: visible results that aren't already in the sidebar.
    private var selectableResults: [DiscoveredProject] {
        filteredResults.filter { !model.isAlreadyAdded($0) }
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
            if !workspaces.isEmpty {
                Picker("Add to", selection: $destinationWorkspaceID) {
                    Text("No Workspace").tag(UUID?.none)
                    ForEach(workspaces) { workspace in
                        Text(workspace.name).tag(Optional(workspace.id))
                    }
                }
                .fixedSize()
                .help("Which sidebar workspace the imported projects go into")
            }
            Button("Add \(model.selected.count) Project\(model.selected.count == 1 ? "" : "s")") {
                model.addSelectedProjects(to: context, workspaceID: destinationWorkspaceID)
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .disabled(model.selected.isEmpty)
        }
        .padding(12)
    }

    private var workspaces: [WorkspaceRecord] {
        WorkspaceStore.orderedWorkspaces(workspaceRows)
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
        model.run(
            roots: folders.map(\.url),
            baseConfig: settings.scanConfig,
            existingProjectPaths: Set(projects.map { ProjectStore.canonicalPath(for: $0.url) })
        )
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
