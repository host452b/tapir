// Flexoki Light palette as TypeScript constants.
// Source: https://stephango.com/flexoki

export const flexoki = {
  bg: {
    primary: '#FFFCF0',
    secondary: '#F2F0E5',
    tertiary: '#E6E4D9',
    active: '#DAD8CE',
  },
  text: {
    primary: '#100F0F',
    secondary: '#6F6E69',
    dim: '#878580',
    muted: '#B7B5AC',
  },
  border: {
    default: '#E6E4D9',
    light: '#F2F0E5',
  },
  red: '#AF3029',
  redLight: '#D14D41',
  orange: '#BC5215',
  orangeLight: '#DA702C',
  yellow: '#AD8301',
  yellowLight: '#D0A215',
  green: '#66800B',
  greenLight: '#879A39',
  cyan: '#24837B',
  cyanLight: '#3AA99F',
  blue: '#205EA6',
  blueLight: '#4385BE',
  purple: '#5E409D',
  purpleLight: '#8B7EC8',
  magenta: '#A02F6F',
  magentaLight: '#CE5D97',
} as const

// Semantic aliases
export const semantic = {
  accent: flexoki.cyan,
  success: flexoki.green,
  warning: flexoki.orange,
  error: flexoki.red,
  info: flexoki.blue,
} as const
