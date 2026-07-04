//
//  OnboardingView.swift
//  EnvHub
//
//  First-launch welcome flow: what EnvHub is, the privacy model, how to organize,
//  and an actionable "get started" page. Shown once (AppSettings.hasSeenOnboarding);
//  re-openable via Help → Welcome to EnvHub.
//

import SwiftUI

struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appActions) private var appActions
    // Initial page overridable via ENVHUB_ONBOARDING_PAGE (screenshot hook).
    @State private var page = Int(ProcessInfo.processInfo.environment["ENVHUB_ONBOARDING_PAGE"] ?? "") ?? 0

    private let pageCount = 4

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch page {
                case 0: welcomePage
                case 1: privacyPage
                case 2: organizePage
                default: getStartedPage
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.horizontal, 44)
            .padding(.top, 40)

            footer
        }
        .frame(width: 600, height: 560)
        .animation(.snappy, value: page)
    }

    // MARK: Pages

    private var welcomePage: some View {
        OnboardingPage(
            symbol: "key.horizontal.fill",
            tint: .blue,
            title: "Welcome to EnvHub",
            subtitle: "Every .env file on your machine, in one window."
        ) {
            OnboardingFeatureRow(
                symbol: "tablecells",
                title: "A real editor for env files",
                detail: "Keys, values, and the comment above each key — with inline validation, masking, and a raw text mode."
            )
            OnboardingFeatureRow(
                symbol: "circle.grid.2x1.left.filled",
                title: "Environments at a glance",
                detail: "Development, Staging, Production, Local, and Example tabs, driven by rules you can edit."
            )
            OnboardingFeatureRow(
                symbol: "magnifyingglass",
                title: "Search everything",
                detail: "Type a key, a value, or a project name and jump straight to the match — across all projects."
            )
        }
    }

    private var privacyPage: some View {
        OnboardingPage(
            symbol: "lock.shield.fill",
            tint: .green,
            title: "Private & Open Source",
            subtitle: "No backend, no accounts, no telemetry."
        ) {
            OnboardingFeatureRow(
                symbol: "chevron.left.forwardslash.chevron.right",
                title: "Open source, so you can trust it",
                detail: "EnvHub touches your most sensitive files, so you shouldn't have to trust a black box — read the code, build it yourself, verify nothing leaves your Mac."
            )
            OnboardingFeatureRow(
                symbol: "internaldrive",
                title: "Your files stay the source of truth",
                detail: "EnvHub edits .env files in place (with a .bak safety copy) and stores only its own metadata locally."
            )
            OnboardingFeatureRow(
                symbol: "lock.doc",
                title: "Encrypted sharing when you need it",
                detail: "Export files or whole projects as password-protected .envenc (AES-256-GCM + scrypt)."
            )
        }
    }

    private var organizePage: some View {
        OnboardingPage(
            symbol: "rectangle.stack.fill",
            tint: .purple,
            title: "Organize with Workspaces",
            subtitle: "Sidebar sections that group your projects your way."
        ) {
            OnboardingFeatureRow(
                symbol: "square.and.arrow.down.on.square",
                title: "Drag, drop, multi-select",
                detail: "Drag projects onto a workspace header, or select several and move or remove them together."
            )
            OnboardingFeatureRow(
                symbol: "sparkle.magnifyingglass",
                title: "Fast, safe scanning",
                detail: "The scanner walks folders in parallel, skips caches, never re-imports what you already have, and can stop early to review."
            )
            OnboardingFeatureRow(
                symbol: "hand.raised",
                title: "One permission to know about",
                detail: "Scanning Desktop, Documents, or Downloads may prompt for access — macOS asking, not EnvHub phoning home."
            )
        }
    }

    private var getStartedPage: some View {
        OnboardingPage(
            symbol: "checkmark.seal.fill",
            tint: .orange,
            title: "You're Set",
            subtitle: "Bring in your first projects — everything else is the ⊕ button in the toolbar."
        ) {
            VStack(spacing: 10) {
                Button {
                    dismiss()
                    appActions?.addProject()
                } label: {
                    Label("Add a Project Folder…", systemImage: "folder.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .controlSize(.large)
                .buttonStyle(.borderedProminent)

                Button {
                    appActions?.scan()   // closes this sheet itself, then opens the scanner
                } label: {
                    Label("Scan for .env Files…", systemImage: "magnifyingglass")
                        .frame(maxWidth: .infinity)
                }
                .controlSize(.large)
            }
            .padding(.top, 4)

            OnboardingFeatureRow(
                symbol: "terminal",
                title: "There's a CLI too",
                detail: "envhub scan, list, get, export, import, workspace — and `envhub .` to open a folder here. It shares the same data as the app."
            )

            Divider().padding(.vertical, 2)

            VStack(alignment: .leading, spacing: 6) {
                Text("Built by Abdullah Alhaider — free and open source.")
                    .font(.callout).fontWeight(.medium)
                Text("Have a bug, an idea, or need an environment type EnvHub doesn't have? Contributions and issues are welcome.")
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 14) {
                    Link("GitHub", destination: URL(string: "https://github.com/cs4alhaider/EnvHub")!)
                    Link("Open an Issue", destination: URL(string: "https://github.com/cs4alhaider/EnvHub/issues/new")!)
                    Link("alhaider.net", destination: URL(string: "https://alhaider.net")!)
                    Link("@cs4alhaider", destination: URL(string: "https://x.com/cs4alhaider")!)
                }
                .font(.caption)
            }
        }
    }

    // MARK: Footer

    private var footer: some View {
        HStack {
            if page > 0 {
                Button("Back") { page -= 1 }
            } else {
                Button("Skip") { dismiss() }
            }
            Spacer()
            HStack(spacing: 7) {
                ForEach(0..<pageCount, id: \.self) { dot in
                    Circle()
                        .fill(dot == page ? Color.accentColor : Color.secondary.opacity(0.35))
                        .frame(width: 7, height: 7)
                }
            }
            Spacer()
            if page < pageCount - 1 {
                Button("Continue") { page += 1 }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            } else {
                Button("Start Exploring") { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .background(.bar)
    }
}

/// One onboarding page: a tinted symbol tile, title/subtitle, and content rows.
private struct OnboardingPage<Content: View>: View {
    let symbol: String
    let tint: Color
    let title: String
    let subtitle: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 14) {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(tint.gradient)
                    .frame(width: 64, height: 64)
                    .overlay {
                        Image(systemName: symbol)
                            .font(.system(size: 30, weight: .medium))
                            .foregroundStyle(.white)
                    }
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.largeTitle.bold())
                    Text(subtitle).font(.title3).foregroundStyle(.secondary)
                }
            }
            VStack(alignment: .leading, spacing: 16) {
                content
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct OnboardingFeatureRow: View {
    let symbol: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).fontWeight(.semibold)
                Text(detail).font(.callout).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
