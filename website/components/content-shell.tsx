import type { ReactNode } from "react";

type ContentShellProps = {
  children: ReactNode;
  className?: string;
};

export function Reveal({ children, className }: ContentShellProps) {
  return <div className={className}>{children}</div>;
}

export function HeroEntrance({ children, className }: ContentShellProps) {
  return <div className={className}>{children}</div>;
}
