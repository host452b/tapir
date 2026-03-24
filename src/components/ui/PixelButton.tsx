import { type CSSProperties, type ReactNode, useState } from "react";

type Variant = "default" | "primary" | "danger";

interface PixelButtonProps {
  onClick?: () => void;
  variant?: Variant;
  disabled?: boolean;
  icon?: string;
  children?: ReactNode;
  compact?: boolean;
}

const baseStyle: CSSProperties = {
  display: "inline-flex",
  alignItems: "center",
  gap: "4px",
  fontFamily: "var(--font-mono)",
  fontSize: "12px",
  fontWeight: 600,
  border: "1px solid var(--border)",
  borderRadius: "var(--radius-sm)",
  cursor: "pointer",
  transition: "all 120ms ease",
  boxShadow: "var(--shadow-button)",
  lineHeight: 1,
  whiteSpace: "nowrap",
};

function variantStyles(variant: Variant): CSSProperties {
  switch (variant) {
    case "primary":
      return {
        background: "var(--accent)",
        color: "#fff",
        borderColor: "var(--accent)",
      };
    case "danger":
      return {
        background: "var(--red)",
        color: "#fff",
        borderColor: "var(--red)",
      };
    default:
      return {
        background: "var(--bg-tertiary)",
        color: "var(--text-primary)",
      };
  }
}

export function PixelButton({
  onClick,
  variant = "default",
  disabled = false,
  icon,
  children,
  compact = false,
}: PixelButtonProps) {
  const [pressed, setPressed] = useState(false);
  const [hovered, setHovered] = useState(false);

  const padding = compact ? "3px 6px" : "5px 10px";

  const dynamicStyle: CSSProperties = {
    ...baseStyle,
    ...variantStyles(variant),
    padding,
    opacity: disabled ? 0.5 : 1,
    cursor: disabled ? "default" : "pointer",
    transform: pressed
      ? "translateY(1px) scale(0.97)"
      : hovered && !disabled
        ? "translateY(-1px)"
        : "none",
    boxShadow:
      hovered && !disabled && !pressed
        ? "0 2px 4px rgba(16,15,15,0.16)"
        : "var(--shadow-button)",
  };

  return (
    <button
      type="button"
      style={dynamicStyle}
      disabled={disabled}
      onClick={disabled ? undefined : onClick}
      onMouseEnter={() => setHovered(true)}
      onMouseLeave={() => {
        setHovered(false);
        setPressed(false);
      }}
      onMouseDown={() => setPressed(true)}
      onMouseUp={() => setPressed(false)}
    >
      {icon && <span>{icon}</span>}
      {children}
    </button>
  );
}
