import type { CSSProperties } from 'react'
import { useAppState } from '../hooks/useAppState'
import { PixelButton } from './ui'

const barStyle: CSSProperties = {
  display: 'flex',
  alignItems: 'center',
  justifyContent: 'space-between',
  paddingTop: 12,
  flexShrink: 0,
}

const leftStyle: CSSProperties = {
  display: 'flex',
  alignItems: 'center',
  gap: 8,
}

export function StepNavBar() {
  const currentStep = useAppState((s) => s.currentStep)
  const setCurrentStep = useAppState((s) => s.setCurrentStep)
  const hasPermission = useAppState((s) => s.hasPermission)
  const selectedCount = useAppState((s) => s.selectedWindows.length)
  const stepsCount = useAppState((s) => s.keySteps.length)
  const reset = useAppState((s) => s.reset)

  function canGoNext(): boolean {
    if (currentStep === 0) return hasPermission
    if (currentStep === 1) return selectedCount > 0
    if (currentStep === 2) return stepsCount > 0
    return false
  }

  return (
    <div style={barStyle}>
      <div style={leftStyle}>
        <PixelButton
          disabled={currentStep === 0}
          onClick={() => setCurrentStep(currentStep - 1)}
        >
          BACK
        </PixelButton>
        {currentStep < 3 && (
          <PixelButton
            variant="primary"
            disabled={!canGoNext()}
            onClick={() => setCurrentStep(currentStep + 1)}
          >
            NEXT
          </PixelButton>
        )}
      </div>
      <PixelButton variant="danger" onClick={reset}>
        RESET
      </PixelButton>
    </div>
  )
}
