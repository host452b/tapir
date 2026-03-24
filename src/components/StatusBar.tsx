import type { CSSProperties } from 'react'
import { useAppState } from '../hooks/useAppState'

const barStyle: CSSProperties = {
  display: 'flex',
  alignItems: 'center',
  justifyContent: 'space-between',
  height: 24,
  background: 'var(--bg-secondary)',
  borderTop: '1px solid var(--border)',
  padding: '0 12px',
  fontFamily: 'var(--font-mono)',
  fontSize: 10,
  flexShrink: 0,
}

const sectionStyle: CSSProperties = {
  display: 'flex',
  alignItems: 'center',
  gap: 6,
}

function dotStyle(color: string): CSSProperties {
  return {
    width: 6,
    height: 6,
    borderRadius: '50%',
    background: color,
    flexShrink: 0,
  }
}

export function StatusBar() {
  const hasPermission = useAppState((s) => s.hasPermission)
  const selectedWindows = useAppState((s) => s.selectedWindows)
  const keySteps = useAppState((s) => s.keySteps)
  const intervalMs = useAppState((s) => s.intervalMs)
  const sendingState = useAppState((s) => s.sendingState)

  const permissionColor = hasPermission ? 'var(--green)' : 'var(--red)'

  const stateColor =
    sendingState === 'running'
      ? 'var(--green)'
      : sendingState === 'paused'
        ? 'var(--yellow)'
        : 'var(--text-dim)'

  return (
    <div style={barStyle}>
      <div style={sectionStyle}>
        <span style={dotStyle(permissionColor)} />
        <span style={{ color: 'var(--text-dim)' }}>Accessibility</span>
      </div>
      <div style={sectionStyle}>
        <span style={{ color: 'var(--text-dim)' }}>
          {selectedWindows.length} target(s)
        </span>
        <span style={{ color: 'var(--text-muted)' }}>|</span>
        <span style={{ color: 'var(--text-dim)' }}>
          {keySteps.length} step(s)
        </span>
        <span style={{ color: 'var(--text-muted)' }}>|</span>
        <span style={{ color: 'var(--text-dim)' }}>
          {intervalMs}ms
        </span>
      </div>
      <div style={sectionStyle}>
        <span style={{ color: stateColor, textTransform: 'uppercase', fontWeight: 600 }}>
          {sendingState}
        </span>
      </div>
    </div>
  )
}
