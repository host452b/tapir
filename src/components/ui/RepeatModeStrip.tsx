import { type CSSProperties, useCallback, useState } from "react";
import { PixelButton } from "./PixelButton";
import { PixelInput } from "./PixelInput";
import { SegmentButton } from "./SegmentButton";

interface RepeatModeStripProps {
  repeatCount: number | null;
  onChange: (value: number | null) => void;
}

const QUICK_PICKS = [1, 3, 5, 10, 50, 100];

const MODE_OPTIONS = [
  { value: "loop", label: "\u221E LOOP" },
  { value: "count", label: "N\u00D7" },
];

const containerStyle: CSSProperties = {
  display: "flex",
  flexDirection: "column",
  gap: "6px",
};

const rowStyle: CSSProperties = {
  display: "flex",
  alignItems: "center",
  gap: "4px",
  flexWrap: "wrap",
};

const customInputStyle: CSSProperties = {
  width: "48px",
};

export function RepeatModeStrip({
  repeatCount,
  onChange,
}: RepeatModeStripProps) {
  const mode = repeatCount === null ? "loop" : "count";
  const [customValue, setCustomValue] = useState("");

  const handleModeChange = useCallback(
    (newMode: string) => {
      if (newMode === "loop") {
        onChange(null);
      } else {
        onChange(1);
      }
    },
    [onChange],
  );

  const handleCustomChange = useCallback(
    (val: string) => {
      setCustomValue(val);
      const num = parseInt(val, 10);
      if (!isNaN(num) && num > 0) {
        onChange(num);
      }
    },
    [onChange],
  );

  return (
    <div style={containerStyle}>
      <SegmentButton
        options={MODE_OPTIONS}
        value={mode}
        onChange={handleModeChange}
      />
      {mode === "count" && (
        <div style={rowStyle}>
          {QUICK_PICKS.map((n) => (
            <PixelButton
              key={n}
              compact
              variant={repeatCount === n ? "primary" : "default"}
              onClick={() => onChange(n)}
            >
              {n}
            </PixelButton>
          ))}
          <div style={customInputStyle}>
            <PixelInput
              value={customValue}
              onChange={handleCustomChange}
              placeholder="#"
              type="number"
            />
          </div>
        </div>
      )}
    </div>
  );
}
