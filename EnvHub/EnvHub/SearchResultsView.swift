//
//  SearchResultsView.swift
//  EnvHub
//
//  Cross-project search results: every variable whose key/value/filename/project matches
//  the query, grouped by project. Selecting a hit opens that project.
//

import SwiftUI
import Core

struct SearchResultsView: View {
    let query: String
    let hits: [IndexedVariable]
    let onSelect: (UUID, URL) -> Void

    @State private var reveal = false

    private struct ProjectGroup: Identifiable {
        let id: UUID
        let name: String
        let path: String
        let hits: [IndexedVariable]
    }

    var body: some View {
        content
            .navigationTitle("Search")
            .navigationSubtitle("“\(query)” — \(hits.count) match\(hits.count == 1 ? "" : "es")")
            .toolbar {
                if !hits.isEmpty {
                    ToolbarItem {
                        Button { reveal.toggle() } label: {
                            Image(systemName: reveal ? "eye.slash" : "eye")
                        }
                        .help(reveal ? "Hide values" : "Reveal values")
                    }
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        if hits.isEmpty {
            ContentUnavailableView(
                "No matches for “\(query)”",
                systemImage: "magnifyingglass",
                description: Text("No project has a key, value, or file matching your search.")
            )
        } else {
            List {
                ForEach(groups) { group in
                    Section {
                        ForEach(group.hits, id: \.self) { hit in
                            Button { onSelect(hit.projectID, hit.fileURL) } label: { row(hit) }
                                .buttonStyle(.plain)
                        }
                    } header: {
                        HStack(spacing: 6) {
                            Image(systemName: "folder.fill").foregroundStyle(.tint)
                            Text(group.name).fontWeight(.semibold)
                            Text("· \(group.hits.count)").foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private func row(_ hit: IndexedVariable) -> some View {
        HStack(spacing: 8) {
            Circle().fill(hit.kind.tint).frame(width: 7, height: 7)
            Text(hit.key).monospaced().fontWeight(.medium)
            Text("=").foregroundStyle(.tertiary)
            Text(reveal ? hit.value : masked(hit.value))
                .monospaced().foregroundStyle(.secondary).lineLimit(1).truncationMode(.tail)
            Spacer(minLength: 8)
            Text(hit.fileName).font(.caption).foregroundStyle(.secondary).monospaced()
            Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
    }

    private var groups: [ProjectGroup] {
        var order: [UUID] = []
        var map: [UUID: [IndexedVariable]] = [:]
        for hit in hits {
            if map[hit.projectID] == nil { order.append(hit.projectID) }
            map[hit.projectID, default: []].append(hit)
        }
        return order
            .map { id in
                let hs = map[id] ?? []
                return ProjectGroup(id: id, name: hs.first?.projectName ?? "", path: hs.first?.projectPath ?? "", hits: hs)
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func masked(_ value: String) -> String {
        value.isEmpty ? "" : String(repeating: "•", count: min(max(value.count, 3), 16))
    }
}
