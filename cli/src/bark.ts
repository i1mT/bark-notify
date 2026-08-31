import { Buffer } from "node:buffer";
import { CliError, type BarkPayload, type ResolvedConfig, type SendOptions } from "./types.js";

export interface PushResult {
  httpStatus: number;
  response: unknown;
}

export function makePayload(options: SendOptions, config: ResolvedConfig): BarkPayload {
  const body = options.message ?? options.markdown ?? "";
  const payload: BarkPayload = { device_key: config.deviceKey, body };
  assign(payload, "title", options.title);
  assign(payload, "subtitle", options.subtitle);
  assign(payload, "markdown", options.markdown);
  assign(payload, "level", options.level ?? config.level);
  assign(payload, "volume", options.volume);
  assign(payload, "badge", options.badge);
  assign(payload, "copy", options.copy);
  assign(payload, "sound", options.sound ?? config.sound);
  assign(payload, "icon", options.icon);
  assign(payload, "image", options.image);
  assign(payload, "group", options.group ?? config.group);
  assign(payload, "ttl", options.ttl);
  assign(payload, "url", options.url);
  assign(payload, "id", options.id);
  if (options.call) payload.call = "1";
  if (options.autoCopy) payload.autoCopy = "1";
  if (options.archive ?? config.archive) payload.isArchive = "1";
  if (options.noAction) payload.action = "none";
  return payload;
}

export async function push(payload: BarkPayload, config: ResolvedConfig): Promise<PushResult> {
  const response = await barkFetch(config, "push", {
    method: "POST",
    headers: { "Content-Type": "application/json; charset=utf-8" },
    body: JSON.stringify(payload),
  });
  const parsed = await parseResponse(response);
  const barkCode = responseObject(parsed)?.code;
  if (!response.ok || (typeof barkCode === "number" && barkCode !== 200)) {
    throw new BarkHttpError(response.status, responseMessage(parsed));
  }
  return { httpStatus: response.status, response: parsed };
}

export async function testConnection(config: ResolvedConfig): Promise<string[]> {
  const results: string[] = [];
  await expectSuccess(await barkFetch(config, "ping"));
  results.push("✓ Server reachable");
  try { await expectSuccess(await barkFetch(config, "info")); results.push("✓ Server info available"); }
  catch (error) { results.push(`! Server info unavailable: ${messageOf(error)}`); }
  try {
    await expectSuccess(await barkFetch(config, `register/${encodeURIComponent(config.deviceKey)}`, {}, false));
    results.push("✓ Device registered");
  } catch (error) { results.push(`! Device check unavailable: ${messageOf(error)}`); }
  return results;
}

export class BarkHttpError extends CliError {
  constructor(readonly status: number, message: string) {
    super(`Bark returned HTTP ${status}: ${message}`);
    this.name = "BarkHttpError";
  }
}

async function barkFetch(config: ResolvedConfig, path: string, init: RequestInit = {}, authenticated = true): Promise<Response> {
  const headers = new Headers(init.headers);
  headers.set("User-Agent", "barkdesk-notify/1.0");
  if (authenticated && config.username && config.password) {
    headers.set("Authorization", `Basic ${Buffer.from(`${config.username}:${config.password}`).toString("base64")}`);
  }
  try {
    return await fetch(`${config.server}/${path}`, { ...init, headers, signal: AbortSignal.timeout(20_000) });
  } catch (error) {
    throw new CliError(`Could not reach Bark Server: ${messageOf(error)}`);
  }
}

async function expectSuccess(response: Response): Promise<void> {
  if (!response.ok) throw new BarkHttpError(response.status, responseMessage(await parseResponse(response)));
}

async function parseResponse(response: Response): Promise<unknown> {
  const text = await response.text();
  if (!text) return {};
  try { return JSON.parse(text) as unknown; } catch { return text; }
}

function responseObject(value: unknown): Record<string, unknown> | undefined {
  return value !== null && typeof value === "object" && !Array.isArray(value) ? value as Record<string, unknown> : undefined;
}

function responseMessage(value: unknown): string {
  if (typeof value === "string") return value;
  const object = responseObject(value);
  return typeof object?.message === "string" ? object.message : "Unknown response";
}

function assign<K extends keyof BarkPayload>(target: BarkPayload, key: K, value: BarkPayload[K] | undefined): void {
  if (value !== undefined && value !== "") target[key] = value;
}

function messageOf(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}
