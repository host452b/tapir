import { type CSSProperties, useState } from "react";

interface PixelToggleProps {
  checked: boolean;
  onChange: (checked: boolean) => void;
  label?: string;
  color?: string;
  disabled?: boolean;
}

const wrapperStyle: CSSProperties = {
  display: "inline-flex",
  alignItems: "center",
  gap: "6px",
  cursor: "pointer",
  fontFamily: "var(--font-mono)",
  fontSize: "12px",
  userSelect: "none",
};

function boxStyle(
  checked: boolean,
  color: string,
  pressed: boolean,
  disabled: boolean,
): CSSProperties {
  return {
    width: "14px",
    height: "14px",
    borderRadius: "2px",
    display: "flex",
    alignItems: "center",
    justifyContent: "center",
    fontSize: "10px",
    lineHeight: 1,
    fontWeight: 700,
    color: checked ? "#fff" : "transparent",
    background: checked ? color : "var(--bg-tertiary)",
    border: checked ? `1px solid ${color}` : "1px solid var(--border)",
    transition: "all 120ms ease",
    transform: pressed ? "scale(0.85)" : "none",
    cursor: disabled ? "default" : "pointer",
    opacity: disabled ? 0.5 : 1,
    flexShrink: 0,
  };
}

const labelStyle: CSSProperties = {
  color: "var(--text-primary)",
};

export function PixelToggle({
  checked,
  onChange,
  label,
  color = "var(--accent)",
  disabled = false,
}: PixelToggleProps) {
  const [pressed, setPressed] = useState(false);

  const handleClick = () => {
    if (!disabled) onChange(!checked);
  };

  return (
    <div
      style={{
        ...wrapperStyle,
        cursor: disabled ? "default" : "pointer",
        opacity: disabled ? 0.5 : 1,
      }}
      role="checkbox"
      aria-checked={checked}
      tabIndex={0}
      onClick={handleClick}
      onKeyDown={(e) => {
        if (e.key === " " || e.key === "Enter") {
          e.preventDefault();
          handleClick();
        }
      }}
      onMouseDown={() => setPressed(true)}
      onMouseUp={() => setPressed(false)}
      onMouseLeave={() => setPressed(false)}
    >
      <div style={boxStyle(checked, color, pressed, disabled)}>
        {checked ? "\u2713" : ""}
      </div>
      {label && <span style={labelStyle}>{label}</span>}
    </div>
  );
}
