import { emitKeypressEvents } from "node:readline";
import type { DetectionResult } from "./model.js";

export async function selectAgents(items: DetectionResult[]): Promise<DetectionResult[]> {
  if (!process.stdin.isTTY || !process.stdout.isTTY || !process.stdin.setRawMode) {
    throw new Error("Interactive selection requires a terminal. Use --all or --agents codex,claude instead.");
  }
  let cursor = 0;
  const selected = new Set(items.map((_, index) => index));
  emitKeypressEvents(process.stdin);
  process.stdin.setRawMode(true);
  process.stdin.resume();
  process.stdout.write("Select coding agents (↑/↓ move, Space toggle, Enter confirm):\n");
  draw(items, selected, cursor, false);
  try {
    return await new Promise((resolve, reject) => {
      const keypress = (_text: string, key: { name?: string; ctrl?: boolean }): void => {
        if (key.ctrl && key.name === "c") { cleanup(); reject(new Error("Selection cancelled.")); return; }
        if (key.name === "up") cursor = (cursor - 1 + items.length) % items.length;
        else if (key.name === "down") cursor = (cursor + 1) % items.length;
        else if (key.name === "space") selected.has(cursor) ? selected.delete(cursor) : selected.add(cursor);
        else if (key.name === "return") {
          cleanup();
          resolve(items.filter((_, index) => selected.has(index)));
          return;
        } else return;
        draw(items, selected, cursor, true);
      };
      const cleanup = (): void => {
        process.stdin.off("keypress", keypress);
        process.stdin.setRawMode(false);
        process.stdin.pause();
        process.stdout.write("\n");
      };
      process.stdin.on("keypress", keypress);
    });
  } finally {
    if (process.stdin.isRaw) process.stdin.setRawMode(false);
  }
}

function draw(items: DetectionResult[], selected: Set<number>, cursor: number, redraw: boolean): void {
  if (redraw) process.stdout.write(`\x1b[${items.length}A`);
  items.forEach((item, index) => {
    const pointer = index === cursor ? "›" : " ";
    const check = selected.has(index) ? "◉" : "○";
    const configured = item.configured ? " · configured" : "";
    process.stdout.write(`\x1b[2K${pointer} ${check} ${item.definition.label}${configured}\n`);
  });
}
