import { useEffect, useState } from 'react'
import { APP_STORE_URL, GITHUB_URL } from '../components/Nav'

const SECTIONS = [
  ['get-started', 'Get started'],
  ['projects', 'Projects & workspaces'],
  ['editor', 'The editor'],
  ['search', 'Search'],
  ['environments', 'Environments'],
  ['scanner', 'Scanner'],
  ['sharing', 'Encrypted sharing'],
  ['cli', 'The CLI'],
  ['shortcuts', 'Shortcuts'],
] as const

export default function Docs() {
  const [active, setActive] = useState('get-started')

  useEffect(() => {
    const io = new IntersectionObserver(
      es => es.forEach(e => e.isIntersecting && setActive(e.target.id)),
      { rootMargin: '-20% 0px -70% 0px' },
    )
    document.querySelectorAll('.doc-section').forEach(s => io.observe(s))
    return () => io.disconnect()
  }, [])

  return (
    <main className="page">
      <div className="wrap">
        <div className="eyebrow"><b style={{ color: 'var(--local)' }}>#</b> DOCUMENTATION</div>
        <h1>How to do <em className="grad">anything</em> in EnvHub.</h1>
        <p className="pagesub">
          Task-oriented guides for the app and the CLI. Something missing?{' '}
          <a href={`${GITHUB_URL}/issues/new`} target="_blank" rel="noreferrer" style={{ color: 'var(--local)' }}>Open an issue</a>.
        </p>

        <div className="docs-layout">
          <nav className="docs-rail" aria-label="Documentation sections">
            {SECTIONS.map(([id, label]) => (
              <a key={id} href={`#${id}`} className={active === id ? 'active' : ''}># {label.toLowerCase()}</a>
            ))}
          </nav>

          <div className="docs-body">
            <section className="doc-section" id="get-started">
              <h2>Get started</h2>
              <p>
                Install the app from the <a href={APP_STORE_URL} target="_blank" rel="noreferrer">Mac App Store</a> (macOS 26+).
                On first launch a short welcome tour offers the two ways in:
              </p>
              <ul>
                <li><b>Add Project…</b> (<kbd>⌘N</kbd>) — pick a folder you already know has <code>.env</code> files.</li>
                <li><b>Scan…</b> (<kbd>⇧⌘F</kbd>) — point EnvHub at a parent folder (like <code>~/Developer</code>) and let it discover everything.</li>
              </ul>
              <p>
                EnvHub is sandboxed: the folder you pick in the open panel <b>is</b> the permission grant, and macOS
                remembers it across launches. If access is ever revoked you'll see a clear “Grant Access” screen —
                one click to fix.
              </p>
              <p>Optionally add the CLI:</p>
              <pre className="code">brew install cs4alhaider/tap/envhub</pre>
            </section>

            <section className="doc-section" id="projects">
              <h2>Projects & workspaces</h2>
              <h3>Organize the sidebar</h3>
              <ul>
                <li>Create a workspace with <kbd>⇧⌘N</kbd>, then <b>drag projects onto its header</b> — or multi-select and use the context menu to move several at once.</li>
                <li><b>Pin</b> favorites from the context menu; pinned projects surface at the top.</li>
                <li>Sections collapse (chevron on hover) and remember their state; a search always expands matches.</li>
                <li>Paths display home-relative (<code>~/Developer/api</code>) with the tail always visible.</li>
              </ul>
              <h3>Dashboards</h3>
              <p>Click a section header to see that workspace at a glance: projects, env files and variable counts with environment-colored dots. Double-click any card to open the project.</p>
              <h3>Tabs & windows</h3>
              <ul>
                <li><b>Double-click</b> a sidebar project → its own window.</li>
                <li><b>⌘-double-click</b> → a native tab (each tab is a full window, sidebar included).</li>
                <li>Context menu: “Open in New Tab(s) / Window(s)” works on multi-selections; Merge All Windows behaves like Finder.</li>
              </ul>
              <p>Removing a project only forgets it in EnvHub — nothing on disk is ever touched.</p>
            </section>

            <section className="doc-section" id="editor">
              <h2>The editor</h2>
              <h3>Table mode</h3>
              <ul>
                <li>Every file is a <b>Key / Value / Comment</b> table. The Comment column is the <code># line</code> directly above each entry — edit it inline and it survives every save.</li>
                <li>Values are <b>masked by default</b>. Reveal one row with its eye button, or everything with the eye toggle in the editor bar (default lives in Settings → General).</li>
                <li>Add rows with <b>+</b>, remove with <b>−</b>, and switch environments with the tabs above the editor.</li>
              </ul>
              <h3>Saving</h3>
              <ul>
                <li><kbd>⌘S</kbd> opens the <b>Save Review</b>: added / changed / removed entries (values <i>and</i> comments) before anything is written.</li>
                <li>Every save keeps a <code>.bak</code> of the previous version next to the file.</li>
                <li>Untouched lines are written back <b>byte-for-byte</b> — ordering, blank lines, comments and CRLF endings all survive.</li>
              </ul>
              <h3>Files</h3>
              <ul>
                <li><b>New File</b> can start blank or copy an existing file's keys with values stripped — a perfect <code>.env.example</code> in one click.</li>
                <li>The <b>ⓘ</b> button shows created / modified / size / variable count / latest backup, with Reveal in Finder.</li>
                <li><b>Compare</b> (toolbar) diffs two environments side by side, read-only.</li>
              </ul>
            </section>

            <section className="doc-section" id="search">
              <h2>Search</h2>
              <ul>
                <li>The sidebar field filters projects <b>and</b> searches keys, values, comments and filenames — hit counts appear as badges.</li>
                <li><kbd>⇧⌘O</kbd> opens <b>Quick Open</b>: type anything, arrow through grouped results, <kbd>↩</kbd> jumps straight to the file.</li>
                <li>Settings → Search can <b>exclude whole environments</b> from results (keep Production values out of your screen-shares). New environments are searchable by default.</li>
              </ul>
            </section>

            <section className="doc-section" id="environments">
              <h2>Environments</h2>
              <p>
                Files are classified by <b>ordered regex rules</b> on the filename (Settings → Classification → Rules):
                <code>.env.production</code> → Production, <code>.env.development.local</code> → Local,
                <code>.env.production.example</code> → Example (example wins on purpose — templates are meant to be committed).
              </p>
              <ul>
                <li>Add your own environment in Settings → Classification → Environments: name it (UAT, Pre-Prod…), pick a color, drag to reorder.</li>
                <li><b>Safe to commit</b> marks environments (like Example) whose files shouldn't trigger warnings.</li>
                <li>The colors drive tabs, dots, dashboards, and Quick Open.</li>
              </ul>
            </section>

            <section className="doc-section" id="scanner">
              <h2>Scanner</h2>
              <ul>
                <li><kbd>⇧⌘F</kbd> → pick folders → EnvHub walks them <b>in parallel</b>, typically seconds for a whole dev directory.</li>
                <li>Noise is skipped by default (<code>node_modules</code>, <code>.git</code>, caches, <code>~/Library</code>…) — the exclusion list and filename patterns are editable in Settings → Scanning.</li>
                <li><b>Stop &amp; Review</b> keeps partial results; already-imported projects show an “Added” badge and are skipped by Select All.</li>
                <li>Pick a destination workspace as you import.</li>
              </ul>
            </section>

            <section className="doc-section" id="sharing">
              <h2>Encrypted sharing (.envenc)</h2>
              <ul>
                <li><b>Export</b> (toolbar lock icon) encrypts one file or a whole project; Settings → Data → “Export All Variables” does your entire library.</li>
                <li>Crypto: <b>scrypt</b> key derivation + <b>AES-256-GCM</b>, entirely on-device. Wrong passwords fail cleanly.</li>
                <li><b>Import</b> (<kbd>⌘I</kbd>) previews the contents, then recreates files where you choose — library exports get per-project subfolders.</li>
                <li>Share the password out-of-band. Lost passwords are unrecoverable by design.</li>
              </ul>
            </section>

            <section className="doc-section" id="cli">
              <h2>The CLI</h2>
              <p>The <code>envhub</code> CLI shares the app's library — changes appear in the sidebar instantly.</p>
              <pre className="code">{`brew install cs4alhaider/tap/envhub

envhub add .                    `}<span className="c"># add the current folder as a project</span>{`
envhub ~/code/my-app            `}<span className="c"># open a window without adding</span>{`
envhub scan ~/Developer --deep  `}<span className="c"># discover .env files</span>{`
envhub list ./my-app --mask     `}<span className="c"># files + variables, masked</span>{`
envhub get API_KEY --project ./my-app --mask
envhub export ./my-app --project --out secrets.envenc
envhub import secrets.envenc --into ./restored
envhub workspace create Backend
envhub workspace move ./my-app Backend
envhub store                    `}<span className="c"># prints the shared database path</span></pre>
              <p>
                <code>ENVHUB_STORE=&lt;path&gt;</code> points the CLI (or the app) at a different store.
                For AI coding agents, the repo ships a ready-made <a href={`${GITHUB_URL}/blob/main/skills/envhub-cli/SKILL.md`} target="_blank" rel="noreferrer">agent skill</a>.
              </p>
            </section>

            <section className="doc-section" id="shortcuts">
              <h2>Shortcuts</h2>
              <table className="tbl">
                <thead><tr><th>Action</th><th>Shortcut</th></tr></thead>
                <tbody>
                  <tr><td>Add project</td><td><kbd>⌘N</kbd></td></tr>
                  <tr><td>New workspace</td><td><kbd>⇧⌘N</kbd></td></tr>
                  <tr><td>Quick Open (search everywhere)</td><td><kbd>⇧⌘O</kbd></td></tr>
                  <tr><td>Scan for .env files</td><td><kbd>⇧⌘F</kbd></td></tr>
                  <tr><td>Import .envenc</td><td><kbd>⌘I</kbd></td></tr>
                  <tr><td>Save (opens Save Review)</td><td><kbd>⌘S</kbd></td></tr>
                  <tr><td>Settings</td><td><kbd>⌘,</kbd></td></tr>
                  <tr><td>Remove selected project(s)</td><td><kbd>⌫</kbd></td></tr>
                </tbody>
              </table>
            </section>
          </div>
        </div>
      </div>
    </main>
  )
}
