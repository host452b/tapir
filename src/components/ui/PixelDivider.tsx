import type { CSSProperties } from "react";

interface PixelDividerProps {
  label?: string;
}

const wrapperStyle: CSSProperties = {
  display: "flex",
  alignItems: "center",
  gap: "8px",
  width: "100%",
};

const lineStyle: CSSProperties = {
  flex: 1,
  height: "1px",
  background: "var(--border)",
};

const labelStyle: CSSProperties = {
  fontFamily: "var(--font-mono)",
  fontSize: "9px",
  fontWeight: 700,
  letterSpacing: "1px",
  textTransform: "uppercase",
  color: "var(--text-dim)",
  whiteSpace: "nowrap",
};

export function PixelDivider({ label }: PixelDividerProps) {
  if (!label) {
    return <div style={lineStyle} />;
  }

  return (
    <div style={wrapperStyle}>
      <div style={lineStyle} />
      <span style={labelStyle}>{label}</span>
      <div style={lineStyle} />
    </div>
  );
}
