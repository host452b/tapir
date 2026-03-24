import { type CSSProperties, useMemo, useState } from 'react'
import { useAppState } from '../hooks/useAppState'
import { tauriCommands } from '../hooks/useTauriCommand'
import type { WindowInfo } from '../types/models'
import { PixelBadge, PixelButton, PixelInput, PixelPanel } from './ui'

const topRowStyle: CSSProperties = {
  display: 'flex',
  alignItems: 'center',
  gap: 8,
  marginBottom: 8,
  flexWrap: 'wrap',
}

const searchWrapperStyle: CSSProperties = {
  flex: 1,
  minWidth: 120,
}

const listStyle: CSSProperties = {
  display: 'flex',
  flexDirection: 'column',
  gap: 0,
  maxHeight: 'calc(100vh - 260px)',
  overflowY: 'auto',
}

const selectedStripStyle: CSSProperties = {
  display: 'flex',
  flexWrap: 'wrap',
  alignItems: 'center',
  gap: 6,
  padding: '8px 0',
  marginBottom: 8,
  borderBottom: '1px solid var(--border)',
}

const selectedChipStyle: CSSProperties = {
  display: 'inline-flex',
  alignItems: 'center',
  gap: 4,
  padding: '2px 8px',
  background: 'rgba(36, 131, 123, 0.08)',
  border: '1px solid rgba(36, 131, 123, 0.3)',
  borderRadius: 10,
  fontFamily: 'var(--font-mono)',
  fontSize: 10,
  color: 'var(--text-primary)',
}

const chipRemoveStyle: CSSProperties = {
  cursor: 'pointer',
  color: 'var(--text-dim)',
  fontWeight: 700,
  fontSize: 10,
  lineHeight: 1,
  padding: '0 2px',
  borderRadius: 2,
  transition: 'color 120ms ease',
}

const emptyStyle: CSSProperties = {
  fontFamily: 'var(--font-mono)',
  fontSize: 11,
  color: 'var(--text-dim)',
  padding: 24,
  textAlign: 'center',
}

function rowStyle(selected: boolean, hovered: boolean): CSSProperties {
  let bg = 'transparent'
  if (selected) bg = 'rgba(36, 131, 123, 0.04)'
  else if (hovered) bg = 'var(--bg-active)'

  return {
    display: 'flex',
    alignItems: 'center',
    gap: 8,
    padding: '6px 10px',
    cursor: 'pointer',
    borderLeft: selected ? '3px solid var(--accent)' : '3px solid transparent',
    background: bg,
    transition: 'all 120ms ease',
    fontFamily: 'var(--font-mono)',
    fontSize: 12,
  }
}

const ownerStyle: CSSProperties = {
  fontWeight: 700,
  color: 'var(--text-primary)',
  whiteSpace: 'nowrap',
  overflow: 'hidden',
  textOverflow: 'ellipsis',
  maxWidth: 140,
}

const windowNameStyle: CSSProperties = {
  color: 'var(--text-secondary)',
  flex: 1,
  whiteSpace: 'nowrap',
  overflow: 'hidden',
  textOverflow: 'ellipsis',
}

const rightInfoStyle: CSSProperties = {
  display: 'flex',
  alignItems: 'center',
  gap: 4,
  flexShrink: 0,
}

function WindowRow({
  window,
  selected,
  onToggle,
}: {
  window: WindowInfo
  selected: boolean
  onToggle: () => void
}) {
  const [hovered, setHovered] = useState(false)

  return (
    <div
      style={rowStyle(selected, hovered)}
      onClick={onToggle}
      onMouseEnter={() => setHovered(true)}
      onMouseLeave={() => setHovered(false)}
    >
      <span style={ownerStyle}>{window.ownerName}</span>
      <span style={windowNameStyle}>{window.windowName || '(untitled)'}</span>
      <div style={rightInfoStyle}>
        <PixelBadge color="var(--text-dim)">PID {window.pid}</PixelBadge>
        {window.isOnScreen && (
          <PixelBadge color="var(--green)">ON</PixelBadge>
        )}
      </div>
    </div>
  )
}

export function WindowSelector() {
  const scannedWindows = useAppState((s) => s.scannedWindows)
  const setScannedWindows = useAppState((s) => s.setScannedWindows)
  const selectedWindows = useAppState((s) => s.selectedWindows)
  const toggleWindow = useAppState((s) => s.toggleWindow)
  const clearSelection = useAppState((s) => s.clearSelection)
  const searchQuery = useAppState((s) => s.searchQuery)
  const setSearchQuery = useAppState((s) => s.setSearchQuery)
  const showToast = useAppState((s) => s.showToast)
  const [scanning, setScanning] = useState(false)
  const [hasScanned, setHasScanned] = useState(false)

  const handleScan = async () => {
    setScanning(true)
    try {
      const windows = await tauriCommands.scanWindows()
      setScannedWindows(windows)
      setHasScanned(true)
      showToast(`Found ${windows.length} window(s)`, 'var(--accent)')
    } catch {
      showToast('Failed to scan windows', 'var(--red)')
    } finally {
      setScanning(false)
    }
  }

  const filtered = useMemo(() => {
    if (!searchQuery.trim()) return scannedWindows
    const q = searchQuery.toLowerCase()
    return scannedWindows.filter(
      (w) =>
        w.ownerName.toLowerCase().includes(q) ||
        w.windowName.toLowerCase().includes(q),
    )
  }, [scannedWindows, searchQuery])

  const selectedIds = useMemo(
    () => new Set(selectedWindows.map((w) => w.id)),
    [selectedWindows],
  )

  const deselectWindow = useAppState((s) => s.deselectWindow)

  return (
    <div style={{ display: 'flex', flexDirection: 'column', flex: 1 }}>
      <div style={topRowStyle}>
        <PixelButton variant="primary" onClick={handleScan} disabled={scanning}>
          {scanning ? 'SCANNING...' : 'SCAN'}
        </PixelButton>
        <div style={searchWrapperStyle}>
          <PixelInput
            value={searchQuery}
            onChange={setSearchQuery}
            placeholder="Search windows..."
          />
        </div>
        <PixelBadge color="var(--accent)">{selectedWindows.length} selected</PixelBadge>
        {selectedWindows.length > 0 && (
          <PixelButton variant="danger" compact onClick={clearSelection}>
            CLEAR ALL
          </PixelButton>
        )}
      </div>

      {/* Selected targets strip */}
      {selectedWindows.length > 0 && (
        <div style={selectedStripStyle}>
          <span style={{ fontSize: 9, fontWeight: 700, letterSpacing: 1, color: 'var(--text-dim)', textTransform: 'uppercase' as const }}>
            Targets:
          </span>
          {selectedWindows.map((w) => (
            <div key={w.id} style={selectedChipStyle}>
              <span style={{ maxWidth: 120, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' as const }}>
                {w.ownerName}
                {w.windowName ? ` — ${w.windowName}` : ''}
              </span>
              <span
                style={chipRemoveStyle}
                onClick={(e) => { e.stopPropagation(); deselectWindow(w.id) }}
                title="Remove target"
              >
                x
              </span>
            </div>
          ))}
        </div>
      )}

      <PixelPanel header="WINDOWS" accent="var(--cyan)">
        <div style={listStyle}>
          {filtered.length === 0 && (
            <div style={emptyStyle}>
              {hasScanned ? '(no windows found)' : 'Press SCAN to discover windows'}
            </div>
          )}
          {filtered.map((w) => (
            <WindowRow
              key={w.id}
              window={w}
              selected={selectedIds.has(w.id)}
              onToggle={() => toggleWindow(w)}
            />
          ))}
        </div>
      </PixelPanel>
    </div>
  )
}
