import type { CSSProperties, ReactNode } from 'react'
import Reveal from '../components/Reveal'
import Terminal from '../components/Terminal'
import { APP_STORE_URL, GITHUB_URL } from '../components/Nav'
import icon from '../assets/icon.png'
import badge from '../assets/mac-app-store-badge.svg'
import shotHero from '../assets/01-hero.png'
import shotQuickOpen from '../assets/02-quickopen.png'
import shotSaveReview from '../assets/03-savereview.png'
import shotDashboard from '../assets/04-dashboard.png'
import shotTabs from '../assets/05-tabs.png'
import shotEnvironments from '../assets/07-environments.png'

/* The six environment kinds — the accent system for the whole page. */
const KINDS = [
  ['Development', 'var(--dev)'],
  ['Staging', 'var(--staging)'],
  ['Production', 'var(--prod)'],
  ['Local', 'var(--local)'],
  ['Example', 'var(--example)'],
  ['Other', 'var(--other)'],
] as const

function Act({
  n, tag, accent, title, lede, bullets, children, flip = false,
}: {
  n: string
  tag: string
  accent: string
  title: ReactNode
  lede: string
  bullets: Array<ReactNode>
  children: ReactNode
  flip?: boolean
}) {
  return (
    <section className="act">
      <div className={`wrap act-grid${flip ? ' flip' : ''}`}>
        <Reveal className="act-copy">
          <div className="eyebrow"><b style={{ color: accent }}># {n}</b> · {tag}</div>
          <h2>{title}</h2>
          <p className="lede">{lede}</p>
          <ul style={{ '--accent': accent } as CSSProperties}>
            {/* Wrap each bullet in one span: in a flex row the <b> label would
                otherwise become its own flex item and wrap in a narrow column. */}
            {bullets.map((b, i) => <li key={i}><span>{b}</span></li>)}
          </ul>
        </Reveal>
        <Reveal delay={1}>{children}</Reveal>
      </div>
    </section>
  )
}

export default function Landing() {
  return (
    <main>
      {/* ============ HERO ============ */}
      <section className="hero">
        <div className="wrap">
          <Reveal><img className="hero-icon" src={icon} alt="EnvHub app icon" /></Reveal>
          <Reveal delay={1}>
            <h1>Every <em className="grad">.env</em> file on your Mac. One home.</h1>
          </Reveal>
          <Reveal delay={2}>
            <p className="sub">
              Projects, workspaces and environments — organized in a fast, native macOS app.
              Open source, local-only, and your values stay masked until you say otherwise.
            </p>
          </Reveal>
          <Reveal delay={3}>
            <div className="hero-ctas">
              <a className="badge-link" href={APP_STORE_URL} target="_blank" rel="noreferrer">
                <img src={badge} alt="Download on the Mac App Store" />
              </a>
              <code className="brew"><span className="dollar">$</span> brew install cs4alhaider/tap/envhub</code>
              <span className="note">App in review — releasing soon · CLI on Homebrew today · macOS 26+</span>
            </div>
          </Reveal>
          <Reveal delay={3}>
            <figure className="hero-shot shot"><img src={shotHero} alt="EnvHub main window: workspace sidebar, environment tabs, and the masked-value editor" /></figure>
          </Reveal>
        </div>
      </section>

      {/* ============ TICKER ============ */}
      <div className="strip" aria-hidden>
        <div className="strip-inner">
          {[0, 1].map(k => (
            <span key={k}>
              <i style={{ color: 'var(--dev)' }}>100% offline</i> &nbsp;·&nbsp; open source · GPL-3.0 &nbsp;·&nbsp;{' '}
              <i style={{ color: 'var(--local)' }}>native SwiftUI</i> &nbsp;·&nbsp; zero telemetry &nbsp;·&nbsp;{' '}
              <i style={{ color: 'var(--example)' }}>scrypt + AES-256-GCM</i> &nbsp;·&nbsp; sandboxed &nbsp;·&nbsp;{' '}
              <i style={{ color: 'var(--staging)' }}>values masked by default</i> &nbsp;·&nbsp; 100 UI-free tests &nbsp;·&nbsp;{' '}
              DATABASE_URL=•••••••• &nbsp;·&nbsp; STRIPE_SECRET_KEY=•••••••• &nbsp;·&nbsp; OPENAI_API_KEY=•••••••• &nbsp;·&nbsp;
            </span>
          ))}
        </div>
      </div>

      {/* ============ ACT 1 · ORGANIZE ============ */}
      <Act
        n="01" tag="ORGANIZE" accent="var(--local)"
        title={<>Your whole workspace, <em className="grad">at a glance</em>.</>}
        lede="Add project folders once — EnvHub groups them into pinned favorites, custom workspaces and dashboards that count every file and variable."
        bullets={[
          <><b>Workspaces & pins</b> — drag-and-drop grouping, bulk move, collapsible sections that remember themselves.</>,
          <><b>Dashboards</b> — click a section header for projects, files and variables, color-coded per environment.</>,
          <><b>Native tabs & windows</b> — open each client's stack side by side, exactly like Finder.</>,
        ]}
      >
        <figure className="shot"><img src={shotDashboard} alt="Workspace dashboard with per-project cards" loading="lazy" /></figure>
      </Act>

      <section style={{ paddingTop: 40 }}>
        <div className="wrap">
          <Reveal>
            <figure className="shot crop" style={{ maxHeight: 260, '--zoom': '135%', '--y': '-2%' } as CSSProperties}>
              <img src={shotTabs} alt="Native macOS tabs across three projects" loading="lazy" />
            </figure>
          </Reveal>
        </div>
      </section>

      {/* ============ ACT 2 · EDIT ============ */}
      <Act
        flip n="02" tag="EDIT SAFELY" accent="var(--staging)"
        title={<>Review every change <em className="grad">before</em> it hits disk.</>}
        lede="A real editor for env files: keys, values and the comment above each entry — masked by default, diffed on save, backed up every time."
        bullets={[
          <><b>Save review</b> — added / changed / removed, values and comments, one clear sheet before writing.</>,
          <><b>Automatic .bak</b> — the previous version sits right next to the file, every save.</>,
          <><b>Byte-faithful writes</b> — untouched lines, comments, blank lines and CRLF endings survive exactly.</>,
          <><b>Raw mode</b> — flip to plain text when you'd rather paste a block.</>,
        ]}
      >
        <figure className="shot"><img src={shotSaveReview} alt="Save review sheet showing an added, changed and removed variable" loading="lazy" /></figure>
      </Act>

      {/* ============ ACT 3 · FIND ============ */}
      <Act
        n="03" tag="FIND INSTANTLY" accent="var(--dev)"
        title={<>Find any key in <em className="grad">a keystroke</em>.</>}
        lede="⇧⌘O searches keys, values, comments and filenames across every project at once — grouped by project, colored by environment."
        bullets={[
          <><b>Quick Open</b> — full keyboard flow: type, arrow, return, done.</>,
          <><b>Search privacy</b> — exclude entire environments (say, Production) from results.</>,
          <><b>Zero lag</b> — a prebuilt index means no disk I/O per keystroke, even with hundreds of projects.</>,
        ]}
      >
        <figure className="shot crop" style={{ maxHeight: 430, '--zoom': '145%', '--x': '-28%', '--y': '-4%' } as CSSProperties}>
          <img src={shotQuickOpen} alt="Quick Open panel finding STRIPE keys across three projects" loading="lazy" />
        </figure>
      </Act>

      {/* ============ ACT 4 · ENVIRONMENTS ============ */}
      <Act
        flip n="04" tag="CLASSIFY" accent="var(--example)"
        title={<>Your environments, <em className="grad">your rules</em>.</>}
        lede="Development, Staging, Production, Local and Example ship as defaults — add UAT, Pre-Prod, anything, with your own names, colors and ordering."
        bullets={[
          <><b>Filename rules</b> — editable regex mapping decides what lands where; first match wins.</>,
          <><b>Safe-to-commit</b> — Example templates are marked committable and never nag you.</>,
          <>
            <b>Colors everywhere</b> — tabs, dots, dashboards and search all speak the same palette:&nbsp;
            {KINDS.map(([name, color]) => (
              <span key={name} title={name} style={{
                display: 'inline-block', width: 10, height: 10, borderRadius: 5,
                background: color, marginRight: 5, verticalAlign: 'middle',
              }} />
            ))}
          </>,
        ]}
      >
        <figure className="shot"><img src={shotEnvironments} alt="Environments editor with per-environment colors and safe-to-commit flags" loading="lazy" /></figure>
      </Act>

      {/* ============ ACT 5 · SHARE ============ */}
      <Act
        n="05" tag="SHARE SAFELY" accent="var(--prod)"
        title={<>Secrets travel <em className="grad">encrypted</em> — or not at all.</>}
        lede="Export a file, a project or your whole library as a password-protected .envenc. Move machines, onboard teammates, keep an off-site backup."
        bullets={[
          <><b>Real crypto</b> — scrypt key derivation + AES-256-GCM, implemented on Apple CryptoKit and tested against the RFC 7914 vectors.</>,
          <><b>All on-device</b> — encryption happens on your Mac; nothing is ever uploaded.</>,
          <><b>Fails cleanly</b> — authenticated encryption means a wrong password never produces silent garbage.</>,
          <><b>Diff before deploy</b> — compare two environments side by side and catch the missing key first.</>,
        ]}
      >
        <div className="envelope" aria-label="the .envenc file format">
          <div className="dim2">// secrets.envenc</div>
          <div>{'{'}</div>
          <div>&nbsp;&nbsp;<span className="k">"version"</span>: 1,</div>
          <div>&nbsp;&nbsp;<span className="k">"type"</span>: <span className="s">"library"</span>,</div>
          <div>&nbsp;&nbsp;<span className="k">"kdf"</span>: <span className="s">"scrypt"</span>, <span className="dim2">// N=32768, r=8, p=1</span></div>
          <div>&nbsp;&nbsp;<span className="k">"salt"</span>: <span className="s">"kY2…"</span>,</div>
          <div>&nbsp;&nbsp;<span className="k">"nonce"</span>: <span className="s">"9fA…"</span>,</div>
          <div>&nbsp;&nbsp;<span className="k">"ciphertext"</span>: <span className="s">"AES-256-GCM ••••••••••••••••"</span></div>
          <div>{'}'}</div>
        </div>
      </Act>

      {/* ============ CLI ============ */}
      <Act
        flip n="06" tag="SCRIPT IT" accent="var(--teal, #40c8e0)"
        title={<>The same core, <em className="grad">in your shell</em>.</>}
        lede="The envhub CLI shares the app's library — organize a workspace in the terminal and watch the sidebar update."
        bullets={[
          <><b>Nine commands</b> — scan, list, get, export, import, workspace, add, open, store.</>,
          <><b>Masked output</b> — values stay dots in your scrollback unless you ask.</>,
          <><b>Agent-ready</b> — a bundled skill teaches AI coding agents to use it safely.</>,
        ]}
      >
        <Terminal />
      </Act>

      {/* ============ PRIVACY ============ */}
      <div className="wrap">
        <Reveal className="privacy-panel">
          <div className="eyebrow" style={{ marginBottom: 8 }}><b style={{ color: 'var(--dev)' }}># 07</b> · PRIVATE BY DESIGN</div>
          <h2 style={{ fontSize: 'clamp(30px, 4.5vw, 48px)' }}>
            Your secrets never leave your Mac.<br /><em className="grad">The code proves it.</em>
          </h2>
          <div className="zeros">
            <div><b>0</b><span>servers</span></div>
            <div><b>0</b><span>accounts</span></div>
            <div><b>0</b><span>trackers</span></div>
            <div><b>0</b><span>network calls</span></div>
          </div>
          <p style={{ color: 'var(--dim)', maxWidth: '58ch', margin: '18px auto 0' }}>
            EnvHub is fully sandboxed, works entirely offline, and every line is public under
            GPL-3.0. The App Store privacy label reads “Data Not Collected” — because there is
            nothing to collect it with.
          </p>
          <p style={{ marginTop: 22 }}>
            <a href={GITHUB_URL} target="_blank" rel="noreferrer" style={{ color: 'var(--local)', fontWeight: 600 }}>
              Read the source →
            </a>
          </p>
        </Reveal>
      </div>

      {/* ============ DOWNLOAD ============ */}
      <section className="dl">
        <div className="wrap">
          <Reveal>
            <div className="eyebrow"><b style={{ color: 'var(--local)' }}># 08</b> · GET ENVHUB</div>
            <h2>Give your <em className="grad">.env</em> files a home.</h2>
          </Reveal>
          <Reveal delay={1}>
            <div className="hero-ctas">
              <a className="badge-link" href={APP_STORE_URL} target="_blank" rel="noreferrer">
                <img src={badge} alt="Download on the Mac App Store" />
              </a>
              <code className="brew"><span className="dollar">$</span> brew install cs4alhaider/tap/envhub</code>
              <span className="note">Free · macOS 26 (Tahoe) · the app and CLI share one library</span>
            </div>
          </Reveal>
        </div>
      </section>
    </main>
  )
}
