import { type CSSProperties, useEffect, useState } from 'react'
import { useAppState } from '../hooks/useAppState'
import { tauriCommands } from '../hooks/useTauriCommand'
import { PixelBadge, PixelButton, PixelDivider, PixelPanel } from './ui'

const containerStyle: CSSProperties = {
  display: 'flex',
  flexDirection: 'column',
  alignItems: 'center',
  justifyContent: 'center',
  flex: 1,
  gap: 16,
}

const statusIconStyle = (granted: boolean): CSSProperties => ({
  fontSize: 48,
  lineHeight: 1,
  color: granted ? 'var(--green)' : 'var(--red)',
  transition: 'all 120ms ease',
})

const statusTextStyle = (granted: boolean): CSSProperties => ({
  fontFamily: 'var(--font-mono)',
  fontSize: 14,
  fontWeight: 700,
  color: granted ? 'var(--green)' : 'var(--red)',
  textAlign: 'center',
})

const buttonRowStyle: CSSProperties = {
  display: 'flex',
  gap: 8,
  justifyContent: 'center',
}

const instructionsStyle: CSSProperties = {
  fontFamily: 'var(--font-mono)',
  fontSize: 11,
  color: 'var(--text-secondary)',
  textAlign: 'center',
  lineHeight: 1.6,
  maxWidth: 380,
}

const detailRowStyle: CSSProperties = {
  display: 'flex',
  justifyContent: 'space-between',
  fontFamily: 'var(--font-mono)',
  fontSize: 10,
  color: 'var(--text-dim)',
  gap: 12,
}

export function SystemView() {
  const hasPermission = useAppState((s) => s.hasPermission)
  const setHasPermission = useAppState((s) => s.setHasPermission)
  const showToast = useAppState((s) => s.showToast)
  const [checking, setChecking] = useState(false)

  const checkPermission = async () => {
    setChecking(true)
    try {
      const result = await tauriCommands.checkPermission()
      setHasPermission(result)
      if (result) {
        showToast('Permission granted', 'var(--green)')
      }
    } catch {
      showToast('Failed to check permission', 'var(--red)')
    } finally {
      setChecking(false)
    }
  }

  const requestPermission = async () => {
    try {
      const result = await tauriCommands.requestPermission()
      setHasPermission(result)
      if (result) {
        showToast('Permission granted', 'var(--green)')
      } else {
        showToast('Permission not yet granted', 'var(--warning)')
      }
    } catch {
      showToast('Failed to request permission', 'var(--red)')
    }
  }

  useEffect(() => {
    checkPermission()
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  return (
    <div style={containerStyle}>
      <PixelPanel header="ACCESSIBILITY" accent={hasPermission ? 'var(--green)' : 'var(--red)'}>
        <div
          style={{
            display: 'flex',
            flexDirection: 'column',
            alignItems: 'center',
            gap: 12,
            padding: '8px 24px',
            minWidth: 320,
          }}
        >
          <span style={statusIconStyle(hasPermission)}>
            {hasPermission ? '\u2713' : '\u2717'}
          </span>
          <span style={statusTextStyle(hasPermission)}>
            Accessibility permission {hasPermission ? 'GRANTED' : 'NOT GRANTED'}
          </span>

          <div style={buttonRowStyle}>
            <PixelButton variant="primary" onClick={requestPermission}>
              GRANT
            </PixelButton>
            <PixelButton onClick={checkPermission} disabled={checking}>
              CHECK
            </PixelButton>
          </div>

          <div style={{ width: '100%', padding: '4px 0' }}>
            <PixelDivider label="instructions" />
          </div>

          <p style={instructionsStyle}>
            Tapir needs Accessibility permission to send key events to other
            applications. Open System Settings &gt; Privacy &amp; Security &gt;
            Accessibility and enable Tapir.
          </p>

          <div style={{ width: '100%', padding: '4px 0' }}>
            <PixelDivider label="technical details" />
          </div>

          <div style={{ width: '100%', display: 'flex', flexDirection: 'column', gap: 4 }}>
            <div style={detailRowStyle}>
              <span>Platform</span>
              <PixelBadge color="var(--text-dim)">macOS</PixelBadge>
            </div>
            <div style={detailRowStyle}>
              <span>Engine</span>
              <PixelBadge color="var(--text-dim)">Tauri/Rust</PixelBadge>
            </div>
            <div style={detailRowStyle}>
              <span>Method</span>
              <PixelBadge color="var(--text-dim)">CGEvent</PixelBadge>
            </div>
            <div style={detailRowStyle}>
              <span>Sandbox</span>
              <PixelBadge color="var(--text-dim)">Enabled</PixelBadge>
            </div>
          </div>
        </div>
      </PixelPanel>
    </div>
  )
}
