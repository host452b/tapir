import { type CSSProperties, useEffect, useRef } from 'react'
import { useAppState } from '../hooks/useAppState'
import { PixelBadge, PixelButton, PixelToggle } from './ui'

const containerStyle: CSSProperties = {
  display: 'flex',
  flexDirection: 'column',
  border: '1px solid var(--border)',
  borderRadius: 'var(--radius-sm)',
  background: 'var(--bg-secondary)',
  overflow: 'hidden',
}

const headerStyle: CSSProperties = {
  display: 'flex',
  alignItems: 'center',
  gap: 8,
  padding: '6px 10px',
  borderBottom: '1px solid var(--border)',
  fontFamily: 'var(--font-mono)',
  fontSize: 10,
  fontWeight: 700,
  letterSpacing: '1px',
  color: 'var(--text-secondary)',
}

const scrollAreaStyle: CSSProperties = {
  maxHeight: 200,
  overflowY: 'auto',
  padding: '4px 0',
}

const entryStyle: CSSProperties = {
  display: 'flex',
  alignItems: 'flex-start',
  gap: 6,
  padding: '2px 10px',
  fontFamily: 'var(--font-mono)',
  fontSize: 10,
  lineHeight: 1.5,
}

const timestampStyle: CSSProperties = {
  color: 'var(--text-dim)',
  flexShrink: 0,
}

const messageStyle: CSSProperties = {
  color: 'var(--text-primary)',
  wordBreak: 'break-word',
}

const emptyStyle: CSSProperties = {
  fontFamily: 'var(--font-mono)',
  fontSize: 10,
  color: 'var(--text-dim)',
  textAlign: 'center',
  padding: 16,
}

const TAG_COLORS: Record<string, string> = {
  KEY: 'var(--cyan)',
  SYS: 'var(--green)',
  ERR: 'var(--red)',
  WRN: 'var(--orange)',
}

function tagColor(entryType: string): string {
  return TAG_COLORS[entryType.toUpperCase()] ?? 'var(--text-dim)'
}

export function EventLog() {
  const logEntries = useAppState((s) => s.logEntries)
  const clearLog = useAppState((s) => s.clearLog)
  const autoScroll = useAppState((s) => s.autoScroll)
  const setAutoScroll = useAppState((s) => s.setAutoScroll)
  const scrollRef = useRef<HTMLDivElement>(null)

  useEffect(() => {
    if (autoScroll && scrollRef.current) {
      scrollRef.current.scrollTop = scrollRef.current.scrollHeight
    }
  }, [logEntries, autoScroll])

  return (
    <div style={containerStyle}>
      <div style={headerStyle}>
        <span>EVENT LOG</span>
        <div style={{ flex: 1 }} />
        <PixelToggle
          checked={autoScroll}
          onChange={setAutoScroll}
          label="Auto"
          color="var(--accent)"
        />
        <PixelButton compact onClick={clearLog}>
          CLEAR
        </PixelButton>
      </div>
      <div style={scrollAreaStyle} ref={scrollRef}>
        {logEntries.length === 0 && (
          <div style={emptyStyle}>(no events)</div>
        )}
        {logEntries.map((entry) => (
          <div key={entry.id} style={entryStyle}>
            <span style={timestampStyle}>{entry.timestamp}</span>
            <PixelBadge color={tagColor(entry.entryType)}>
              {entry.entryType.toUpperCase()}
            </PixelBadge>
            <span style={messageStyle}>{entry.message}</span>
          </div>
        ))}
      </div>
    </div>
  )
}
