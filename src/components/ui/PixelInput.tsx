import { type CSSProperties, useState } from "react";

interface PixelInputProps {
  value: string;
  onChange: (value: string) => void;
  placeholder?: string;
  disabled?: boolean;
  type?: string;
}

function inputStyle(focused: boolean, disabled: boolean): CSSProperties {
  return {
    fontFamily: "var(--font-mono)",
    fontSize: "12px",
    color: "var(--text-primary)",
    background: "var(--bg-primary)",
    border: "none",
    borderBottom: focused
      ? "1px solid var(--accent)"
      : "1px solid var(--border)",
    borderRadius: 0,
    padding: "4px 6px",
    outline: "none",
    width: "100%",
    transition: "border-color 120ms ease",
    opacity: disabled ? 0.5 : 1,
    cursor: disabled ? "default" : "text",
  };
}

export function PixelInput({
  value,
  onChange,
  placeholder,
  disabled = false,
  type = "text",
}: PixelInputProps) {
  const [focused, setFocused] = useState(false);

  return (
    <input
      type={type}
      style={inputStyle(focused, disabled)}
      value={value}
      onChange={(e) => {
        if (!disabled) onChange(e.target.value);
      }}
      placeholder={placeholder}
      disabled={disabled}
      onFocus={() => setFocused(true)}
      onBlur={() => setFocused(false)}
    />
  );
}
