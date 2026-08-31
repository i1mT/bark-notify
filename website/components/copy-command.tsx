"use client";

import { Check, Copy, WarningCircle } from "@phosphor-icons/react";
import { useState } from "react";

type CopyState = "idle" | "copied" | "error";

export function CopyCommand({ command, compact = false }: { command: string; compact?: boolean }) {
  const [state, setState] = useState<CopyState>("idle");

  async function copy() {
    try {
      await navigator.clipboard.writeText(command);
      setState("copied");
      window.setTimeout(() => setState("idle"), 1800);
    } catch {
      setState("error");
    }
  }

  const label = state === "copied" ? "已复制" : state === "error" ? "复制失败" : "复制命令";
  const Icon = state === "copied" ? Check : state === "error" ? WarningCircle : Copy;

  return (
    <button className={`copy-button${compact ? " compact" : ""}`} type="button" onClick={copy} aria-live="polite">
      <Icon aria-hidden size={18} weight="bold" />
      <span>{label}</span>
    </button>
  );
}
