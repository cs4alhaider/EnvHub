//
//  SidebarView.swift
//  EnvHub
//
//  Projects list: search-filtered, pinned-first, with a right-click menu (pin, Finder,
//  remove). Add a folder, scan, or import a .envenc from the toolbar.
//

import SwiftUI
import SwiftData
import AppKit
import UniformTypeIdentifiers
import Core

/// Wrapper so a picked .envenc URL can drive a `.sheet(item:)`.
struct ImportItem: Identifiable {
    let id = UUID()
    let url: URL
}

struct SidebarView: View {
    @Environment(\.modelContext) private var context
    @Query private var projects: [ProjectRecord]
    @Binding var selection: UUID?
    /// Project IDs matching the current search, or `nil` when not searching.
    let matchingIDs: Set<UUID>?

    @State private var showScan = false
    @State private var importItem: ImportItem?

    private var displayedProjects: [ProjectRecord] {
        let filtered = matchingIDs.map { ids in projects.filter { ids.contains($0.id) } } ?? projects
        return filtered.sorted {
            if $0.isPinned != $1.isPinned { return $0.isPinned }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    var body: some View {
        List(selection: $selection) {
            Section("Projects") {
                ForEach(displayedProjects, id: \.id) { project in
                    ProjectRow(project: project)
                        .tag(project.id)
                        .contextMenu { menu(for: project) }
                }
            }
        }
        .navigationTitle("EnvHub")
        .toolbar {
            ToolbarItem {
                Button { importEnvenc() } label: {
                    Label("Import", systemImage: "square.and.arrow.down")
                }
                .help("Import an encrypted .envenc file")
                .keyboardShortcut("i", modifiers: .command)
            }
            ToolbarItem {
                Button { showScan = true } label: {
                    Label("Scan", systemImage: "magnifyingglass")
                }
                .help("Scan folders for .env files")
                .keyboardShortcut("f", modifiers: [.command, .shift])
            }
            ToolbarItem {
                Button(action: addProjects) {
                    Label("Add Project", systemImage: "plus")
                }
                .help("Add a folder that contains .env files")
                .keyboardShortcut("n", modifiers: .command)
            }
        }
        .sheet(isPresented: $showScan) { ScanView() }
        .sheet(item: $importItem) { item in ImportView(fileURL: item.url) }
        .overlay { emptyState }
    }

    @ViewBuilder
    private func menu(for project: ProjectRecord) -> some View {
        Button(project.isPinned ? "Unpin" : "Pin", systemImage: project.isPinned ? "pin.slash" : "pin") {
            ProjectStore.setPinned(project, !project.isPinned)
        }
        Divider()
        Button("Reveal in Finder", systemImage: "magnifyingglass") { FinderActions.reveal(project.url) }
        Button("Open in Finder", systemImage: "folder") { FinderActions.open(project.url) }
        Button("Copy Path", systemImage: "doc.on.doc") { FinderActions.copyPath(project.url) }
        Divider()
        Button("Remove from EnvHub", systemImage: "trash", role: .destructive) { remove(project) }
    }

    @ViewBuilder
    private var emptyState: some View {
        if projects.isEmpty {
            ContentUnavailableView {
                Label("No Projects", systemImage: "folder.badge.plus")
            } description: {
                Text("Add a folder with .env files, or scan for them.")
            } actions: {
                Button("Add Project…", action: addProjects)
                Button("Scan…") { showScan = true }
            }
        } else if displayedProjects.isEmpty {
            ContentUnavailableView.search
        }
    }

    // MARK: Actions

    private func addProjects() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = true
        panel.prompt = "Add"
        panel.message = "Choose one or more folders that contain .env files"
        guard panel.runModal() == .OK else { return }
        for url in panel.urls {
            if let added = ProjectStore.addProject(at: url, to: context) {
                selection = added.id
            }
        }
    }

    private func remove(_ project: ProjectRecord) {
        if selection == project.id { selection = nil }
        ProjectStore.remove(project, from: context)
    }

    private func importEnvenc() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [UTType(filenameExtension: "envenc") ?? .json]
        panel.prompt = "Import"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        importItem = ImportItem(url: url)
    }
}

private struct ProjectRow: View {
    let project: ProjectRecord
    @State private var fileCount = 0

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
        .task(id: project.path) {
            fileCount = EnvFileLister.envFiles(in: project.url).count
        }
    }
}
