//
//  QuickOpenPanel.swift
//  EnvHub
//
//  Xcode-"Open Quickly"-style popup (⇧⌘O): type, see matches grouped by project
//  (project name/path matches first, then variable hits), arrow through them, and
//  Enter/click jumps straight to the project. Esc or clicking outside dismisses.
//

import SwiftUI
import Core

struct QuickOpenPanel: View {
    let index: SearchIndex
    let projects: [ProjectRecord]
    /// Environments excluded from results (Settings → Search); everything else shows.
    var excludedKinds: Set<String> = []
    /// Pre-filled query (used by the screenshot/test hook; empty in normal use).
    var initialQuery: String = ""
    /// Called with the chosen project's ID; the caller selects it and closes the panel.
    let onOpen: (UUID) -> Void
    let onClose: () -> Void

    @Environment(\.environmentCatalog) private var catalog
    @State private var query = ""
    @State private var highlighted = 0
    @FocusState private var fieldFocused: Bool

    /// One keyboard-navigable result line. `id` is **stable and content-derived** —
    /// using a fresh UUID here recycles SwiftUI's lazy row views wrongly and desyncs
    /// headers from their rows.
    private struct Row: Identifiable {
        enum Kind {
            case project(ProjectRecord)
            case hit(IndexedVariable)
        }
        let id: String
        let projectID: UUID
        let kind: Kind
        /// Section this row renders under: display title + a stable id (so two
        /// same-named projects still get distinct headers).
        let section: String
        let sectionID: String
        let isFirstOfSection: Bool
    }

    /// A rendered line: either a section header or a result row. Headers are
    /// first-class list items (not coupled to a row), each with a stable id.
    private enum DisplayItem: Identifiable {
        case header(sectionID: String, title: String)
        case row(Row, position: Int)

        var id: String {
            switch self {
            case .header(let sectionID, _): "h:\(sectionID)"
            case .row(let row, _): "r:\(row.id)"
            }
        }
    }

    var body: some View {
        let rows = rows(for: query)

        VStack(spacing: 0) {
            searchField(rows: rows)
            Divider()
            results(rows: rows)
        }
        .frame(width: 640)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.separator, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.3), radius: 24, y: 8)
        .defaultFocus($fieldFocused, true)
        .onExitCommand(perform: onClose)
        .task {
            if !initialQuery.isEmpty { query = initialQuery }
            // The overlay's TextField isn't in the responder chain on the first tick
            // (the panel animates in over a window that already holds focus), so give
            // it a couple of runloop turns before grabbing focus.
            try? await Task.sleep(for: .milliseconds(60))
            fieldFocused = true
        }
        .onChange(of: query) { highlighted = 0 }
    }

    // MARK: Field

    private func searchField(rows: [Row]) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.title3)
                .foregroundStyle(.secondary)
            TextField("Search keys, values, files, and projects", text: $query)
                .textFieldStyle(.plain)
                .font(.title3)
                .focused($fieldFocused)
                .onSubmit { open(rows: rows, at: highlighted) }
                .onKeyPress(.downArrow) {
                    highlighted = min(highlighted + 1, max(rows.count - 1, 0))
                    return .handled
                }
                .onKeyPress(.upArrow) {
                    highlighted = max(highlighted - 1, 0)
                    return .handled
                }
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
    }

    // MARK: Results

    @ViewBuilder
    private func results(rows: [Row]) -> some View {
        if query.trimmingCharacters(in: .whitespaces).isEmpty {
            hint("Type to search across \(projects.count) project\(projects.count == 1 ? "" : "s") — keys, values, filenames, and project names.")
        } else if rows.isEmpty {
            hint("No matches for “\(query)”.")
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 1) {
                        ForEach(displayItems(rows)) { item in
                            switch item {
                            case .header(_, let title):
                                sectionHeader(title)
                            case .row(let row, let position):
                                resultRow(row, isHighlighted: position == highlighted)
                                    .onTapGesture { open(rows: rows, at: position) }
                            }
                        }
                    }
                    .padding(8)
                }
                .frame(maxHeight: 380)
                .onChange(of: highlighted) { _, position in
                    guard rows.indices.contains(position) else { return }
                    withAnimation(.easeOut(duration: 0.1)) {
                        proxy.scrollTo("r:\(rows[position].id)", anchor: .center)
                    }
                }
            }
        }
    }

    private func hint(_ text: String) -> some View {
        Text(text)
            .font(.callout)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 28)
            .padding(.horizontal, 20)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.top, 8)
            .padding(.bottom, 2)
    }

    @ViewBuilder
    private func resultRow(_ row: Row, isHighlighted: Bool) -> some View {
        HStack(spacing: 8) {
            switch row.kind {
            case .project(let project):
                Image(systemName: "folder.fill").foregroundStyle(.tint)
                Text(project.name).fontWeight(.medium)
                Text(PathDisplay.homeRelative(project.path))
                    .font(.caption).foregroundStyle(.secondary)
                    .lineLimit(1).truncationMode(.head)
                    .help(project.path)
                Spacer(minLength: 8)
            case .hit(let hit):
                Circle().fill(catalog.tint(for: hit.kind)).frame(width: 7, height: 7)
                Text(hit.key).monospaced().fontWeight(.medium).lineLimit(1)
                Text("=").foregroundStyle(.tertiary)
                Text(ValueMasking.masked(hit.value, maxDots: 12))
                    .monospaced().foregroundStyle(.secondary).lineLimit(1)
                Spacer(minLength: 8)
                Text(hit.fileName).font(.caption).foregroundStyle(.secondary).monospaced()
            }
            Image(systemName: "return")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .opacity(isHighlighted ? 1 : 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(isHighlighted ? AnyShapeStyle(Color.accentColor.opacity(0.22)) : AnyShapeStyle(.clear))
        )
        .contentShape(Rectangle())
    }

    // MARK: Data

    /// Flattened, keyboard-navigable results: projects whose name/path match first
    /// (under "Projects"), then variable hits grouped by project.
    private func rows(for query: String) -> [Row] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return [] }

        var rows: [Row] = []

        let nameMatches = projects.filter {
            ProjectSearch.projectMatches(query: trimmed, name: $0.name, path: $0.path)
        }
        for (offset, project) in nameMatches.prefix(8).enumerated() {
            rows.append(Row(
                id: "proj:\(project.id.uuidString)",
                projectID: project.id, kind: .project(project),
                section: "Projects", sectionID: "projects", isFirstOfSection: offset == 0))
        }

        let hits = ProjectSearch.search(trimmed, in: index).filter { !excludedKinds.contains($0.kind.rawValue) }
        for group in ProjectSearch.groupedByProject(hits) {
            for (offset, hit) in group.hits.prefix(20).enumerated() {
                rows.append(Row(
                    id: "hit:\(group.id.uuidString):\(hit.fileURL.path(percentEncoded: false)):\(hit.key)",
                    projectID: hit.projectID, kind: .hit(hit),
                    section: group.name, sectionID: group.id.uuidString, isFirstOfSection: offset == 0))
            }
        }
        return rows
    }

    /// Interleave section headers (as their own items) with rows for rendering. Each
    /// row carries its position in the selectable `rows` array for highlighting.
    private func displayItems(_ rows: [Row]) -> [DisplayItem] {
        var items: [DisplayItem] = []
        for (position, row) in rows.enumerated() {
            if row.isFirstOfSection {
                items.append(.header(sectionID: row.sectionID, title: row.section))
            }
            items.append(.row(row, position: position))
        }
        return items
    }

    private func open(rows: [Row], at position: Int) {
        guard rows.indices.contains(position) else { return }
        onOpen(rows[position].projectID)
    }
}
