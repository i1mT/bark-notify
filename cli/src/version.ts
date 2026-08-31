import { readFileSync } from "node:fs";

const metadata = JSON.parse(
  readFileSync(new URL("../../package.json", import.meta.url), "utf8"),
) as { version?: unknown };

if (typeof metadata.version !== "string" || !metadata.version) {
  throw new Error("package.json does not contain a valid version");
}

export const packageVersion = metadata.version;
