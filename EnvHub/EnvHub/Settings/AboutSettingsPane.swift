//
//  AboutSettingsPane.swift
//  EnvHub
//
//  Who made EnvHub, why it's open source, and where to get involved. EnvHub reads your
//  .env files across your machine — being open source is the whole point: you can read
//  exactly what it does before trusting it with your secrets.
//

import SwiftUI
import Core

struct AboutSettingsPane: View {
    var body: some View {
        Form {
            Section {
                HStack(spacing: 14) {
                    // The real app icon — bitmap includes squircle margins, so
                    // draw at 68pt inside a 56pt layout box.
                    Image(nsImage: .envHubIcon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 68, height: 68)
                        .padding(-6)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("EnvHub").font(.title2.bold())
                        Text("Version \(Core.version)").font(.callout).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.vertical, 4)
            }

            Section {
                Text("EnvHub reads and edits the `.env` files across your machine — files that hold your most sensitive secrets. It runs with **no sandbox** so it can find them, which is exactly why it's **open source**: you shouldn't have to trust a closed-source app with your API keys and database passwords. Read the code, build it yourself, and see that nothing ever leaves your Mac — no backend, no accounts, no telemetry.")
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
            } header: {
                Text("Why open source")
            }

            Section {
                LabeledContent("Author", value: "Abdullah Alhaider")
                LinkRow(title: "Website", detail: "alhaider.net", url: "https://alhaider.net")
                LinkRow(title: "GitHub", detail: "@cs4alhaider", url: "https://github.com/cs4alhaider")
                LinkRow(title: "X (Twitter)", detail: "@cs4alhaider", url: "https://x.com/cs4alhaider")
            } header: {
                Text("Author")
            }

            Section {
                LinkRow(title: "Source code", detail: "github.com/cs4alhaider/EnvHub", url: "https://github.com/cs4alhaider/EnvHub", prominent: true)
                LinkRow(title: "Report a bug or request a feature", detail: "Open an issue", url: "https://github.com/cs4alhaider/EnvHub/issues/new")
                LinkRow(title: "Contribute", detail: "Pull requests welcome", url: "https://github.com/cs4alhaider/EnvHub/blob/main/CONTRIBUTING.md")
            } header: {
                Text("Get involved")
            } footer: {
                Text("Found something rough, or want an environment type or feature EnvHub doesn't have yet? Open an issue — contributions and ideas are genuinely welcome.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

/// A settings row whose value is a clickable link.
private struct LinkRow: View {
    let title: String
    let detail: String
    let url: String
    var prominent: Bool = false

    var body: some View {
        LabeledContent(title) {
            if let link = URL(string: url) {
                Link(destination: link) {
                    HStack(spacing: 4) {
                        Text(detail)
                        Image(systemName: "arrow.up.right.square")
                            .font(.caption)
                    }
                    .fontWeight(prominent ? .semibold : .regular)
                }
            } else {
                Text(detail).foregroundStyle(.secondary)
            }
        }
    }
}
