/// macOS virtual key code mapping.
library;
/// maps human-readable key names to macOS CGKeyCode values.
/// reference: /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/System/Library/Frameworks/Carbon.framework/Versions/A/Frameworks/HIToolbox.framework/Headers/Events.h

const Map<String, int> keyCodeMap = {
  // letter keys
  'A': 0,
  'S': 1,
  'D': 2,
  'F': 3,
  'H': 4,
  'G': 5,
  'Z': 6,
  'X': 7,
  'C': 8,
  'V': 9,
  'B': 11,
  'Q': 12,
  'W': 13,
  'E': 14,
  'R': 15,
  'Y': 16,
  'T': 17,
  'O': 31,
  'U': 32,
  'I': 34,
  'P': 35,
  'L': 37,
  'J': 38,
  'K': 40,
  'N': 45,
  'M': 46,

  // number keys
  '1': 18,
  '2': 19,
  '3': 20,
  '4': 21,
  '5': 23,
  '6': 22,
  '7': 26,
  '8': 28,
  '9': 25,
  '0': 29,

  // special keys
  'Return': 36,
  'Tab': 48,
  'Space': 49,
  'Delete': 51,
  'Escape': 53,
  'Forward Delete': 117,

  // symbol keys
  '=': 24,
  '-': 27,
  ']': 30,
  '[': 33,
  '\'': 39,
  ';': 41,
  '\\': 42,
  ',': 43,
  '/': 44,
  '.': 47,
  '`': 50,

  // function keys
  'F1': 122,
  'F2': 120,
  'F3': 99,
  'F4': 118,
  'F5': 96,
  'F6': 97,
  'F7': 98,
  'F8': 100,
  'F9': 101,
  'F10': 109,
  'F11': 103,
  'F12': 111,

  // arrow keys
  'Left': 123,
  'Right': 124,
  'Down': 125,
  'Up': 126,

  // navigation keys
  'Home': 115,
  'End': 119,
  'Page Up': 116,
  'Page Down': 121,
};

/// all available key names sorted into logical groups for the UI picker
const List<String> letterKeys = [
  'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M',
  'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z',
];

const List<String> numberKeys = [
  '0', '1', '2', '3', '4', '5', '6', '7', '8', '9',
];

const List<String> specialKeys = [
  'Return', 'Tab', 'Space', 'Delete', 'Escape', 'Forward Delete',
];

const List<String> functionKeys = [
  'F1', 'F2', 'F3', 'F4', 'F5', 'F6', 'F7', 'F8', 'F9', 'F10', 'F11', 'F12',
];

const List<String> arrowKeys = [
  'Left', 'Right', 'Up', 'Down',
];

const List<String> navigationKeys = [
  'Home', 'End', 'Page Up', 'Page Down',
];

/// all key names flattened into a single list (cached, not re-created per call)
final List<String> allKeyNames = [
  ...specialKeys,
  ...letterKeys,
  ...numberKeys,
  ...functionKeys,
  ...arrowKeys,
  ...navigationKeys,
];
