//
//  SidebarView.swift
//  EnvHub
//
//  Sectioned projects list: Pinned on top, one section per workspace, ungrouped
//  projects under Others — each with a project-count badge. Projects can be
//  multi-selected and dragged between sections (drop on a section header) or moved /
//  removed in bulk via the context menu; workspaces are created, renamed, and
//  deleted here too. App-wide actions (add/scan/import) live on RootView — the
//  sidebar deliberately has no toolbar, so nothing disappears when it collapses.
//

import SwiftUI
import SwiftData
import Core

struct SidebarView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.appActions) private var appActions
    @Environment(\.openWindow) private var openWindow
    @Query private var projects: [ProjectRecord]
    @Query private var workspaceRows: [WorkspaceRecord]
    @Binding var selection: Set<UUID>
    /// Set by RootView (toolbar "+", menu bar, onboarding) to open the
    /// new-workspace alert; also set locally by the context menu's
    /// "Move to Workspace → New Workspace…".
    @Binding var newWorkspaceRequested: Bool
    /// Clicking a section header shows that section's dashboard in the detail pane.
    @Binding var dashboardTarget: DashboardTarget?
    /// Project IDs matching the current search, or `nil` when not searching.
    let matchingIDs: Set<UUID>?
    /// Env-file count per project (from the search index — no per-row disk I/O).
    let fileCounts: [UUID: Int]

    // Workspace management state
    @State private var newWorkspaceName = ""
    /// Projects waiting to move into the workspace being created via
    /// "Move to Workspace → New Workspace…".
    @State private var pendingMoves: [ProjectRecord] = []
    @State private var renameTarget: WorkspaceRecord?
    @State private var renameText = ""
    @State private var deleteTarget: WorkspaceRecord?
    /// Projects staged for a confirmed bulk remove.
    @State private var removalCandidates: [ProjectRecord] = []
    /// Collapsed section ids (Pinned / workspace UUIDs / Others), persisted across
    /// launches via UserDefaults as a newline-joined string.
    @AppStorage("sidebarCollapsedSections") private var collapsedRaw: String = ""

    var body: some View {
        List(selection: $selection) {
            if !pinnedProjects.isEmpty {
                Section {
                    if !isCollapsed("pinned") { projectRows(pinnedProjects) }
                } header: {
                    sectionHeader("Pinned", sectionID: "pinned", count: pinnedProjects.count)
                }
            }

            ForEach(workspaces) { workspace in
                let members = members(of: workspace)
                // While searching, collapse sections with no matches.
                if !(isSearching && members.isEmpty) {
                    Section {
                        if !isCollapsed(workspace.id.uuidString) {
                            if members.isEmpty {
                                dropHint(for: workspace)
                            } else {
                                projectRows(members)
                            }
                        }
                    } header: {
                        workspaceHeader(workspace, count: members.count)
                    }
                }
            }

            let others = members(of: nil)
            if !others.isEmpty || (!isSearching && !projects.isEmpty) {
                Section {
                    if !isCollapsed("others") { projectRows(others) }
                } header: {
                    othersHeader(count: others.count)
                }
            }
        }
        .contextMenu(forSelectionType: UUID.self) { ids in
            menu(for: targets(of: ids))
        }
        .onDeleteCommand { requestRemoval(targets(of: selection)) }
        .navigationTitle("EnvHub")
        .overlay { emptyState }
        .onAppear {
            // Test/screenshot hook: ENVHUB_COLLAPSE=others,<uuid> pre-collapses sections.
            if collapsedRaw.isEmpty, let seed = ProcessInfo.processInfo.environment["ENVHUB_COLLAPSE"], !seed.isEmpty {
                collapsedRaw = seed.split(separator: ",").joined(separator: "\n")
            }
        }
        .alert("New Workspace", isPresented: $newWorkspaceRequested) {
            TextField("Name", text: $newWorkspaceName)
            Button("Create") { createWorkspace() }
            Button("Cancel", role: .cancel) { pendingMoves = []; newWorkspaceName = "" }
        } message: {
            Text(pendingMoves.isEmpty
                 ? "Workspaces are sidebar sections you can drag projects into."
                 : "The \(pendingMoves.count) selected project\(pendingMoves.count == 1 ? "" : "s") will move into it.")
        }
        .alert("Rename Workspace", isPresented: renameAlertShown) {
            TextField("Name", text: $renameText)
            Button("Rename") {
                if let target = renameTarget { WorkspaceStore.rename(target, to: renameText) }
                renameTarget = nil
            }
            Button("Cancel", role: .cancel) { renameTarget = nil }
        }
        .confirmationDialog(
            "Delete “\(deleteTarget?.name ?? "")”?",
            isPresented: deleteDialogShown,
            titleVisibility: .visible
        ) {
            Button("Delete Workspace", role: .destructive) {
                if let target = deleteTarget { WorkspaceStore.delete(target, in: context) }
                deleteTarget = nil
            }
            Button("Cancel", role: .cancel) { deleteTarget = nil }
        } message: {
            Text("Its projects move back to Others. Nothing is deleted from disk.")
        }
        .confirmationDialog(
            "Remove \(removalCandidates.count) projects from EnvHub?",
            isPresented: removalDialogShown,
            titleVisibility: .visible
        ) {
            Button("Remove \(removalCandidates.count) Projects", role: .destructive) {
                remove(removalCandidates)
                removalCandidates = []
            }
            Button("Cancel", role: .cancel) { removalCandidates = [] }
        } message: {
            Text("EnvHub only forgets them — no files on disk are touched.")
        }
    }

    // MARK: Sections

    private var isSearching: Bool { matchingIDs != nil }

    private var workspaces: [WorkspaceRecord] {
        WorkspaceStore.orderedWorkspaces(workspaceRows)
    }

    /// Projects surviving the current search filter.
    private var visibleProjects: [ProjectRecord] {
        guard let matchingIDs else { return projects }
        return projects.filter { matchingIDs.contains($0.id) }
    }

    private var pinnedProjects: [ProjectRecord] {
        WorkspaceStore.ordered(visibleProjects.filter(\.isPinned))
    }

    /// Unpinned members of a workspace (nil = the ungrouped Others section).
    private func members(of workspace: WorkspaceRecord?) -> [ProjectRecord] {
        WorkspaceStore.members(of: workspace, in: visibleProjects.filter { !$0.isPinned })
    }

    /// "Others" only makes sense as a counterpart to something above it.
    private var othersTitle: String {
        (workspaces.isEmpty && pinnedProjects.isEmpty) ? "Projects" : "Others"
    }

    private func projectRows(_ list: [ProjectRecord]) -> some View {
        ForEach(list, id: \.id) { project in
            ProjectRow(project: project, fileCount: fileCounts[project.id] ?? 0)
                .tag(project.id)
                .draggable(project.id.uuidString)
                // Double-click opens the project in its own window (⌘-double-click:
                // a tab, like Finder) — via an AppKit recognizer that leaves
                // single-click selection untouched.
                .onDoubleClick {
                    if NSEvent.modifierFlags.contains(.command) {
                        WindowTabbing.openTab(selecting: project.id, using: openWindow)
                    } else {
                        openWindow(id: "project", value: ProjectWindowRef.saved(project.id))
                    }
                }
        }
    }

    // MARK: Section headers (collapse chevron; clickable → dashboard; drop; badges)

    /// The disclosure chevron that collapses/expands a section. A distinct button, so
    /// it never competes with the header's dashboard tap.
    private func disclosure(_ sectionID: String) -> some View {
        Button {
            toggleCollapsed(sectionID)
        } label: {
            Image(systemName: isCollapsed(sectionID) ? "chevron.right" : "chevron.down")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
                .frame(width: 10)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(isCollapsed(sectionID) ? "Expand" : "Collapse")
    }

    private func sectionHeader(_ title: String, sectionID: String, count: Int, isActive: Bool = false) -> some View {
        HStack(spacing: 5) {
            disclosure(sectionID)
            Text(title)
                .foregroundStyle(isActive ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
            Spacer()
            Text("\(count)")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(isActive ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(isActive ? AnyShapeStyle(.tint.opacity(0.15)) : AnyShapeStyle(.quaternary), in: Capsule())
        }
        .contentShape(Rectangle())
    }

    private func workspaceHeader(_ workspace: WorkspaceRecord, count: Int) -> some View {
        sectionHeader(workspace.name, sectionID: workspace.id.uuidString, count: count, isActive: dashboardTarget == .workspace(workspace.id))
            .onTapGesture { openDashboard(.workspace(workspace.id)) }
            .help("Click for the “\(workspace.name)” dashboard")
            .dropDestination(for: String.self) { ids, _ in _ = move(ids, to: workspace) }
            .contextMenu {
                Button("Show Dashboard", systemImage: "rectangle.grid.2x2") {
                    openDashboard(.workspace(workspace.id))
                }
                Button(isCollapsed(workspace.id.uuidString) ? "Expand" : "Collapse",
                       systemImage: isCollapsed(workspace.id.uuidString) ? "chevron.right" : "chevron.down") {
                    toggleCollapsed(workspace.id.uuidString)
                }
                Divider()
                Button("Rename…", systemImage: "pencil") {
                    renameText = workspace.name
                    renameTarget = workspace
                }
                Button("Sort Projects by Name", systemImage: "arrow.up.arrow.down") {
                    WorkspaceStore.sortProjects(in: workspace, by: .name, context: context)
                }
                Divider()
                Button("Delete Workspace", systemImage: "trash", role: .destructive) {
                    deleteTarget = workspace
                }
            }
    }

    private func othersHeader(count: Int) -> some View {
        sectionHeader(othersTitle, sectionID: "others", count: count, isActive: dashboardTarget == .others)
            .onTapGesture { openDashboard(.others) }
            .help("Click for the “\(othersTitle)” dashboard")
            .dropDestination(for: String.self) { ids, _ in _ = move(ids, to: nil) }
    }

    // MARK: Collapse state

    private var collapsedSections: Set<String> {
        Set(collapsedRaw.split(separator: "\n").map(String.init))
    }

    /// A section is only "collapsed" when not searching — search must never hide matches.
    private func isCollapsed(_ sectionID: String) -> Bool {
        !isSearching && collapsedSections.contains(sectionID)
    }

    private func toggleCollapsed(_ sectionID: String) {
        var set = collapsedSections
        if set.contains(sectionID) { set.remove(sectionID) } else { set.insert(sectionID) }
        collapsedRaw = set.sorted().joined(separator: "\n")
    }

    /// Show a section dashboard in the detail pane (clears any project selection —
    /// the two are mutually exclusive detail states).
    private func openDashboard(_ target: DashboardTarget) {
        selection = []
        dashboardTarget = target
    }

    /// Placeholder row that keeps an empty workspace visible — and droppable.
    private func dropHint(for workspace: WorkspaceRecord) -> some View {
        Label("Drag projects here", systemImage: "tray.and.arrow.down")
            .font(.caption)
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .dropDestination(for: String.self) { ids, _ in _ = move(ids, to: workspace) }
    }

    // MARK: Selection context menu

    /// The projects a context menu targets: the clicked/selected IDs, resolved.
    private func targets(of ids: Set<UUID>) -> [ProjectRecord] {
        projects.filter { ids.contains($0.id) }
    }

    /// One menu for both single and multi selections — actions apply to all targets.
    @ViewBuilder
    private func menu(for targets: [ProjectRecord]) -> some View {
        if targets.isEmpty {
            EmptyView()
        } else {
            let single = targets.count == 1 ? targets[0] : nil
            let allPinned = targets.allSatisfy(\.isPinned)

            Button(
                targets.count == 1 ? "Open in New Tab" : "Open in New Tabs",
                systemImage: "plus.square.on.square"
            ) {
                for project in targets { WindowTabbing.openTab(selecting: project.id, using: openWindow) }
            }
            Button(
                targets.count == 1 ? "Open in New Window" : "Open in New Windows",
                systemImage: "macwindow.badge.plus"
            ) {
                for project in targets { openWindow(id: "project", value: ProjectWindowRef.saved(project.id)) }
            }
            Divider()
            Button(allPinned ? "Unpin" : "Pin", systemImage: allPinned ? "pin.slash" : "pin") {
                for project in targets { ProjectStore.setPinned(project, !allPinned) }
            }
            Menu(targets.count == 1 ? "Move to Workspace" : "Move \(targets.count) to Workspace") {
                Button {
                    for project in targets { WorkspaceStore.assign(project, to: nil) }
                } label: {
                    if targets.allSatisfy({ $0.workspaceID == nil }) {
                        Label("Others", systemImage: "checkmark")
                    } else {
                        Text("Others")
                    }
                }
                ForEach(workspaces) { workspace in
                    Button {
                        for project in targets { WorkspaceStore.assign(project, to: workspace) }
                    } label: {
                        if targets.allSatisfy({ $0.workspaceID == workspace.id }) {
                            Label(workspace.name, systemImage: "checkmark")
                        } else {
                            Text(workspace.name)
                        }
                    }
                }
                Divider()
                Button("New Workspace…", systemImage: "plus") {
                    pendingMoves = targets
                    newWorkspaceRequested = true
                }
            }
            if let single {
                Divider()
                Button("Reveal in Finder", systemImage: "magnifyingglass") { FinderActions.reveal(single.url) }
                Button("Copy Path", systemImage: "doc.on.doc") { FinderActions.copyPath(single.url) }
            }
            Divider()
            Button(
                targets.count == 1 ? "Remove from EnvHub" : "Remove \(targets.count) from EnvHub",
                systemImage: "trash",
                role: .destructive
            ) {
                requestRemoval(targets)
            }
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if projects.isEmpty {
            ContentUnavailableView {
                Label("No Projects", systemImage: "folder.badge.plus")
            } description: {
                Text("Add a folder with .env files, or scan for them.")
            } actions: {
                Button("Add Project…") { appActions?.addProject() }
                Button("Scan…") { appActions?.scan() }
            }
        } else if visibleProjects.isEmpty {
            ContentUnavailableView.search
        }
    }

    // MARK: Actions

    /// Handle a drop of dragged project IDs onto a section (nil = Others).
    private func move(_ draggedIDs: [String], to workspace: WorkspaceRecord?) -> Bool {
        let ids = draggedIDs.compactMap(UUID.init)
        let targets = projects.filter { ids.contains($0.id) }
        guard !targets.isEmpty else { return false }
        for project in targets {
            WorkspaceStore.assign(project, to: workspace)
        }
        return true
    }

    private func createWorkspace() {
        let name = newWorkspaceName.trimmingCharacters(in: .whitespaces)
        newWorkspaceName = ""
        guard !name.isEmpty else { pendingMoves = []; return }
        let workspace = WorkspaceStore.create(named: name, in: context)
        for project in pendingMoves {
            WorkspaceStore.assign(project, to: workspace)
        }
        pendingMoves = []
    }

    /// Remove immediately for a single project; confirm first for a bulk removal.
    private func requestRemoval(_ targets: [ProjectRecord]) {
        guard !targets.isEmpty else { return }
        if targets.count == 1 {
            remove(targets)
        } else {
            removalCandidates = targets
        }
    }

    private func remove(_ targets: [ProjectRecord]) {
        selection.subtract(targets.map(\.id))
        for project in targets {
            ProjectStore.remove(project, from: context)
        }
    }

    private var renameAlertShown: Binding<Bool> {
        Binding(get: { renameTarget != nil }, set: { if !$0 { renameTarget = nil } })
    }

    private var deleteDialogShown: Binding<Bool> {
        Binding(get: { deleteTarget != nil }, set: { if !$0 { deleteTarget = nil } })
    }

    private var removalDialogShown: Binding<Bool> {
        Binding(get: { !removalCandidates.isEmpty }, set: { if !$0 { removalCandidates = [] } })
    }

}
