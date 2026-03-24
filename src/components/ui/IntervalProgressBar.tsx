import type { CSSProperties } from "react";

interface IntervalProgressBarProps {
  progress: number;
  color?: string;
}

const SEGMENT_COUNT = 10;
const SEGMENT_WIDTH = 4;
const SEGMENT_HEIGHT = 12;
const SEGMENT_GAP = 2;

const containerStyle: CSSProperties = {
  display: "flex",
  alignItems: "center",
  gap: `${SEGMENT_GAP}px`,
};

function segmentStyle(filled: boolean, color: string): CSSProperties {
  return {
    width: `${SEGMENT_WIDTH}px`,
    height: `${SEGMENT_HEIGHT}px`,
    borderRadius: "1px",
    background: filled ? color : "var(--bg-tertiary)",
    transition: "background 120ms ease",
  };
}

export function IntervalProgressBar({
  progress,
  color = "var(--accent)",
}: IntervalProgressBarProps) {
  const filledCount = Math.round(
    Math.max(0, Math.min(1, progress)) * SEGMENT_COUNT,
  );

  return (
    <div style={containerStyle}>
      {Array.from({ length: SEGMENT_COUNT }, (_, i) => (
        <div key={i} style={segmentStyle(i < filledCount, color)} />
      ))}
    </div>
  );
}
