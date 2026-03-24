import type { CSSProperties, ReactNode } from "react";

interface FlowLayoutProps {
  gap?: number;
  children: ReactNode;
}

export function FlowLayout({ gap = 4, children }: FlowLayoutProps) {
  const style: CSSProperties = {
    display: "flex",
    flexWrap: "wrap",
    gap: `${gap}px`,
  };

  return <div style={style}>{children}</div>;
}
