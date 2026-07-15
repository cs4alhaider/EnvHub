import { NavLink, Link } from 'react-router-dom'
import { useTheme } from './theme'
import icon from '../assets/icon.png'

export const APP_STORE_URL = 'https://apps.apple.com/app/id6788664509'
export const GITHUB_URL = 'https://github.com/cs4alhaider/EnvHub'

export default function Nav() {
  const { theme, toggle } = useTheme()
  return (
    <header className="nav">
      <div className="nav-inner">
        <Link to="/" className="nav-logo">
          <img src={icon} alt="" width={34} height={34} />
          EnvHub
        </Link>
        <nav className="nav-links">
          <NavLink to="/" end>Overview</NavLink>
          <NavLink to="/docs" className="keep">Docs</NavLink>
          <NavLink to="/support">Support</NavLink>
          <a href={GITHUB_URL} target="_blank" rel="noreferrer">GitHub</a>
        </nav>
        <button
          className="theme-btn"
          onClick={toggle}
          aria-label={`Switch to ${theme === 'dark' ? 'light' : 'dark'} theme`}
          title={`Switch to ${theme === 'dark' ? 'light' : 'dark'} theme`}
        >
          {theme === 'dark' ? (
            <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round">
              <circle cx="12" cy="12" r="4.5" />
              <path d="M12 2v2.5M12 19.5V22M2 12h2.5M19.5 12H22M4.6 4.6l1.8 1.8M17.6 17.6l1.8 1.8M4.6 19.4l1.8-1.8M17.6 6.4l1.8-1.8" />
            </svg>
          ) : (
            <svg width="15" height="15" viewBox="0 0 24 24" fill="currentColor">
              <path d="M21 13.2A8.6 8.6 0 0 1 10.8 3 8.6 8.6 0 1 0 21 13.2Z" />
            </svg>
          )}
        </button>
        <a className="nav-cta" href={APP_STORE_URL} target="_blank" rel="noreferrer">
          Get the app
        </a>
      </div>
    </header>
  )
}
