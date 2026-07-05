//
//  StarPromptView.swift
//  EnvHub
//
//  A gentle, occasional nudge — shown after the app has been used a while (see the
//  launch counter in RootView) — asking to star the project on GitHub. Unlike the
//  onboarding page, this one *can* say "Enjoying EnvHub?" because by now you've used it.
//

import SwiftUI

struct StarPromptView: View {
    /// Called with the user's choice so RootView can record it.
    enum Outcome { case starred, shared, notNow, dontAsk }
    let onChoose: (Outcome) -> Void

    private let repoURL = URL(string: "https://github.com/cs4alhaider/EnvHub")!

    var body: some View {
        VStack(spacing: 18) {
            Image("GitHubMark")
                .renderingMode(.template)
                .resizable().scaledToFit()
                .frame(width: 48, height: 48)
                .foregroundStyle(.primary)

            VStack(spacing: 6) {
                Text("Enjoying EnvHub?").font(.title2.bold())
                Text("It's free and open source. If it's been useful, a star on GitHub genuinely helps others find it.")
                    .font(.callout).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 10) {
                Link(destination: repoURL) {
                    Label("Star on GitHub", systemImage: "star.fill")
                        .frame(maxWidth: .infinity)
                }
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
                .simultaneousGesture(TapGesture().onEnded { onChoose(.starred) })

                ShareLink(item: repoURL) {
                    Label("Share EnvHub", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .controlSize(.large)
                .simultaneousGesture(TapGesture().onEnded { onChoose(.shared) })
            }

            HStack {
                Button("Don't Ask Again") { onChoose(.dontAsk) }
                    .buttonStyle(.plain).foregroundStyle(.secondary)
                Spacer()
                Button("Not Now") { onChoose(.notNow) }
            }
            .font(.callout)
            .padding(.top, 2)
        }
        .padding(24)
        .frame(width: 380)
    }
}
