import { type CSSProperties, useState } from "react";

interface SegmentOption {
  value: string;
  label: string;
}

interface SegmentButtonProps {
  options: SegmentOption[];
  value: string;
  onChange: (value: string) => void;
  color?: string;
}

const containerStyle: CSSProperties = {
  display: "inline-flex",
  borderRadius: "var(--radius-sm)",
  overflow: "hidden",
  border: "1px solid var(--border)",
};

function segmentStyle(
  active: boolean,
  hovered: boolean,
  color: string,
): CSSProperties {
  let bg = "transparent";
  let borderColor = "transparent";

  if (active) {
    bg = `color-mix(in srgb, ${color} 12%, transparent)`;
    borderColor = `color-mix(in srgb, ${color} 50%, transparent)`;
  } else if (hovered) {
    bg = `color-mix(in srgb, ${color} 4%, transparent)`;
  }

  return {
    fontFamily: "var(--font-mono)",
    fontSize: "9px",
    fontWeight: 700,
    letterSpacing: "0.5px",
    textTransform: "uppercase",
    padding: "4px 8px",
    cursor: "pointer",
    background: bg,
    color: active ? color : "var(--text-secondary)",
    border: "none",
    borderRight: `1px solid ${active ? borderColor : "var(--border)"}`,
    outline: "none",
    transition: "all 120ms ease",
    lineHeight: 1,
    whiteSpace: "nowrap",
  };
}

function Segment({
  option,
  active,
  color,
  onClick,
  isLast,
}: {
  option: SegmentOption;
  active: boolean;
  color: string;
  onClick: () => void;
  isLast: boolean;
}) {
  const [hovered, setHovered] = useState(false);
  const style = segmentStyle(active, hovered, color);

  return (
    <button
      type="button"
      style={{
        ...style,
        borderRight: isLast ? "none" : style.borderRight,
      }}
      onClick={onClick}
      onMouseEnter={() => setHovered(true)}
      onMouseLeave={() => setHovered(false)}
    >
      {option.label}
    </button>
  );
}

export function SegmentButton({
  options,
  value,
  onChange,
  color = "var(--accent)",
}: SegmentButtonProps) {
  return (
    <div style={containerStyle}>
      {options.map((option, i) => (
        <Segment
          key={option.value}
          option={option}
          active={option.value === value}
          color={color}
          onClick={() => onChange(option.value)}
          isLast={i === options.length - 1}
        />
      ))}
    </div>
  );
}
