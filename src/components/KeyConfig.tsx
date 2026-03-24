import type { CSSProperties } from 'react'
import {
  DndContext,
  closestCenter,
  PointerSensor,
  useSensor,
  useSensors,
  type DragEndEvent,
} from '@dnd-kit/core'
import {
  SortableContext,
  verticalListSortingStrategy,
  arrayMove,
} from '@dnd-kit/sortable'
import { useAppState } from '../hooks/useAppState'
import { createKeyStep } from '../types/models'
import { FlowLayout, PixelBadge, PixelButton, PixelInput } from './ui'
import { KeyStepCard } from './KeyStepCard'

const topRowStyle: CSSProperties = {
  display: 'flex',
  alignItems: 'center',
  gap: 8,
  marginBottom: 8,
  flexWrap: 'wrap',
}

const intervalRowStyle: CSSProperties = {
  display: 'flex',
  alignItems: 'center',
  gap: 6,
  fontFamily: 'var(--font-mono)',
  fontSize: 12,
  color: 'var(--text-secondary)',
}

const intervalInputStyle: CSSProperties = {
  width: 64,
}

const listStyle: CSSProperties = {
  display: 'flex',
  flexDirection: 'column',
  gap: 6,
  marginTop: 8,
  flex: 1,
  overflowY: 'auto',
}

const emptyStyle: CSSProperties = {
  fontFamily: 'var(--font-mono)',
  fontSize: 11,
  color: 'var(--text-dim)',
  textAlign: 'center',
  padding: 24,
}

const modeColor: Record<string, string> = {
  key: 'var(--cyan)',
  text: 'var(--green)',
  combo: 'var(--yellow)',
}

function chipStyle(mode: string): CSSProperties {
  const color = modeColor[mode] ?? 'var(--text-dim)'
  return {
    fontFamily: 'var(--font-mono)',
    fontSize: 9,
    fontWeight: 700,
    padding: '2px 5px',
    borderRadius: 3,
    background: `color-mix(in srgb, ${color} 12%, transparent)`,
    color,
    border: `1px solid color-mix(in srgb, ${color} 30%, transparent)`,
    lineHeight: 1,
  }
}

function stepLabel(step: { mode: string; keyName: string; textContent: string }): string {
  if (step.mode === 'key') return step.keyName
  if (step.mode === 'text') return step.textContent.slice(0, 12) || '(empty)'
  return step.textContent.slice(0, 8) || 'combo'
}

export function KeyConfig() {
  const keySteps = useAppState((s) => s.keySteps)
  const addKeyStep = useAppState((s) => s.addKeyStep)
  const reorderKeySteps = useAppState((s) => s.reorderKeySteps)
  const intervalMs = useAppState((s) => s.intervalMs)
  const setIntervalMs = useAppState((s) => s.setIntervalMs)
  const editable = useAppState((s) => s.isEditable)()

  const sensors = useSensors(
    useSensor(PointerSensor, { activationConstraint: { distance: 5 } }),
  )

  const handleDragEnd = (event: DragEndEvent) => {
    const { active, over } = event
    if (!over || active.id === over.id) return
    const oldIndex = keySteps.findIndex((s) => s.id === active.id)
    const newIndex = keySteps.findIndex((s) => s.id === over.id)
    if (oldIndex !== -1 && newIndex !== -1) {
      reorderKeySteps(arrayMove(keySteps, oldIndex, newIndex))
    }
  }

  const handleIntervalChange = (val: string) => {
    const num = parseInt(val, 10)
    if (!isNaN(num) && num >= 0) {
      setIntervalMs(num)
    }
  }

  return (
    <div style={{ display: 'flex', flexDirection: 'column', flex: 1 }}>
      {/* Sequence preview */}
      {keySteps.length > 0 && (
        <FlowLayout gap={4}>
          {keySteps.map((s) => (
            <span key={s.id} style={chipStyle(s.mode)}>
              {stepLabel(s)}
            </span>
          ))}
        </FlowLayout>
      )}

      <div style={topRowStyle}>
        <div style={intervalRowStyle}>
          <span>Interval:</span>
          <div style={intervalInputStyle}>
            <PixelInput
              value={String(intervalMs)}
              onChange={handleIntervalChange}
              type="number"
              disabled={!editable}
            />
          </div>
          <span>ms</span>
        </div>
        <div style={{ flex: 1 }} />
        <PixelBadge color="var(--accent)">{keySteps.length} step(s)</PixelBadge>
      </div>

      {/* Add buttons */}
      <div style={{ display: 'flex', gap: 6, marginBottom: 6 }}>
        <PixelButton
          compact
          disabled={!editable}
          onClick={() => addKeyStep(createKeyStep('key'))}
        >
          <span style={{ color: 'var(--cyan)' }}>+</span> KEY
        </PixelButton>
        <PixelButton
          compact
          disabled={!editable}
          onClick={() => addKeyStep(createKeyStep('text'))}
        >
          <span style={{ color: 'var(--green)' }}>+</span> TEXT
        </PixelButton>
        <PixelButton
          compact
          disabled={!editable}
          onClick={() => addKeyStep(createKeyStep('combo'))}
        >
          <span style={{ color: 'var(--yellow)' }}>+</span> COMBO
        </PixelButton>
      </div>

      {/* Step list */}
      <DndContext
        sensors={sensors}
        collisionDetection={closestCenter}
        onDragEnd={handleDragEnd}
      >
        <SortableContext
          items={keySteps.map((s) => s.id)}
          strategy={verticalListSortingStrategy}
        >
          <div style={listStyle}>
            {keySteps.length === 0 && (
              <div style={emptyStyle}>Add key steps using the buttons above</div>
            )}
            {keySteps.map((step, i) => (
              <KeyStepCard key={step.id} step={step} index={i} total={keySteps.length} />
            ))}
          </div>
        </SortableContext>
      </DndContext>
    </div>
  )
}
