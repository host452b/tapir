import { type CSSProperties, useState } from 'react'
import { useAppState } from '../hooks/useAppState'
import { PixelBadge } from './ui'
import { AboutPanel } from './AboutPanel'

const barStyle: CSSProperties = {
  display: 'flex',
  alignItems: 'center',
  justifyContent: 'space-between',
  height: 36,
  background: 'var(--bg-secondary)',
  borderBottom: '1px solid var(--border)',
  paddingLeft: 70, // space for macOS traffic lights
  paddingRight: 12,
  flexShrink: 0,
}

const titleStyle: CSSProperties = {
  fontFamily: 'var(--font-mono)',
  fontSize: 24,
  fontWeight: 900,
  color: 'var(--text-primary)',
  letterSpacing: '1px',
  lineHeight: 1,
}

const centerStyle: CSSProperties = {
  display: 'flex',
  alignItems: 'center',
  gap: 6,
}

const versionStyle: CSSProperties = {
  fontFamily: 'var(--font-mono)',
  fontSize: 10,
  color: 'var(--text-dim)',
}

const aboutBtnStyle: CSSProperties = {
  display: 'flex',
  alignItems: 'center',
  gap: 8,
}

const infoBtnStyle: CSSProperties = {
  fontFamily: 'var(--font-mono)',
  fontSize: 11,
  color: 'var(--text-dim)',
  cursor: 'pointer',
  padding: '2px 6px',
  borderRadius: 'var(--radius-sm)',
  border: '1px solid transparent',
  background: 'transparent',
  transition: 'all 120ms ease',
}

export function TitleBar() {
  const selectedWindows = useAppState((s) => s.selectedWindows)
  const keySteps = useAppState((s) => s.keySteps)
  const [showAbout, setShowAbout] = useState(false)

  return (
    <>
      <div style={barStyle} data-tauri-drag-region>
        <span style={titleStyle}>TAPIR</span>
        <div style={centerStyle}>
          <PixelBadge color="var(--cyan)">{selectedWindows.length} target(s)</PixelBadge>
          <PixelBadge color="var(--green)">{keySteps.length} step(s)</PixelBadge>
        </div>
        <div style={aboutBtnStyle}>
          <span style={versionStyle}>v2.0</span>
          <button
            style={infoBtnStyle}
            onClick={() => setShowAbout(true)}
            onMouseEnter={(e) => {
              e.currentTarget.style.color = 'var(--accent)'
              e.currentTarget.style.borderColor = 'var(--border)'
            }}
            onMouseLeave={(e) => {
              e.currentTarget.style.color = 'var(--text-dim)'
              e.currentTarget.style.borderColor = 'transparent'
            }}
          >
            About
          </button>
        </div>
      </div>
      {showAbout && <AboutPanel onClose={() => setShowAbout(false)} />}
    </>
  )
}
