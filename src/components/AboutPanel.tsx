import type { CSSProperties } from 'react'
import { PixelButton, PixelDivider, PixelPanel } from './ui'

const overlayStyle: CSSProperties = {
  position: 'fixed',
  inset: 0,
  background: 'rgba(16, 15, 15, 0.3)',
  display: 'flex',
  alignItems: 'center',
  justifyContent: 'center',
  zIndex: 200,
}

const panelStyle: CSSProperties = {
  width: 360,
  maxWidth: '90vw',
}

const headerStyle: CSSProperties = {
  textAlign: 'center' as const,
  padding: '20px 0 12px',
}

const appNameStyle: CSSProperties = {
  fontFamily: 'var(--font-mono)',
  fontSize: 32,
  fontWeight: 900,
  color: 'var(--text-primary)',
  letterSpacing: 2,
}

const versionStyle: CSSProperties = {
  fontFamily: 'var(--font-mono)',
  fontSize: 12,
  color: 'var(--text-dim)',
  marginTop: 4,
}

const descStyle: CSSProperties = {
  fontFamily: 'var(--font-mono)',
  fontSize: 11,
  color: 'var(--text-secondary)',
  lineHeight: 1.6,
  textAlign: 'center' as const,
  padding: '12px 16px',
}

const infoRowStyle: CSSProperties = {
  display: 'flex',
  justifyContent: 'space-between',
  fontFamily: 'var(--font-mono)',
  fontSize: 10,
  padding: '4px 16px',
}

const labelStyle: CSSProperties = {
  color: 'var(--text-dim)',
  textTransform: 'uppercase' as const,
  letterSpacing: 0.5,
}

const valueStyle: CSSProperties = {
  color: 'var(--text-primary)',
}

const footerStyle: CSSProperties = {
  display: 'flex',
  justifyContent: 'center',
  padding: '12px 0 4px',
}

interface Props {
  onClose: () => void
}

export function AboutPanel({ onClose }: Props) {
  return (
    <div style={overlayStyle} onClick={onClose}>
      <div style={panelStyle} onClick={(e) => e.stopPropagation()}>
        <PixelPanel accent="var(--cyan)">
          <div style={headerStyle}>
            <div style={appNameStyle}>TAPIR</div>
            <div style={versionStyle}>Version 2.0.0</div>
          </div>

          <div style={descStyle}>
            macOS keyboard automation tool.
            <br />
            Send automated key events to any target application.
          </div>

          <PixelDivider />

          <div style={{ padding: '8px 0' }}>
            <div style={infoRowStyle}>
              <span style={labelStyle}>Engine</span>
              <span style={valueStyle}>Tauri v2 + Rust</span>
            </div>
            <div style={infoRowStyle}>
              <span style={labelStyle}>Frontend</span>
              <span style={valueStyle}>React + TypeScript</span>
            </div>
            <div style={infoRowStyle}>
              <span style={labelStyle}>Platform</span>
              <span style={valueStyle}>macOS 14.0+</span>
            </div>
            <div style={infoRowStyle}>
              <span style={labelStyle}>Sandbox</span>
              <span style={valueStyle}>Enabled</span>
            </div>
            <div style={infoRowStyle}>
              <span style={labelStyle}>Method</span>
              <span style={valueStyle}>CGEvent → HID</span>
            </div>
            <div style={infoRowStyle}>
              <span style={labelStyle}>Theme</span>
              <span style={valueStyle}>Flexoki Light</span>
            </div>
          </div>

          <PixelDivider />

          <div style={footerStyle}>
            <PixelButton onClick={onClose}>CLOSE</PixelButton>
          </div>
        </PixelPanel>
      </div>
    </div>
  )
}
