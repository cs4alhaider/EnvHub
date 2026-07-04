//
//  EnvironmentsEditor.swift
//  EnvHub
//
//  Define your own environments (UAT, pre-prod, …): name, color, and whether files of
//  that kind are safe to commit. The order here is the display order of the tabs,
//  dashboards, and search settings. Definitions are stored on AppSettings; a filename
//  is mapped to one of these by the Rules editor.
//

import SwiftUI
import Core

struct EnvironmentsEditor: View {
    let settings: AppSettings
    @State private var newName = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Environments appear as tabs and dots, in this order. Map filenames to them in Rules (e.g. “.env.production” → Production).")
                .font(.caption).foregroundStyle(.secondary)
                .padding([.horizontal, .top], 12).padding(.bottom, 6)

            List {
                ForEach(settings.environmentDefinitions) { definition in
                    EnvironmentRow(definition: definition, settings: settings)
                }
                .onMove { move(from: $0, to: $1) }
                .onDelete { delete(at: $0) }
            }

            Divider()
            HStack(spacing: 8) {
                TextField("New environment (e.g. UAT)", text: $newName)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(add)
                Button { add() } label: { Label("Add", systemImage: "plus") }
                    .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
                Spacer()
                Button("Reset to Defaults") {
                    settings.environmentDefinitions = EnvironmentDefinition.defaults
                }
            }
            .padding(12)
        }
    }

    private func add() {
        let name = newName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        let kind = EnvKind.slug(from: name)
        var definitions = settings.environmentDefinitions
        // No duplicate slugs; if it exists, just clear the field.
        guard !definitions.contains(where: { $0.kind == kind }) else { newName = ""; return }
        // Insert before the trailing "Other" bucket so it stays last.
        let insertIndex = definitions.firstIndex { $0.kind == .other } ?? definitions.count
        definitions.insert(
            EnvironmentDefinition(kind: kind, title: name, color: nextColor(after: definitions)),
            at: insertIndex
        )
        settings.environmentDefinitions = definitions
        newName = ""
    }

    private func delete(at offsets: IndexSet) {
        var definitions = settings.environmentDefinitions
        // "Other" is the classifier's fallback bucket — never deletable.
        let removable = offsets.filter { definitions[$0].kind != .other }
        definitions.remove(atOffsets: IndexSet(removable))
        settings.environmentDefinitions = definitions
    }

    private func move(from: IndexSet, to: Int) {
        var definitions = settings.environmentDefinitions
        definitions.move(fromOffsets: from, toOffset: to)
        settings.environmentDefinitions = definitions
    }

    /// Pick a palette color not already used, so new environments look distinct.
    private func nextColor(after definitions: [EnvironmentDefinition]) -> EnvColor {
        let used = Set(definitions.map(\.color))
        return EnvColor.allCases.first { !used.contains($0) } ?? .gray
    }
}

/// One environment definition row: color swatch, editable title, safe-to-track toggle.
private struct EnvironmentRow: View {
    let definition: EnvironmentDefinition
    let settings: AppSettings

    private var isOther: Bool { definition.kind == .other }

    var body: some View {
        HStack(spacing: 10) {
            ColorSwatchMenu(selection: binding(\.color))
            VStack(alignment: .leading, spacing: 1) {
                TextField("Name", text: binding(\.title))
                    .textFieldStyle(.plain)
                Text(definition.kind.rawValue)
                    .font(.caption2).monospaced().foregroundStyle(.tertiary)
            }
            Spacer()
            Toggle("Safe to commit", isOn: binding(\.isSafeToTrack))
                .toggleStyle(.checkbox)
                .help("Files of this environment (like .env.example) won’t trigger the git-tracking warning.")
                .disabled(isOther)
        }
    }

    private func binding<T>(_ keyPath: WritableKeyPath<EnvironmentDefinition, T>) -> Binding<T> {
        Binding(
            get: { (settings.environmentDefinitions.first { $0.kind == definition.kind } ?? definition)[keyPath: keyPath] },
            set: { newValue in
                var definitions = settings.environmentDefinitions
                if let i = definitions.firstIndex(where: { $0.kind == definition.kind }) {
                    definitions[i][keyPath: keyPath] = newValue
                    settings.environmentDefinitions = definitions
                }
            }
        )
    }
}

/// A menu that shows the current color as a swatch and lets you pick another.
private struct ColorSwatchMenu: View {
    @Binding var selection: EnvColor

    var body: some View {
        Menu {
            ForEach(EnvColor.allCases) { color in
                Button {
                    selection = color
                } label: {
                    Label {
                        Text(color.title)
                    } icon: {
                        Image(systemName: selection == color ? "checkmark.circle.fill" : "circle.fill")
                            .foregroundStyle(color.color)
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Circle()
                    .fill(selection.color)
                    .frame(width: 15, height: 15)
                    .overlay(Circle().strokeBorder(.primary.opacity(0.15), lineWidth: 1))
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Environment color")
    }
}
