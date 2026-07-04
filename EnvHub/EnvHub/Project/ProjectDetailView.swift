//
//  ProjectDetailView.swift
//  EnvHub
//
//  Environment tabs (with per-file variable counts) over the editor, plus a git-tracking
//  warning, create-file, Finder actions, and .gitignore management.
//

import SwiftUI
import SwiftData
import Core

struct ProjectDetailView: View {
    let project: ProjectRecord
    @Environment(\.modelContext) private var context
    @Environment(\.environmentCatalog) private var catalog

    @State private var classified: [EnvFile] = []
    @State private var selectedFile: URL?
    @State private var editor: EnvFileEditorModel?
    @State private var metadata = ProjectMetadata.empty

    // Sheets / confirmation
    @State private var pendingFile: URL?
    @State private var confirmSwitch = false
    @State private var showDiff = false
    @State private var showExport = false
    @State private var showNewFile = false

    private var currentEnvFile: EnvFile? { classified.first { $0.path == selectedFile } }

    var body: some View {
        VStack(spacing: 0) {
            if !classified.isEmpty {
                EnvironmentTabBar(kinds: kinds, counts: kindCounts, selection: kindBinding)
                if let kind = selectedKind, filesForKind(kind).count > 1 {
                    Divider()
                    filePicker(for: kind)
                }
                Divider()
            }

            // Example/template files are *meant* to be committed — no warning for them.
            if let url = selectedFile,
               !(currentEnvFile.map { catalog.isSafeToTrack($0.kind) } ?? false),
               metadata.gitInfo.status(for: url)?.isTracked == true {
                GitTrackingBanner(fileURL: url) { unstageAndIgnore(url) }
            }

            if let editor {
                EnvFileEditor(model: editor)
                    .id(editor.fileURL)
            } else {
                ContentUnavailableView {
                    Label("No .env files", systemImage: "doc")
                } description: {
                    Text("This folder has no .env files yet.")
                } actions: {
                    Button("Create .env File…") { showNewFile = true }
                }
            }
        }
        .navigationTitle(project.name)
        .navigationSubtitle(project.path)
        .toolbar { toolbarContent }
        .sheet(isPresented: $showDiff) { DiffView(files: classified) }
        .sheet(isPresented: $showExport) {
            ExportSheet(projectName: project.name, currentFile: currentEnvFile, allFiles: classified)
        }
        .sheet(isPresented: $showNewFile) {
            NewEnvFileSheet(projectFolder: project.url, existingFiles: classified) { url in
                Task { await reload(select: url) }
            }
        }
        .task(id: project.path) { await reload(select: nil) }
        .confirmationDialog(
            "You have unsaved changes",
            isPresented: $confirmSwitch,
            titleVisibility: .visible
        ) {
            Button("Save & Switch") { editor?.save(); commitSwitch() }
            Button("Discard Changes", role: .destructive) { commitSwitch() }
            Button("Cancel", role: .cancel) { pendingFile = nil }
        } message: {
            Text("Switching will lose unsaved changes to \(selectedFile?.lastPathComponent ?? "this file").")
        }
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem {
            Menu {
                Button("Reveal in Finder", systemImage: "magnifyingglass") { FinderActions.reveal(project.url) }
                Button("Open in Finder", systemImage: "folder") { FinderActions.open(project.url) }
                Button("Copy Path", systemImage: "doc.on.doc") { FinderActions.copyPath(project.url) }
                if let url = selectedFile, metadata.gitInfo.isRepo {
                    Divider()
                    if metadata.gitignoredFileNames.contains(url.lastPathComponent) {
                        Button("Remove \(url.lastPathComponent) from .gitignore", systemImage: "eye") {
                            toggleGitignore(url, add: false)
                        }
                    } else {
                        Button("Add \(url.lastPathComponent) to .gitignore", systemImage: "eye.slash") {
                            toggleGitignore(url, add: true)
                        }
                    }
                }
            } label: {
                Label("Project Actions", systemImage: "ellipsis.circle")
            }
            .help("Reveal in Finder, copy path, manage .gitignore")
        }
        ToolbarItem {
            Button { showNewFile = true } label: { Label("New File", systemImage: "plus") }
                .help("Create a new env file")
        }
        if !classified.isEmpty {
            ToolbarItem {
                Button { showExport = true } label: { Label("Export", systemImage: "lock.doc") }
                    .help("Export an encrypted .envenc")
            }
        }
        if classified.count >= 2 {
            ToolbarItem {
                Button { showDiff = true } label: { Label("Compare", systemImage: "arrow.left.arrow.right") }
                    .help("Compare two environments side by side")
            }
        }
    }

    // MARK: Derived

    private var kinds: [EnvKind] {
        catalog.sorted(Set(classified.map(\.kind)))
    }

    private var kindCounts: [EnvKind: Int] {
        var counts: [EnvKind: Int] = [:]
        for file in classified {
            counts[file.kind, default: 0] += metadata.variableCounts[file.path] ?? 0
        }
        return counts
    }

    private var selectedKind: EnvKind? {
        classified.first { $0.path == selectedFile }?.kind
    }

    private func filesForKind(_ kind: EnvKind) -> [URL] {
        classified.filter { $0.kind == kind }.map(\.path).sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    private var kindBinding: Binding<EnvKind?> {
        Binding(
            get: { selectedKind },
            set: { newKind in
                if let k = newKind, let first = filesForKind(k).first { requestSwitch(to: first) }
            }
        )
    }

    private func filePicker(for kind: EnvKind) -> some View {
        Picker("File", selection: Binding(get: { selectedFile }, set: { requestSwitch(to: $0) })) {
            ForEach(filesForKind(kind), id: \.self) { url in
                Text("\(url.lastPathComponent) (\(metadata.variableCounts[url] ?? 0))").tag(Optional(url))
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .padding(8)
    }

    // MARK: Actions

    /// Re-list + classify the folder's env files, open an editor on `url` (or the first
    /// file in tab order), then refresh metadata off the main actor.
    private func reload(select url: URL?) async {
        let settings = EnvHubStore.settings(in: context)
        classified = ProjectLoader.envFiles(
            in: project.url,
            rules: settings.classificationRules,
            patterns: settings.filenamePatterns
        )
        let target = url ?? kinds.first.flatMap { filesForKind($0).first } ?? classified.first?.path
        selectedFile = target
        openEditor(for: target)
        await refreshMetadata()
    }

    private func refreshMetadata() async {
        metadata = await ProjectMetadata.load(folder: project.url, files: classified.map(\.path))
    }

    private func openEditor(for url: URL?) {
        if let url {
            editor = EnvFileEditorModel(fileURL: url, maskByDefault: EnvHubStore.settings(in: context).maskByDefault)
        } else {
            editor = nil
        }
    }

    private func requestSwitch(to url: URL?) {
        guard url != selectedFile else { return }
        if let editor, editor.isDirty {
            pendingFile = url
            confirmSwitch = true
        } else {
            selectedFile = url
            openEditor(for: url)
        }
    }

    private func commitSwitch() {
        selectedFile = pendingFile
        openEditor(for: pendingFile)
        pendingFile = nil
    }

    private func unstageAndIgnore(_ url: URL) {
        Task {
            try? await GitService.unstageAndIgnore(url, in: project.url)
            await refreshMetadata()
        }
    }

    private func toggleGitignore(_ url: URL, add: Bool) {
        Task {
            if add {
                try? await GitService.addToGitignore(url.lastPathComponent, folder: project.url)
            } else {
                try? await GitService.removeFromGitignore(url.lastPathComponent, folder: project.url)
            }
            await refreshMetadata()
        }
    }
}
