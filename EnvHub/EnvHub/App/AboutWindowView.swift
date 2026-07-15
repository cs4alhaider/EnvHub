//
//  AboutWindowView.swift
//  EnvHub
//
//  The custom "About EnvHub" window (App menu → About EnvHub), replacing the stock
//  macOS panel with the same story the Settings → About tab tells: what it is, why
//  it's open source, who made it, and how to get involved.
//

import SwiftUI
import Core

struct AboutWindowView: View {
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    Divider()
                    section("Why open source") {
                        Text("EnvHub reads and edits the `.env` files across your machine — files that hold your most sensitive secrets. It runs with **no sandbox** so it can find them, which is exactly why it's **open source**: you shouldn't have to trust a closed-source app with your API keys and passwords. Read the code, build it yourself, and see that nothing ever leaves your Mac — no backend, no accounts, no telemetry.")
                            .font(.callout)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    section("Author") {
                        AboutLinkRow(title: "Abdullah Alhaider", detail: "alhaider.net", url: "https://alhaider.net")
                        AboutLinkRow(title: "GitHub", detail: "@cs4alhaider", url: "https://github.com/cs4alhaider")
                        AboutLinkRow(title: "X (Twitter)", detail: "@cs4alhaider", url: "https://x.com/cs4alhaider")
                    }
                    section("Get involved") {
                        AboutLinkRow(title: "Source code", detail: "github.com/cs4alhaider/EnvHub", url: "https://github.com/cs4alhaider/EnvHub", prominent: true)
                        AboutLinkRow(title: "Report a bug or request a feature", detail: "Open an issue", url: "https://github.com/cs4alhaider/EnvHub/issues/new")
                        AboutLinkRow(title: "Contribute", detail: "Pull requests welcome", url: "https://github.com/cs4alhaider/EnvHub/blob/main/CONTRIBUTING.md")
                    }
                }
                .padding(24)
            }

            Divider()
            HStack {
                Text("GPL-3.0 · © Abdullah Alhaider")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 24).padding(.vertical, 10)
            .background(.bar)
        }
        .frame(width: 440, height: 560)
    }

    private var header: some View {
        HStack(spacing: 16) {
            // The real app icon — bitmap includes squircle margins, so draw at
            // 78pt inside a 64pt layout box.
            Image(nsImage: .envHubIcon)
                .resizable()
                .scaledToFit()
                .frame(width: 78, height: 78)
                .padding(-7)
            VStack(alignment: .leading, spacing: 3) {
                Text("EnvHub").font(.largeTitle.bold())
                Text("Version \(Core.version)").font(.callout).foregroundStyle(.secondary)
                Text("Every .env file on your machine, in one window.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    @ViewBuilder
    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            content()
        }
    }
}

/// One "title — link" row in the About window.
private struct AboutLinkRow: View {
    let title: String
    let detail: String
    let url: String
    var prominent: Bool = false

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            if let link = URL(string: url) {
                Link(destination: link) {
                    HStack(spacing: 4) {
                        Text(detail)
                        Image(systemName: "arrow.up.right.square").font(.caption)
                    }
                    .fontWeight(prominent ? .semibold : .regular)
                }
            }
        }
        .font(.callout)
    }
}
