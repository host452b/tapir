import type { CSSProperties, ReactNode } from "react";

interface PixelPanelProps {
  header?: string;
  accent?: string;
  children: ReactNode;
}

const panelStyle: CSSProperties = {
  background: "var(--bg-secondary)",
  border: "1px solid var(--border)",
  borderRadius: "var(--radius-md)",
  boxShadow: "var(--shadow-panel)",
  overflow: "hidden",
};

const headerStyle = (accent: string): CSSProperties => ({
  borderTop: `2px solid ${accent}`,
  padding: "6px 10px",
  fontSize: "10px",
  fontFamily: "var(--font-mono)",
  fontWeight: 700,
  letterSpacing: "2px",
  textTransform: "uppercase",
  color: "var(--text-secondary)",
});

const bodyStyle: CSSProperties = {
  padding: "10px",
};

export function PixelPanel({
  header,
  accent = "var(--cyan)",
  children,
}: PixelPanelProps) {
  return (
    <div style={panelStyle}>
      {header && <div style={headerStyle(accent)}>{header}</div>}
      <div style={bodyStyle}>{children}</div>
    </div>
  );
}
