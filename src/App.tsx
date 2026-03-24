import type { CSSProperties } from 'react'
import { useAppState } from './hooks/useAppState'
import { useTauriEvents } from './hooks/useTauriCommand'
import { TitleBar } from './components/TitleBar'
import { Sidebar } from './components/Sidebar'
import { StatusBar } from './components/StatusBar'
import { StepNavBar } from './components/StepNavBar'
import { SystemView } from './components/SystemView'
import { WindowSelector } from './components/WindowSelector'
import { KeyConfig } from './components/KeyConfig'
import { SendControl } from './components/SendControl'

const rootStyle: CSSProperties = {
  display: 'flex',
  flexDirection: 'column',
  height: '100vh',
}

const bodyStyle: CSSProperties = {
  display: 'flex',
  flex: 1,
  overflow: 'hidden',
}

const mainStyle: CSSProperties = {
  flex: 1,
  overflow: 'auto',
  padding: 16,
  display: 'flex',
  flexDirection: 'column',
}

const contentStyle: CSSProperties = {
  flex: 1,
  display: 'flex',
  flexDirection: 'column',
}

const toastStyle = (color: string): CSSProperties => ({
  position: 'fixed',
  bottom: 36,
  left: '50%',
  transform: 'translateX(-50%)',
  fontFamily: 'var(--font-mono)',
  fontSize: 11,
  fontWeight: 600,
  color: '#fff',
  background: color,
  padding: '6px 16px',
  borderRadius: 'var(--radius-sm)',
  boxShadow: '0 2px 8px rgba(0,0,0,0.2)',
  zIndex: 999,
  pointerEvents: 'none',
  whiteSpace: 'nowrap',
})

function StepView({ step }: { step: number }) {
  switch (step) {
    case 0:
      return <SystemView />
    case 1:
      return <WindowSelector />
    case 2:
      return <KeyConfig />
    case 3:
      return <SendControl />
    default:
      return null
  }
}

function App() {
  useTauriEvents()
  const currentStep = useAppState((s) => s.currentStep)
  const toast = useAppState((s) => s.toast)

  return (
    <div style={rootStyle}>
      <TitleBar />
      <div style={bodyStyle}>
        <Sidebar />
        <main style={mainStyle}>
          <div style={contentStyle}>
            <StepView step={currentStep} />
          </div>
          <StepNavBar />
        </main>
      </div>
      <StatusBar />
      {toast && <div style={toastStyle(toast.color)}>{toast.message}</div>}
    </div>
  )
}

export default App
