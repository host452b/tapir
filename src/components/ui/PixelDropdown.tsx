import { type CSSProperties, useState } from "react";

interface PixelDropdownProps {
  value: string;
  onChange: (value: string) => void;
  options: string[];
  color?: string;
  disabled?: boolean;
}

const wrapperStyle: CSSProperties = {
  position: "relative",
  display: "inline-block",
};

function selectStyle(
  focused: boolean,
  color: string,
  disabled: boolean,
): CSSProperties {
  return {
    fontFamily: "var(--font-mono)",
    fontSize: "12px",
    color: "var(--text-primary)",
    background: "var(--bg-secondary)",
    border: focused ? `1px solid ${color}` : "1px solid var(--border)",
    borderRadius: "var(--radius-sm)",
    padding: "4px 22px 4px 6px",
    outline: "none",
    cursor: disabled ? "default" : "pointer",
    opacity: disabled ? 0.5 : 1,
    appearance: "none",
    width: "100%",
    transition: "border-color 120ms ease",
  };
}

const chevronStyle: CSSProperties = {
  position: "absolute",
  right: "6px",
  top: "50%",
  transform: "translateY(-50%)",
  pointerEvents: "none",
  fontSize: "10px",
  color: "var(--text-dim)",
  lineHeight: 1,
};

export function PixelDropdown({
  value,
  onChange,
  options,
  color = "var(--accent)",
  disabled = false,
}: PixelDropdownProps) {
  const [focused, setFocused] = useState(false);

  return (
    <div style={wrapperStyle}>
      <select
        style={selectStyle(focused, color, disabled)}
        value={value}
        onChange={(e) => onChange(e.target.value)}
        disabled={disabled}
        onFocus={() => setFocused(true)}
        onBlur={() => setFocused(false)}
      >
        {options.map((opt) => (
          <option key={opt} value={opt}>
            {opt}
          </option>
        ))}
      </select>
      <span style={chevronStyle}>{"\u25BE"}</span>
    </div>
  );
}
