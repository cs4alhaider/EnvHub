//
//  ClassificationSettingsPane.swift
//  EnvHub
//
//  Editable, ordered filename → environment regex rules (first match wins), with a
//  live "test a filename" probe at the bottom.
//

import SwiftUI
import SwiftData
import Core

struct ClassificationSettingsPane: View {
    @Environment(\.modelContext) private var context
    @Query private var rows: [AppSettings]
    @State private var testName = ".env.production"

    var body: some View {
        Group {
            if let settings = rows.first {
                content(settings)
            } else {
                ProgressView().task { _ = EnvHubStore.settings(in: context) }
            }
        }
    }

    private func content(_ settings: AppSettings) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Rules are applied top-to-bottom; the first match wins. Unmatched files are “Other”.")
                .font(.caption).foregroundStyle(.secondary)
                .padding([.horizontal, .top], 12).padding(.bottom, 6)

            List {
                ForEach(settings.classificationRules) { rule in
                    RuleRow(rule: rule, settings: settings)
                }
                .onMove { moveRules(settings, from: $0, to: $1) }
                .onDelete { deleteRules(settings, at: $0) }
            }

            HStack {
                Button { addRule(settings) } label: { Label("Add Rule", systemImage: "plus") }
                Spacer()
                Button("Reset to Defaults") { settings.classificationRules = ClassificationRule.defaults }
            }
            .padding(12)

            Divider()
            HStack(spacing: 8) {
                Text("Test filename:").foregroundStyle(.secondary)
                TextField(".env.production", text: $testName)
                    .textFieldStyle(.roundedBorder).monospaced().frame(width: 200)
                let kind = ProjectLoader.classify(fileName: testName, rules: settings.classificationRules)
                HStack(spacing: 6) {
                    Circle().fill(kind.tint).frame(width: 8, height: 8)
                    Text(kind.title).fontWeight(.medium)
                }
            }
            .padding(12)
        }
    }

    private func addRule(_ s: AppSettings) {
        s.classificationRules.append(ClassificationRule(pattern: "", kind: .other))
    }
    private func deleteRules(_ s: AppSettings, at offsets: IndexSet) {
        s.classificationRules.remove(atOffsets: offsets)
    }
    private func moveRules(_ s: AppSettings, from: IndexSet, to: Int) {
        var r = s.classificationRules
        r.move(fromOffsets: from, toOffset: to)
        s.classificationRules = r
    }
}

/// One editable rule row. Rules live as an encoded array on `AppSettings`, so the
/// bindings rewrite the whole array through the settings object (SwiftData persists
/// the change automatically).
private struct RuleRow: View {
    let rule: ClassificationRule
    let settings: AppSettings

    var body: some View {
        HStack(spacing: 8) {
            Toggle("", isOn: binding(\.isEnabled)).labelsHidden()
                .help("Enable/disable this rule")
            TextField("regex pattern", text: binding(\.pattern))
                .textFieldStyle(.roundedBorder).monospaced()
            Picker("", selection: binding(\.kind)) {
                ForEach(EnvKind.allCases) { kind in Text(kind.title).tag(kind) }
            }
            .labelsHidden().frame(width: 140)
        }
    }

    private func binding<T>(_ keyPath: WritableKeyPath<ClassificationRule, T>) -> Binding<T> {
        Binding(
            get: { (settings.classificationRules.first { $0.id == rule.id } ?? rule)[keyPath: keyPath] },
            set: { newValue in
                var rules = settings.classificationRules
                if let i = rules.firstIndex(where: { $0.id == rule.id }) {
                    rules[i][keyPath: keyPath] = newValue
                    settings.classificationRules = rules
                }
            }
        )
    }
}
