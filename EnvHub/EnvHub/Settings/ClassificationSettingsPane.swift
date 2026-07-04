//
//  ClassificationSettingsPane.swift
//  EnvHub
//
//  Two related things: the environments themselves (name / color / safe-to-track) and
//  the ordered filename → environment rules (first match wins) that sort files into
//  them. A segmented switch keeps both in the fixed settings-window height.
//

import SwiftUI
import SwiftData
import Core

struct ClassificationSettingsPane: View {
    @Environment(\.modelContext) private var context
    @Query private var rows: [AppSettings]
    // Initial sub-mode overridable via ENVHUB_CLASSIFICATION_MODE (screenshot hook).
    @State private var mode: Mode = ProcessInfo.processInfo
        .environment["ENVHUB_CLASSIFICATION_MODE"] == "environments" ? .environments : .rules

    private enum Mode: String, CaseIterable, Identifiable {
        case rules = "Rules"
        case environments = "Environments"
        var id: String { rawValue }
    }

    var body: some View {
        Group {
            if let settings = rows.first {
                VStack(spacing: 0) {
                    Picker("", selection: $mode) {
                        ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .padding(12)
                    Divider()

                    switch mode {
                    case .rules: RulesEditor(settings: settings)
                    case .environments: EnvironmentsEditor(settings: settings)
                    }
                }
            } else {
                ProgressView().task { _ = EnvHubStore.settings(in: context) }
            }
        }
    }
}

/// The filename → environment rule list, with a live "test a filename" probe.
private struct RulesEditor: View {
    let settings: AppSettings
    @State private var testName = ".env.production"

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Rules are applied top-to-bottom; the first match wins. Unmatched files are “Other”.")
                .font(.caption).foregroundStyle(.secondary)
                .padding([.horizontal, .top], 12).padding(.bottom, 6)

            List {
                ForEach(settings.classificationRules) { rule in
                    RuleRow(rule: rule, settings: settings)
                }
                .onMove { moveRules(from: $0, to: $1) }
                .onDelete { deleteRules(at: $0) }
            }

            HStack {
                Button { addRule() } label: { Label("Add Rule", systemImage: "plus") }
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
                let catalog = settings.environmentCatalog
                HStack(spacing: 6) {
                    Circle().fill(catalog.tint(for: kind)).frame(width: 8, height: 8)
                    Text(catalog.title(for: kind)).fontWeight(.medium)
                }
            }
            .padding(12)
        }
    }

    private func addRule() {
        settings.classificationRules.append(ClassificationRule(pattern: "", kind: .other))
    }
    private func deleteRules(at offsets: IndexSet) {
        settings.classificationRules.remove(atOffsets: offsets)
    }
    private func moveRules(from: IndexSet, to: Int) {
        var rules = settings.classificationRules
        rules.move(fromOffsets: from, toOffset: to)
        settings.classificationRules = rules
    }
}

/// One editable rule row. Rules live as an encoded array on `AppSettings`, so the
/// bindings rewrite the whole array through the settings object (SwiftData persists
/// the change automatically). The environment picker offers the user's own catalog.
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
                ForEach(settings.environmentCatalog.definitions) { definition in
                    Text(definition.title).tag(definition.kind)
                }
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
