//
//  StringListSection.swift
//  EnvHub
//
//  A reusable Form section for editing a simple list of strings (add / edit / delete).
//

import SwiftUI

struct StringListSection: View {
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
