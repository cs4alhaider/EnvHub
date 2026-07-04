//
//  SettingsView.swift
//  EnvHub
//
//  Consolidated settings: general prefs, editable classification rules, and scanning
//  patterns/exclusions. (Scan-folder management lives in the scanner, M6.)
//

import SwiftUI
import SwiftData
import Core

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsPane()
                .tabItem { Label("General", systemImage: "gearshape") }
            ClassificationSettingsPane()
                .tabItem { Label("Classification", systemImage: "tag") }
            ScanningSettingsPane()
                .tabItem { Label("Scanning", systemImage: "magnifyingglass") }
        }
        .frame(width: 580, height: 480)
    }
}

// MARK: - General

private struct GeneralSettingsPane: View {
    @Environment(\.modelContext) private var context
    @Query private var rows: [AppSettings]

    var body: some View {
        Form {
            if let settings = rows.first {
                @Bindable var settings = settings
                Section("Editor") {
                    Toggle("Mask values by default", isOn: $settings.maskByDefault)
                    Text("New files open with values hidden; reveal them per-row or with the eye toggle.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("Scanning") {
                    Toggle("Deep scan (recurse into subfolders) by default", isOn: $settings.deepScanDefault)
                }
            } else {
                ProgressView()
            }
        }
        .formStyle(.grouped)
        .task { _ = EnvHubStore.settings(in: context) }
    }
}

// MARK: - Classification

private struct ClassificationSettingsPane: View {
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

// MARK: - Scanning

private struct ScanningSettingsPane: View {
    @Environment(\.modelContext) private var context
    @Query private var rows: [AppSettings]

    var body: some View {
        Form {
            if let settings = rows.first {
                @Bindable var settings = settings
                StringListSection(
                    title: "Filename patterns",
                    footer: "Glob patterns for env files (e.g. .env, .env.*).",
                    placeholder: ".env.*",
                    items: $settings.filenamePatterns
                )
                StringListSection(
                    title: "Excluded directories",
                    footer: "Directory names skipped while scanning.",
                    placeholder: "node_modules",
                    items: $settings.exclusions
                )
            } else {
                ProgressView()
            }
        }
        .formStyle(.grouped)
        .task { _ = EnvHubStore.settings(in: context) }
    }
}

private struct StringListSection: View {
    let title: String
    let footer: String
    let placeholder: String
    @Binding var items: [String]

    var body: some View {
        Section {
            ForEach(items.indices, id: \.self) { i in
                HStack {
                    TextField(placeholder, text: $items[i]).monospaced()
                    Button(role: .destructive) {
                        items.remove(at: i)
                    } label: {
                        Image(systemName: "minus.circle.fill")
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                }
            }
            Button { items.append("") } label: { Label("Add", systemImage: "plus") }
        } header: {
            Text(title)
        } footer: {
            Text(footer).font(.caption).foregroundStyle(.secondary)
        }
    }
}
