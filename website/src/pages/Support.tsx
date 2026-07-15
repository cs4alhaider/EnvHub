import type { ReactNode } from 'react'
import { Link } from 'react-router-dom'
import { APP_STORE_URL, GITHUB_URL } from '../components/Nav'

const FAQ: Array<[string, ReactNode]> = [
  ['Is EnvHub really offline?', <p key="a">Yes — the app makes no network requests at all. No accounts, no telemetry, no crash reporting. It's open source (GPL-3.0), so you can verify that claim in the code rather than take our word for it.</p>],
  ['Where is my data stored?', <p key="a">Your <code>.env</code> files stay exactly where they are on disk — EnvHub edits them in place and keeps a <code>.bak</code> backup on every save. App state (project list, workspaces, settings) lives in a local database in the app-group container; <code>envhub store</code> prints its exact path.</p>],
  ['Why does EnvHub ask for folder access?', <p key="a">EnvHub runs in the macOS App Sandbox. Choosing a folder in the open panel is the permission grant, and macOS remembers it across launches. If a grant is revoked you'll see a “Grant Access” screen — re-pick the folder and you're back.</p>],
  ['Can the app and the Homebrew CLI work together?', <p key="a">Yes — they share one library. Workspaces you create in the terminal appear in the sidebar instantly, and vice versa.</p>],
  ['I forgot an .envenc password. Can you recover it?', <p key="a">No — by design. <code>.envenc</code> files are sealed with scrypt + AES-256-GCM and there is no backdoor, no account, and no server. Keep passwords in your password manager.</p>],
  ['Does EnvHub touch git?', <p key="a">The App Store edition never runs git. Saving a file in EnvHub only writes that file (plus its <code>.bak</code>) — nothing is staged, committed, or pushed.</p>],
  ['Which macOS versions are supported?', <p key="a">macOS 26 (Tahoe) and later — EnvHub is built on the latest SwiftUI and SwiftData.</p>],
  ['Is it really free?', <p key="a">Yes, and open source. If EnvHub is useful, a star on GitHub or an App Store review genuinely helps others find it.</p>],
]

export default function Support() {
  return (
    <main className="page">
      <div className="wrap">
        <div className="eyebrow"><b style={{ color: 'var(--dev)' }}>#</b> SUPPORT</div>
        <h1>We're here — <em className="grad">and it's fast</em>.</h1>
        <p className="pagesub">
          EnvHub is built in the open by one developer. Questions, bugs and ideas all land in the
          same place — GitHub — and they're read.
        </p>

        <div className="support-cards">
          <a className="scard" href={`${GITHUB_URL}/issues/new`} target="_blank" rel="noreferrer">
            <div className="ic">🐛</div>
            <h3>Report a bug</h3>
            <p>macOS version + steps to reproduce is all it takes. Never paste real secret values into an issue.</p>
            <span className="go">Open an issue →</span>
          </a>
          <a className="scard" href={`${GITHUB_URL}/issues`} target="_blank" rel="noreferrer">
            <div className="ic">💡</div>
            <h3>Request a feature</h3>
            <p>An environment type we're missing, a CLI verb, an editor nicety — small, sharp proposals ship fastest.</p>
            <span className="go">Suggest it →</span>
          </a>
          <Link className="scard" to="/docs">
            <div className="ic">📚</div>
            <h3>Read the docs</h3>
            <p>Task-oriented guides for everything: projects, the editor, search, environments, sharing, the CLI.</p>
            <span className="go">Documentation →</span>
          </Link>
          <a className="scard" href="https://alhaider.net" target="_blank" rel="noreferrer">
            <div className="ic">🔒</div>
            <h3>Security reports</h3>
            <p>Found a vulnerability? Contact the author privately before disclosing publicly.</p>
            <span className="go">alhaider.net →</span>
          </a>
        </div>

        <h2 style={{ fontSize: 28, marginTop: 80 }}>Frequently asked</h2>
        <div className="faq">
          {FAQ.map(([q, a]) => (
            <details className="qa" key={q}>
              <summary>{q}</summary>
              {a}
            </details>
          ))}
        </div>

        <p style={{ marginTop: 60, color: 'var(--dim)', fontSize: 15 }}>
          Enjoying EnvHub? A review on the{' '}
          <a href={APP_STORE_URL} target="_blank" rel="noreferrer" style={{ color: 'var(--local)' }}>Mac App Store</a>{' '}
          or a ⭐ on <a href={GITHUB_URL} target="_blank" rel="noreferrer" style={{ color: 'var(--local)' }}>GitHub</a>{' '}
          is the best thank-you there is.
        </p>
      </div>
    </main>
  )
}
