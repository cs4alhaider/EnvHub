import { GITHUB_URL } from '../components/Nav'

export default function Privacy() {
  return (
    <main className="page">
      <div className="wrap">
        <div className="eyebrow"><b style={{ color: 'var(--dev)' }}>#</b> PRIVACY POLICY · EFFECTIVE JULY 11, 2026</div>
        <h1>Your secrets never <em className="grad">leave your Mac</em>.</h1>

        <div className="prose">
          <h2>What EnvHub collects</h2>
          <p><b>Nothing.</b></p>
          <p>
            EnvHub has no analytics, no telemetry, no crash reporting, no accounts, and no servers.
            The app never makes a network request. The corresponding App Store privacy label is
            <b> “Data Not Collected.”</b>
          </p>

          <h2>Where your data lives</h2>
          <ul>
            <li><b>Your <code>.env</code> files</b> stay exactly where they are on disk. EnvHub reads and writes them in place and keeps a local <code>.bak</code> backup next to the file when you save.</li>
            <li><b>App state</b> (your project list, workspaces, pins, settings) is stored in a local database on your Mac. It contains file paths and app preferences — not the contents of your <code>.env</code> files.</li>
            <li><b>Folder access</b> is granted by you through the standard macOS open panel and remembered with security-scoped bookmarks, which stay on your Mac.</li>
          </ul>

          <h2>Encrypted sharing</h2>
          <p>
            When you export an encrypted <code>.envenc</code> file, encryption happens locally on your
            Mac (scrypt key derivation + AES-256-GCM). The file is yours; EnvHub never uploads it
            anywhere. Anyone you share it with needs the passphrase you chose.
          </p>

          <h2>Third parties</h2>
          <p>There are none. EnvHub embeds no third-party SDKs, ad frameworks, or trackers.</p>

          <h2>Open source</h2>
          <p>
            EnvHub's complete source code is public at{' '}
            <a href={GITHUB_URL} target="_blank" rel="noreferrer">github.com/cs4alhaider/EnvHub</a>, so every claim
            in this policy can be verified by reading the code.
          </p>

          <h2>Changes</h2>
          <p>
            If this policy ever changes, the update will appear here and in the repository's{' '}
            <a href={`${GITHUB_URL}/blob/main/PRIVACY.md`} target="_blank" rel="noreferrer">PRIVACY.md</a> with a new
            effective date, alongside the app's release notes.
          </p>

          <h2>Contact</h2>
          <p>
            Questions? Open an issue at{' '}
            <a href={`${GITHUB_URL}/issues`} target="_blank" rel="noreferrer">github.com/cs4alhaider/EnvHub/issues</a>{' '}
            or reach the developer at <a href="https://alhaider.net" target="_blank" rel="noreferrer">alhaider.net</a>.
          </p>
        </div>
      </div>
    </main>
  )
}
