import type { CSSProperties, ReactNode } from "react";

interface PixelBadgeProps {
  color?: string;
  children: ReactNode;
}

function badgeStyle(color: string): CSSProperties {
  return {
    display: "inline-block",
    fontFamily: "var(--font-mono)",
    fontSize: "9px",
    fontWeight: 700,
    letterSpacing: "0.5px",
    lineHeight: 1,
    padding: "3px 7px",
    borderRadius: "10px",
    background: `color-mix(in srgb, ${color} 8%, transparent)`,
    border: `1px solid color-mix(in srgb, ${color} 35%, transparent)`,
    color,
    whiteSpace: "nowrap",
  };
}

export function PixelBadge({
  color = "var(--accent)",
  children,
}: PixelBadgeProps) {
  return <span style={badgeStyle(color)}>{children}</span>;
}
