import { create } from 'zustand'
import type {
  KeyStep,
  LogEntry,
  SendingState,
  WindowInfo,
} from '../types/models'
import { createKeyStep } from '../types/models'

// ── Toast ──────────────────────────────────────────────────────────────

interface Toast {
  message: string
  color: string
}

// ── Store shape ────────────────────────────────────────────────────────

interface AppState {
  // Workflow (0=System 1=Target 2=Keys 3=Control)
  currentStep: number
  setCurrentStep: (step: number) => void

  // Permission
  hasPermission: boolean
  setHasPermission: (v: boolean) => void

  // Windows
  scannedWindows: WindowInfo[]
  setScannedWindows: (w: WindowInfo[]) => void
  selectedWindows: WindowInfo[]
  toggleWindow: (w: WindowInfo) => void
  deselectWindow: (windowId: number) => void
  deselectByPid: (pid: number) => void
  clearSelection: () => void
  searchQuery: string
  setSearchQuery: (q: string) => void

  // Key steps
  keySteps: KeyStep[]
  addKeyStep: (step?: KeyStep) => void
  removeKeyStep: (id: string) => void
  updateKeyStep: (id: string, patch: Partial<KeyStep>) => void
  duplicateKeyStep: (id: string) => void
  reorderKeySteps: (steps: KeyStep[]) => void
  intervalMs: number
  setIntervalMs: (ms: number) => void

  // Sending
  sendingState: SendingState
  setSendingState: (s: SendingState) => void
  sendCount: number
  setSendCount: (n: number) => void
  cyclesCompleted: number
  setCyclesCompleted: (n: number) => void
  repeatCount: number | null // null = infinite
  setRepeatCount: (n: number | null) => void

  // Log
  logEntries: LogEntry[]
  addLogEntry: (entry: LogEntry) => void
  clearLog: () => void
  autoScroll: boolean
  setAutoScroll: (v: boolean) => void

  // Toast
  toast: Toast | null
  showToast: (message: string, color?: string) => void

  // Derived helpers (computed inline, not reactive selectors)
  canProceedToTarget: () => boolean
  canProceedToKeys: () => boolean
  canProceedToControl: () => boolean
  isEditable: () => boolean

  // Reset
  reset: () => void
}

const MAX_LOG_ENTRIES = 500

let toastTimer: ReturnType<typeof setTimeout> | null = null

export const useAppState = create<AppState>((set, get) => ({
  // ── Workflow ────────────────────────────────────────────────────────

  currentStep: 0,
  setCurrentStep: (step) => set({ currentStep: step }),

  // ── Permission ─────────────────────────────────────────────────────

  hasPermission: false,
  setHasPermission: (v) => set({ hasPermission: v }),

  // ── Windows ────────────────────────────────────────────────────────

  scannedWindows: [],
  setScannedWindows: (w) => set({ scannedWindows: w }),

  selectedWindows: [],
  toggleWindow: (w) =>
    set((s) => {
      const exists = s.selectedWindows.some((sw) => sw.id === w.id)
      return {
        selectedWindows: exists
          ? s.selectedWindows.filter((sw) => sw.id !== w.id)
          : [...s.selectedWindows, w],
      }
    }),
  deselectWindow: (windowId) =>
    set((s) => ({
      selectedWindows: s.selectedWindows.filter((sw) => sw.id !== windowId),
    })),
  deselectByPid: (pid) =>
    set((s) => ({
      selectedWindows: s.selectedWindows.filter((sw) => sw.pid !== pid),
    })),
  clearSelection: () => set({ selectedWindows: [] }),

  searchQuery: '',
  setSearchQuery: (q) => set({ searchQuery: q }),

  // ── Key steps ──────────────────────────────────────────────────────

  keySteps: [createKeyStep()],
  addKeyStep: (step) =>
    set((s) => ({
      keySteps: [...s.keySteps, step ?? createKeyStep()],
    })),
  removeKeyStep: (id) =>
    set((s) => ({
      keySteps: s.keySteps.filter((ks) => ks.id !== id),
    })),
  updateKeyStep: (id, patch) =>
    set((s) => ({
      keySteps: s.keySteps.map((ks) =>
        ks.id === id ? { ...ks, ...patch } : ks,
      ),
    })),
  duplicateKeyStep: (id) =>
    set((s) => {
      const idx = s.keySteps.findIndex((ks) => ks.id === id)
      if (idx === -1) return s
      const original = s.keySteps[idx]
      const duplicate: KeyStep = { ...original, id: crypto.randomUUID() }
      const next = [...s.keySteps]
      next.splice(idx + 1, 0, duplicate)
      return { keySteps: next }
    }),
  reorderKeySteps: (steps) => set({ keySteps: steps }),

  intervalMs: 2000,
  setIntervalMs: (ms) => set({ intervalMs: ms }),

  // ── Sending ────────────────────────────────────────────────────────

  sendingState: 'idle',
  setSendingState: (s) => set({ sendingState: s }),
  sendCount: 0,
  setSendCount: (n) => set({ sendCount: n }),
  cyclesCompleted: 0,
  setCyclesCompleted: (n) => set({ cyclesCompleted: n }),
  repeatCount: null,
  setRepeatCount: (n) => set({ repeatCount: n }),

  // ── Log ────────────────────────────────────────────────────────────

  logEntries: [],
  addLogEntry: (entry) =>
    set((s) => {
      const next = [...s.logEntries, entry]
      if (next.length > MAX_LOG_ENTRIES) {
        next.splice(0, next.length - MAX_LOG_ENTRIES)
      }
      return { logEntries: next }
    }),
  clearLog: () => set({ logEntries: [] }),
  autoScroll: true,
  setAutoScroll: (v) => set({ autoScroll: v }),

  // ── Toast ──────────────────────────────────────────────────────────

  toast: null,
  showToast: (message, color = 'var(--accent)') => {
    if (toastTimer) clearTimeout(toastTimer)
    set({ toast: { message, color } })
    toastTimer = setTimeout(() => {
      set({ toast: null })
      toastTimer = null
    }, 1800)
  },

  // ── Derived helpers ────────────────────────────────────────────────

  canProceedToTarget: () => get().hasPermission,
  canProceedToKeys: () => get().selectedWindows.length > 0,
  canProceedToControl: () => get().keySteps.length > 0,
  isEditable: () => get().sendingState === 'idle',

  // ── Reset ──────────────────────────────────────────────────────────

  reset: () => {
    if (toastTimer) {
      clearTimeout(toastTimer)
      toastTimer = null
    }
    set({
      currentStep: 0,
      hasPermission: false,
      scannedWindows: [],
      selectedWindows: [],
      searchQuery: '',
      keySteps: [createKeyStep()],
      intervalMs: 2000,
      sendingState: 'idle',
      sendCount: 0,
      cyclesCompleted: 0,
      repeatCount: null,
      logEntries: [],
      autoScroll: true,
      toast: null,
    })
  },
}))
