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

    @State private var classified: [EnvFile] = []
    @State private var selectedFile: URL?
    @State private var editor: EnvFileEditorModel?

    @State private var fileVarCounts: [URL: Int] = [:]
    @State private var gitInfo: GitInfo?
    @State private var gitignored: [String: Bool] = [:]

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

            gitBanner

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
                reload(select: url)
            }
        }
        .task(id: project.path) { loadFiles() }
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
                if let url = selectedFile, gitInfo?.isRepo == true {
                    Divider()
                    if gitignored[url.lastPathComponent] == true {
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

    // MARK: Git banner

    @ViewBuilder
    private var gitBanner: some View {
        if let url = selectedFile, let status = gitInfo?.status(for: url), status.isTracked {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(url.lastPathComponent) is tracked by git").fontWeight(.medium)
                    Text("Secrets here could be committed. Unstage it and add it to .gitignore.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Unstage & Ignore") { unstageAndIgnore(url) }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
            }
            .padding(10)
            .background(.orange.opacity(0.12))
        }
    }

    // MARK: Derived

    private var kinds: [EnvKind] {
        Array(Set(classified.map(\.kind))).sorted { $0.sortOrder < $1.sortOrder }
    }

    private var kindCounts: [EnvKind: Int] {
        var counts: [EnvKind: Int] = [:]
        for file in classified { counts[file.kind, default: 0] += fileVarCounts[file.path] ?? 0 }
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
                Text("\(url.lastPathComponent) (\(fileVarCounts[url] ?? 0))").tag(Optional(url))
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .padding(8)
    }

    // MARK: Actions

    private func loadFiles() { reload(select: nil) }

    private func reload(select url: URL?) {
        let settings = EnvHubStore.settings(in: context)
        classified = ProjectLoader.envFiles(in: project.url, rules: settings.classificationRules, patterns: settings.filenamePatterns)
        let target = url ?? kinds.first.flatMap { filesForKind($0).first } ?? classified.first?.path
        selectedFile = target
        openEditor(for: target)
        Task { await refreshMetadata() }
    }

    private func refreshMetadata() async {
        let files = classified.map(\.path)
        let folder = project.url
        let result = await Task.detached(priority: .utility) { () -> ([URL: Int], GitInfo, [String: Bool]) in
            var counts: [URL: Int] = [:]
            for file in files { counts[file] = (try? EnvFileService.load(file))?.variables.count ?? 0 }
            let info = GitService.info(folder: folder, files: files)
            var ignored: [String: Bool] = [:]
            if info.isRepo {
                for file in files { ignored[file.lastPathComponent] = GitService.isInGitignore(file.lastPathComponent, folder: folder) }
            }
            return (counts, info, ignored)
        }.value
        fileVarCounts = result.0
        gitInfo = result.1
        gitignored = result.2
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
        try? GitService.unstageAndIgnore(url, in: project.url)
        Task { await refreshMetadata() }
    }

    private func toggleGitignore(_ url: URL, add: Bool) {
        if add {
            try? GitService.addToGitignore(url.lastPathComponent, folder: project.url)
        } else {
            try? GitService.removeFromGitignore(url.lastPathComponent, folder: project.url)
        }
        Task { await refreshMetadata() }
    }
}
