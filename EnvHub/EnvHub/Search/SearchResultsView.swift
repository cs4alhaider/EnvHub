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

    @Environment(\.environmentCatalog) private var catalog
    @State private var reveal = false

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
                ForEach(ProjectSearch.groupedByProject(hits)) { group in
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
            Circle().fill(catalog.tint(for: hit.kind)).frame(width: 7, height: 7)
            Text(hit.key).monospaced().fontWeight(.medium)
            Text("=").foregroundStyle(.tertiary)
            Text(reveal ? hit.value : ValueMasking.masked(hit.value, maxDots: 16))
                .monospaced().foregroundStyle(.secondary).lineLimit(1).truncationMode(.tail)
            Spacer(minLength: 8)
            Text(hit.fileName).font(.caption).foregroundStyle(.secondary).monospaced()
            Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
    }
}
