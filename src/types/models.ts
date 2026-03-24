// TypeScript types matching Rust serde output (camelCase fields, lowercase enums).

export type StepMode = 'key' | 'text' | 'combo'

export interface KeyStep {
  id: string
  mode: StepMode
  keyName: string
  withCommand: boolean
  withShift: boolean
  withOption: boolean
  withControl: boolean
  textContent: string
  appendEnter: boolean
  hasPrefixKey: boolean
  prefixKeyName: string
  hasSuffixKey: boolean
  suffixKeyName: string
}

export interface WindowInfo {
  id: number
  ownerName: string
  windowName: string
  pid: number
  parentPid: number
  parentWindowedPid: number
  isChildProcess: boolean
  childProcessCount: number
  subWindowCount: number
  isOnScreen: boolean
}

export interface LogEntry {
  id: string
  timestamp: string
  entryType: string
  message: string
}

export type SendingState = 'idle' | 'running' | 'paused'

export interface SenderStatus {
  state: SendingState
  sendCount: number
  cyclesCompleted: number
}

export type TapirError =
  | { type: 'noPermission' }
  | { type: 'eventCreationFailed'; message: string }
  | { type: 'invalidTarget'; pid: number }
  | { type: 'noStepsConfigured' }
  | { type: 'windowScanFailed'; message: string }
  | { type: 'sendFailed'; message: string }

export function createKeyStep(mode: StepMode = 'key'): KeyStep {
  return {
    id: crypto.randomUUID(),
    mode,
    keyName: 'Return',
    withCommand: false,
    withShift: false,
    withOption: false,
    withControl: false,
    textContent: '',
    appendEnter: true,
    hasPrefixKey: false,
    prefixKeyName: '',
    hasSuffixKey: true,
    suffixKeyName: 'Return',
  }
}
