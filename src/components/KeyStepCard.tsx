import type { CSSProperties } from 'react'
import { useSortable } from '@dnd-kit/sortable'
import { CSS } from '@dnd-kit/utilities'
import { useAppState } from '../hooks/useAppState'
import { allKeyNames } from '../lib/keycodes'
import type { KeyStep, StepMode } from '../types/models'
import {
  PixelButton,
  PixelDropdown,
  PixelInput,
  PixelToggle,
  SegmentButton,
} from './ui'

const MODE_OPTIONS = [
  { value: 'key', label: 'KEY' },
  { value: 'text', label: 'TXT' },
  { value: 'combo', label: 'CMB' },
]

const modeColor: Record<StepMode, string> = {
  key: 'var(--cyan)',
  text: 'var(--green)',
  combo: 'var(--yellow)',
}

function cardStyle(mode: StepMode): CSSProperties {
  return {
    background: 'var(--bg-secondary)',
    border: '1px solid var(--border)',
    borderLeft: `3px solid ${modeColor[mode]}`,
    borderRadius: 'var(--radius-sm)',
    padding: '8px 10px',
    display: 'flex',
    flexDirection: 'column',
    gap: 8,
    transition: 'all 120ms ease',
  }
}

const configRowStyle: CSSProperties = {
  display: 'flex',
  alignItems: 'center',
  gap: 6,
  flexWrap: 'wrap',
}

const actionRowStyle: CSSProperties = {
  display: 'flex',
  alignItems: 'center',
  gap: 4,
  borderTop: '1px solid var(--border)',
  paddingTop: 6,
}

const keyNames = [...allKeyNames] as string[]

interface KeyStepCardProps {
  step: KeyStep
  index: number
  total: number
}

export function KeyStepCard({ step, index, total }: KeyStepCardProps) {
  const updateKeyStep = useAppState((s) => s.updateKeyStep)
  const removeKeyStep = useAppState((s) => s.removeKeyStep)
  const duplicateKeyStep = useAppState((s) => s.duplicateKeyStep)
  const reorderKeySteps = useAppState((s) => s.reorderKeySteps)
  const keySteps = useAppState((s) => s.keySteps)
  const editable = useAppState((s) => s.isEditable)()

  const {
    attributes,
    listeners,
    setNodeRef,
    transform,
    transition,
    isDragging,
  } = useSortable({ id: step.id })

  const style: CSSProperties = {
    ...cardStyle(step.mode),
    transform: CSS.Transform.toString(transform),
    transition,
    opacity: isDragging ? 0.6 : 1,
  }

  const update = (patch: Partial<KeyStep>) => updateKeyStep(step.id, patch)

  const moveUp = () => {
    if (index === 0) return
    const next = [...keySteps]
    const tmp = next[index - 1]
    next[index - 1] = next[index]
    next[index] = tmp
    reorderKeySteps(next)
  }

  const moveDown = () => {
    if (index === total - 1) return
    const next = [...keySteps]
    const tmp = next[index + 1]
    next[index + 1] = next[index]
    next[index] = tmp
    reorderKeySteps(next)
  }

  return (
    <div ref={setNodeRef} style={style} {...attributes}>
      <SegmentButton
        options={MODE_OPTIONS}
        value={step.mode}
        onChange={(v) => update({ mode: v as StepMode })}
        color={modeColor[step.mode]}
      />

      {step.mode === 'key' && (
        <div style={configRowStyle}>
          <div style={{ width: 100 }}>
            <PixelDropdown
              value={step.keyName}
              onChange={(v) => update({ keyName: v })}
              options={keyNames}
              disabled={!editable}
            />
          </div>
          <PixelToggle
            checked={step.withCommand}
            onChange={(v) => update({ withCommand: v })}
            label="Cmd"
            color="var(--cyan)"
            disabled={!editable}
          />
          <PixelToggle
            checked={step.withShift}
            onChange={(v) => update({ withShift: v })}
            label="Shift"
            color="var(--cyan)"
            disabled={!editable}
          />
          <PixelToggle
            checked={step.withOption}
            onChange={(v) => update({ withOption: v })}
            label="Opt"
            color="var(--cyan)"
            disabled={!editable}
          />
          <PixelToggle
            checked={step.withControl}
            onChange={(v) => update({ withControl: v })}
            label="Ctrl"
            color="var(--cyan)"
            disabled={!editable}
          />
        </div>
      )}

      {step.mode === 'text' && (
        <div style={configRowStyle}>
          <div style={{ flex: 1 }}>
            <PixelInput
              value={step.textContent}
              onChange={(v) => update({ textContent: v })}
              placeholder="Type text..."
              disabled={!editable}
            />
          </div>
          <PixelToggle
            checked={step.appendEnter}
            onChange={(v) => update({ appendEnter: v })}
            label="Enter"
            color="var(--green)"
            disabled={!editable}
          />
        </div>
      )}

      {step.mode === 'combo' && (
        <div style={configRowStyle}>
          <PixelToggle
            checked={step.hasPrefixKey}
            onChange={(v) => update({ hasPrefixKey: v })}
            label="Pre"
            color="var(--yellow)"
            disabled={!editable}
          />
          {step.hasPrefixKey && (
            <div style={{ width: 80 }}>
              <PixelDropdown
                value={step.prefixKeyName}
                onChange={(v) => update({ prefixKeyName: v })}
                options={keyNames}
                color="var(--yellow)"
                disabled={!editable}
              />
            </div>
          )}
          <div style={{ flex: 1 }}>
            <PixelInput
              value={step.textContent}
              onChange={(v) => update({ textContent: v })}
              placeholder="Text..."
              disabled={!editable}
            />
          </div>
          <PixelToggle
            checked={step.hasSuffixKey}
            onChange={(v) => update({ hasSuffixKey: v })}
            label="Suf"
            color="var(--yellow)"
            disabled={!editable}
          />
          {step.hasSuffixKey && (
            <div style={{ width: 80 }}>
              <PixelDropdown
                value={step.suffixKeyName}
                onChange={(v) => update({ suffixKeyName: v })}
                options={keyNames}
                color="var(--yellow)"
                disabled={!editable}
              />
            </div>
          )}
        </div>
      )}

      <div style={actionRowStyle}>
        <PixelButton compact disabled={!editable} onClick={undefined} {...listeners}>
          {'\u2261'}
        </PixelButton>
        <PixelButton compact disabled={!editable || index === 0} onClick={moveUp}>
          {'\u25B2'}
        </PixelButton>
        <PixelButton compact disabled={!editable || index === total - 1} onClick={moveDown}>
          {'\u25BC'}
        </PixelButton>
        <PixelButton compact disabled={!editable} onClick={() => duplicateKeyStep(step.id)}>
          {'\u2398'}
        </PixelButton>
        <div style={{ flex: 1 }} />
        <PixelButton compact variant="danger" disabled={!editable} onClick={() => removeKeyStep(step.id)}>
          {'\u00D7'}
        </PixelButton>
      </div>
    </div>
  )
}
