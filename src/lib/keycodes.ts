// Key name arrays for UI dropdowns.
// Names match the Rust key_codes::KEY_MAP keys exactly.

export const letterKeys = [
  'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J',
  'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T',
  'U', 'V', 'W', 'X', 'Y', 'Z',
] as const

export const numberKeys = [
  '0', '1', '2', '3', '4', '5', '6', '7', '8', '9',
] as const

export const symbolKeys = [
  '=', '-', ']', '[', "'", ';', '\\', ',', '/', '.', '`',
] as const

export const specialKeys = [
  'Return', 'Tab', 'Space', 'Delete', 'Escape', 'ForwardDelete',
] as const

export const functionKeys = [
  'F1', 'F2', 'F3', 'F4', 'F5', 'F6',
  'F7', 'F8', 'F9', 'F10', 'F11', 'F12',
] as const

export const arrowKeys = [
  'Left', 'Right', 'Down', 'Up',
] as const

export const navigationKeys = [
  'Home', 'End', 'PageUp', 'PageDown',
] as const

export const allKeyNames = [
  ...letterKeys,
  ...numberKeys,
  ...symbolKeys,
  ...specialKeys,
  ...functionKeys,
  ...arrowKeys,
  ...navigationKeys,
] as const

export type KeyName = (typeof allKeyNames)[number]
