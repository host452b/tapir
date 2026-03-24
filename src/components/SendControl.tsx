import { type CSSProperties, useEffect, useRef } from 'react'
import { useAppState } from '../hooks/useAppState'
import { tauriCommands } from '../hooks/useTauriCommand'
import {
  IntervalProgressBar,
  PixelButton,
  PixelPanel,
  RepeatModeStrip,
} from './ui'
import { EventLog } from './EventLog'

const containerStyle: CSSProperties = {
  display: 'flex',
  flexDirection: 'column',
  flex: 1,
  gap: 12,
}

const stateTextStyle = (state: string): CSSProperties => {
  let color = 'var(--text-dim)'
  if (state === 'running') color = 'var(--green)'
  else if (state === 'paused') color = 'var(--yellow)'

  return {
    fontFamily: 'var(--font-mono)',
    fontSize: 28,
    fontWeight: 900,
    color,
    textTransform: 'uppercase',
    letterSpacing: '2px',
    lineHeight: 1,
  }
}

const countStyle: CSSProperties = {
  fontFamily: 'var(--font-mono)',
  fontSize: 18,
  fontWeight: 700,
  color: 'var(--text-primary)',
  lineHeight: 1,
}

const countLabelStyle: CSSProperties = {
  fontFamily: 'var(--font-mono)',
  fontSize: 10,
  color: 'var(--text-dim)',
  letterSpacing: '0.5px',
}

const statsRowStyle: CSSProperties = {
  display: 'flex',
  alignItems: 'flex-end',
  gap: 20,
}

const buttonRowStyle: CSSProperties = {
  display: 'flex',
  gap: 8,
}

const warningStyle: CSSProperties = {
  fontFamily: 'var(--font-mono)',
  fontSize: 11,
  color: 'var(--orange)',
  fontWeight: 600,
}

const stateLabel = (state: string): string => {
  if (state === 'running') return 'TRANSMITTING'
  if (state === 'paused') return 'PAUSED'
  return 'IDLE'
}

export function SendControl() {
  const sendingState = useAppState((s) => s.sendingState)
  const setSendingState = useAppState((s) => s.setSendingState)
  const sendCount = useAppState((s) => s.sendCount)
  const setSendCount = useAppState((s) => s.setSendCount)
  const cyclesCompleted = useAppState((s) => s.cyclesCompleted)
  const setCyclesCompleted = useAppState((s) => s.setCyclesCompleted)
  const selectedWindows = useAppState((s) => s.selectedWindows)
  const keySteps = useAppState((s) => s.keySteps)
  const intervalMs = useAppState((s) => s.intervalMs)
  const repeatCount = useAppState((s) => s.repeatCount)
  const setRepeatCount = useAppState((s) => s.setRepeatCount)
  const showToast = useAppState((s) => s.showToast)
  const addLogEntry = useAppState((s) => s.addLogEntry)
  const progressRef = useRef(0)
  const intervalRef = useRef<ReturnType<typeof setInterval> | null>(null)

  // Poll sender status when running or paused
  useEffect(() => {
    if (sendingState === 'running' || sendingState === 'paused') {
      intervalRef.current = setInterval(async () => {
        try {
          const status = await tauriCommands.getSenderStatus()
          setSendCount(status.sendCount)
          setCyclesCompleted(status.cyclesCompleted)
          setSendingState(status.state)

          // Rough progress for visual feedback
          if (intervalMs > 0) {
            progressRef.current = (progressRef.current + 0.15) % 1
          }
        } catch {
          // Ignore poll errors silently
        }
      }, 200)
    } else {
      progressRef.current = 0
    }

    return () => {
      if (intervalRef.current) {
        clearInterval(intervalRef.current)
        intervalRef.current = null
      }
    }
  }, [sendingState, intervalMs, setSendCount, setCyclesCompleted, setSendingState])

  const hasNoTargets = selectedWindows.length === 0
  const hasNoSteps = keySteps.length === 0

  const handleStart = async () => {
    try {
      await tauriCommands.startSending(
        selectedWindows,
        keySteps,
        intervalMs,
        repeatCount ?? 0,
      )
      setSendingState('running')
      addLogEntry({
        id: crypto.randomUUID(),
        timestamp: new Date().toLocaleTimeString('en-GB'),
        entryType: 'SYS',
        message: `Started sending to ${selectedWindows.length} target(s)`,
      })
    } catch {
      showToast('Failed to start sending', 'var(--red)')
    }
  }

  const handlePause = async () => {
    try {
      await tauriCommands.pauseSending()
      setSendingState('paused')
    } catch {
      showToast('Failed to pause', 'var(--red)')
    }
  }

  const handleResume = async () => {
    try {
      await tauriCommands.resumeSending()
      setSendingState('running')
    } catch {
      showToast('Failed to resume', 'var(--red)')
    }
  }

  const handleStop = async () => {
    try {
      await tauriCommands.stopSending()
      setSendingState('idle')
      addLogEntry({
        id: crypto.randomUUID(),
        timestamp: new Date().toLocaleTimeString('en-GB'),
        entryType: 'SYS',
        message: 'Sending stopped',
      })
    } catch {
      showToast('Failed to stop', 'var(--red)')
    }
  }

  return (
    <div style={containerStyle}>
      <PixelPanel header="CONTROL" accent={sendingState === 'running' ? 'var(--green)' : 'var(--accent)'}>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
          {/* State + counts */}
          <span style={stateTextStyle(sendingState)}>{stateLabel(sendingState)}</span>
          <div style={statsRowStyle}>
            <div>
              <div style={countStyle}>{sendCount}</div>
              <div style={countLabelStyle}>SEND COUNT</div>
            </div>
            <div>
              <div style={countStyle}>{cyclesCompleted}</div>
              <div style={countLabelStyle}>CYCLES</div>
            </div>
            <IntervalProgressBar
              progress={sendingState === 'running' ? progressRef.current : 0}
              color={sendingState === 'running' ? 'var(--green)' : 'var(--accent)'}
            />
          </div>

          {/* Repeat config */}
          <RepeatModeStrip repeatCount={repeatCount} onChange={setRepeatCount} />

          {/* Preflight warnings */}
          {hasNoTargets && (
            <span style={warningStyle}>No targets selected - go to step 1</span>
          )}
          {hasNoSteps && (
            <span style={warningStyle}>No key steps configured - go to step 2</span>
          )}

          {/* Action buttons */}
          <div style={buttonRowStyle}>
            {sendingState === 'idle' && (
              <PixelButton
                variant="primary"
                onClick={handleStart}
                disabled={hasNoTargets || hasNoSteps}
              >
                START
              </PixelButton>
            )}
            {sendingState === 'running' && (
              <>
                <PixelButton onClick={handlePause}>PAUSE</PixelButton>
                <PixelButton variant="danger" onClick={handleStop}>STOP</PixelButton>
              </>
            )}
            {sendingState === 'paused' && (
              <>
                <PixelButton variant="primary" onClick={handleResume}>RESUME</PixelButton>
                <PixelButton variant="danger" onClick={handleStop}>STOP</PixelButton>
              </>
            )}
          </div>
        </div>
      </PixelPanel>

      <EventLog />
    </div>
  )
}
