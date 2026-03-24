import type { CSSProperties } from 'react'
import { useAppState } from '../hooks/useAppState'

const STEPS = [
  { label: 'SYSTEM', index: 0 },
  { label: 'TARGET', index: 1 },
  { label: 'KEYS', index: 2 },
  { label: 'CONTROL', index: 3 },
] as const

const sidebarStyle: CSSProperties = {
  width: 120,
  flexShrink: 0,
  background: 'var(--bg-secondary)',
  borderRight: '1px solid var(--border)',
  display: 'flex',
  flexDirection: 'column',
  justifyContent: 'space-between',
  paddingTop: 16,
  paddingBottom: 12,
}

const stepsContainerStyle: CSSProperties = {
  display: 'flex',
  flexDirection: 'column',
  gap: 8,
  padding: '0 12px',
}

const sendingIndicatorStyle: CSSProperties = {
  display: 'flex',
  alignItems: 'center',
  gap: 6,
  padding: '0 12px',
  fontFamily: 'var(--font-mono)',
  fontSize: 10,
  fontWeight: 600,
}

function circleStyle(state: 'active' | 'completed' | 'disabled'): CSSProperties {
  let bg = 'var(--bg-tertiary)'
  let border = '1px solid var(--border)'
  let color = 'var(--text-muted)'

  if (state === 'active') {
    bg = 'var(--accent)'
    border = '1px solid var(--accent)'
    color = '#fff'
  } else if (state === 'completed') {
    bg = 'var(--bg-active)'
    border = '1px solid var(--text-muted)'
    color = 'var(--text-secondary)'
  }

  return {
    width: 24,
    height: 24,
    borderRadius: '50%',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    fontFamily: 'var(--font-mono)',
    fontSize: 11,
    fontWeight: 700,
    background: bg,
    border,
    color,
    flexShrink: 0,
    transition: 'all 120ms ease',
  }
}

function labelStyle(state: 'active' | 'completed' | 'disabled'): CSSProperties {
  return {
    fontFamily: 'var(--font-mono)',
    fontSize: 9,
    fontWeight: state === 'active' ? 700 : 500,
    letterSpacing: '0.5px',
    color: state === 'disabled' ? 'var(--text-muted)' : 'var(--text-secondary)',
    transition: 'all 120ms ease',
  }
}

function stepRowStyle(clickable: boolean): CSSProperties {
  return {
    display: 'flex',
    alignItems: 'center',
    gap: 8,
    cursor: clickable ? 'pointer' : 'default',
    padding: '4px 0',
  }
}

export function Sidebar() {
  const currentStep = useAppState((s) => s.currentStep)
  const setCurrentStep = useAppState((s) => s.setCurrentStep)
  const hasPermission = useAppState((s) => s.hasPermission)
  const hasTargets = useAppState((s) => s.selectedWindows.length > 0)
  const hasSteps = useAppState((s) => s.keySteps.length > 0)
  const sendingState = useAppState((s) => s.sendingState)

  function canNavigateTo(step: number): boolean {
    if (step <= currentStep) return true
    if (step === 1) return hasPermission
    if (step === 2) return hasPermission && hasTargets
    if (step === 3) return hasPermission && hasTargets && hasSteps
    return false
  }

  function handleClick(step: number) {
    if (canNavigateTo(step)) {
      setCurrentStep(step)
    }
  }

  function getState(step: number): 'active' | 'completed' | 'disabled' {
    if (step === currentStep) return 'active'
    if (step < currentStep) return 'completed'
    if (canNavigateTo(step)) return 'completed'
    return 'disabled'
  }

  const sendingColor =
    sendingState === 'running'
      ? 'var(--green)'
      : sendingState === 'paused'
        ? 'var(--yellow)'
        : 'transparent'

  return (
    <div style={sidebarStyle}>
      <div style={stepsContainerStyle}>
        {STEPS.map((s) => {
          const state = getState(s.index)
          const clickable = canNavigateTo(s.index)
          return (
            <div
              key={s.index}
              style={stepRowStyle(clickable)}
              onClick={() => handleClick(s.index)}
            >
              <div style={circleStyle(state)}>{s.index}</div>
              <span style={labelStyle(state)}>{s.label}</span>
            </div>
          )
        })}
      </div>
      {sendingState !== 'idle' && (
        <div style={sendingIndicatorStyle}>
          <span
            style={{
              width: 8,
              height: 8,
              borderRadius: '50%',
              background: sendingColor,
              display: 'inline-block',
              flexShrink: 0,
            }}
          />
          <span style={{ color: sendingColor, textTransform: 'uppercase' }}>
            {sendingState}
          </span>
        </div>
      )}
    </div>
  )
}
