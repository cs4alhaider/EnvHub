import { Link } from 'react-router-dom'
import { APP_STORE_URL, GITHUB_URL } from './Nav'

export default function Footer() {
  return (
    <footer className="footer">
      <div className="wrap footer-inner">
        <div className="cols">
          <Link to="/docs">Documentation</Link>
          <Link to="/support">Support</Link>
          <Link to="/privacy">Privacy</Link>
          <a href={GITHUB_URL} target="_blank" rel="noreferrer">GitHub</a>
          <a href={`${GITHUB_URL}/blob/main/LICENSE`} target="_blank" rel="noreferrer">GPL-3.0</a>
          <a href={APP_STORE_URL} target="_blank" rel="noreferrer">Mac App Store</a>
        </div>
        <div className="mono">
          KEY=<span style={{ letterSpacing: 2 }}>••••••</span> · built by{' '}
          <a href="https://alhaider.net" target="_blank" rel="noreferrer" style={{ color: 'var(--dim)' }}>
            Abdullah Alhaider
          </a>{' '}
          · © 2026
        </div>
      </div>
    </footer>
  )
}
