import { useEffect } from 'react'
import { invoke } from '@tauri-apps/api/core'
import { listen } from '@tauri-apps/api/event'
import type {
  KeyStep,
  LogEntry,
  SenderStatus,
  SendingState,
  WindowInfo,
} from '../types/models'
import { useAppState } from './useAppState'

// ── Typed wrappers for all Tauri invoke calls ──────────────────────────

export const tauriCommands = {
  // Accessibility
  checkPermission: () => invoke<boolean>('check_permission'),
  requestPermission: () => invoke<boolean>('request_permission'),
  openSettings: () => invoke<void>('open_settings'),

  // Window scanning
  scanWindows: () => invoke<WindowInfo[]>('scan_windows'),
  validateWindows: (windows: Array<[number, number]>) =>
    invoke<number[]>('validate_windows', { windows }),

  // Sender control
  startSending: (
    targets: WindowInfo[],
    steps: KeyStep[],
    intervalMs: number,
    repeatCount: number,
  ) =>
    invoke<void>('start_sending', {
      targets,
      steps,
      intervalMs,
      repeatCount,
    }),
  pauseSending: () => invoke<void>('pause_sending'),
  resumeSending: () => invoke<void>('resume_sending'),
  stopSending: () => invoke<void>('stop_sending'),
  getSenderStatus: () => invoke<SenderStatus>('get_sender_status'),
} as const

// ── Event listener hook ────────────────────────────────────────────────

/**
 * Subscribe to Tauri backend events: log entries, state changes,
 * and target invalidation. Should be mounted once at the app root.
 */
export function useTauriEvents() {
  useEffect(() => {
    const unlisteners: Array<Promise<() => void>> = []

    // tapir://log — append to the event log
    unlisteners.push(
      listen<LogEntry>('tapir://log', (event) => {
        useAppState.getState().addLogEntry(event.payload)
      }),
    )

    // tapir://state-change — update sending state from backend
    unlisteners.push(
      listen<SendingState>('tapir://state-change', (event) => {
        const state = useAppState.getState()
        state.setSendingState(event.payload)

        // When returning to idle, sync counters
        if (event.payload === 'idle') {
          state.setSendCount(0)
          state.setCyclesCompleted(0)
        }
      }),
    )

    // tapir://targets-invalidated — remove dead PIDs from selection
    unlisteners.push(
      listen<number[]>('tapir://targets-invalidated', (event) => {
        const state = useAppState.getState()
        for (const pid of event.payload) {
          state.deselectByPid(pid)
        }
        state.showToast('Some targets are no longer available', 'var(--warning)')
      }),
    )

    return () => {
      for (const unlisten of unlisteners) {
        unlisten.then((fn) => fn())
      }
    }
  }, [])
}
