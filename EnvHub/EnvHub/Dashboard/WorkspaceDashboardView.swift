//
//  WorkspaceDashboardView.swift
//  EnvHub
//
//  Shown in the detail pane when a workspace section header is clicked: an overview
//  of every project in that section as cards (file/variable counts, environment
//  dots), each clicking through to the project's editor.
//

import SwiftUI
import SwiftData
import Core

/// What the dashboard is showing: a real workspace, or the ungrouped "Others" section.
enum DashboardTarget: Hashable {
    case workspace(UUID)
    case others
}

struct WorkspaceDashboardView: View {
    let target: DashboardTarget
    /// The search index doubles as the dashboard's stats source (file counts,
    /// variables, environment kinds per project) — no extra disk I/O.
    let index: SearchIndex
    let onOpenProject: (UUID) -> Void

    @Environment(\.openWindow) private var openWindow
    @Environment(\.environmentCatalog) private var catalog
    @Query private var projects: [ProjectRecord]
    @Query private var workspaceRows: [WorkspaceRecord]

    var body: some View {
        let members = members
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header(memberCount: members.count)

                if members.isEmpty {
                    ContentUnavailableView {
                        Label("No Projects Here Yet", systemImage: "tray")
                    } description: {
                        Text("Drag projects onto “\(title)” in the sidebar, or use a project's context menu → Move to Workspace.")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 250), spacing: 14)], spacing: 14) {
                        ForEach(members, id: \.id) { project in
                            ProjectCard(
                                project: project,
                                fileCount: index.fileCounts[project.id] ?? 0,
                                variableCount: variableCounts[project.id] ?? 0,
                                kinds: kindsByProject[project.id] ?? []
                            )
                            // Double-click → own window; single click → in this pane.
                            .onDoubleClick {
                                openWindow(id: "project", value: ProjectWindowRef.saved(project.id))
                            }
                            .onTapGesture { onOpenProject(project.id) }
                            .contextMenu {
                                Button("Open in New Window", systemImage: "macwindow.badge.plus") {
                                    openWindow(id: "project", value: ProjectWindowRef.saved(project.id))
                                }
                            }
                        }
                    }
                }
            }
            .padding(24)
        }
        .navigationTitle(title)
        .navigationSubtitle("\(members.count) project\(members.count == 1 ? "" : "s")")
    }

    // MARK: Data

    private var workspace: WorkspaceRecord? {
        guard case .workspace(let id) = target else { return nil }
        return workspaceRows.first { $0.id == id }
    }

    private var title: String {
        switch target {
        case .workspace: workspace?.name ?? "Workspace"
        case .others: "Others"
        }
    }

    /// All projects in the section — including pinned ones (the sidebar pulls those
    /// into its Pinned section, but they still belong to this workspace).
    private var members: [ProjectRecord] {
        switch target {
        case .workspace(let id): WorkspaceStore.ordered(projects.filter { $0.workspaceID == id })
        case .others: WorkspaceStore.ordered(projects.filter { $0.workspaceID == nil })
        }
    }

    private var variableCounts: [UUID: Int] {
        var counts: [UUID: Int] = [:]
        for variable in index.variables { counts[variable.projectID, default: 0] += 1 }
        return counts
    }

    private var kindsByProject: [UUID: [EnvKind]] {
        var kinds: [UUID: Set<EnvKind>] = [:]
        for variable in index.variables { kinds[variable.projectID, default: []].insert(variable.kind) }
        return kinds.mapValues { catalog.sorted($0) }
    }

    // MARK: Header

    private func header(memberCount: Int) -> some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.tint.opacity(0.15))
                .frame(width: 52, height: 52)
                .overlay {
                    Image(systemName: target == .others ? "square.stack.3d.up" : "rectangle.stack")
                        .font(.title2)
                        .foregroundStyle(.tint)
                }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.title.bold())
                Text(summary(memberCount: memberCount))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private func summary(memberCount: Int) -> String {
        let files = members.reduce(0) { $0 + (index.fileCounts[$1.id] ?? 0) }
        let vars = members.reduce(0) { $0 + (variableCounts[$1.id] ?? 0) }
        return "\(memberCount) project\(memberCount == 1 ? "" : "s") · \(files) env file\(files == 1 ? "" : "s") · \(vars) variable\(vars == 1 ? "" : "s")"
    }
}

/// One clickable project overview card.
private struct ProjectCard: View {
    let project: ProjectRecord
    let fileCount: Int
    let variableCount: Int
    let kinds: [EnvKind]

    @Environment(\.environmentCatalog) private var catalog
    @State private var hovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "folder.fill").foregroundStyle(.tint)
                Text(project.name).fontWeight(.semibold).lineLimit(1)
                if project.isPinned {
                    Image(systemName: "pin.fill").font(.caption2).foregroundStyle(.orange)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .opacity(hovered ? 1 : 0.4)
            }
            Text(project.path)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
            HStack(spacing: 10) {
                Label("\(fileCount)", systemImage: "doc.text")
                Label("\(variableCount)", systemImage: "list.bullet")
                Spacer()
                HStack(spacing: 4) {
                    ForEach(kinds) { kind in
                        Circle().fill(catalog.tint(for: kind)).frame(width: 7, height: 7)
                            .help(catalog.title(for: kind))
                    }
                }
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(hovered ? AnyShapeStyle(.quaternary) : AnyShapeStyle(.quinary))
        )
        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .onHover { hovered = $0 }
    }
}
