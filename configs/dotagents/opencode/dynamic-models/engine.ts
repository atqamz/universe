import { randomUUID } from "node:crypto";
import { chmod, mkdir, readFile, rename, unlink, writeFile } from "node:fs/promises";
import { homedir } from "node:os";
import { dirname, isAbsolute, join } from "node:path";

import { parseMocinCallableIds } from "./adapters/mocin.ts";
import { AdapterPayloadError, parseOpenAIModelIds } from "./adapters/openai.ts";

export const DEFAULT_TIMEOUT_MS = 8_000;
export const LKG_VERSION = 2;
export const SERVICE_ID = "dynamic-models";

export type ProviderModel = Record<string, unknown>;

export type ProviderConfig = {
  models?: Record<string, unknown>;
  options?: Record<string, unknown>;
  [key: string]: unknown;
};

export type OpenCodeConfig = {
  provider?: Record<string, ProviderConfig>;
  [key: string]: unknown;
};

export type DynamicProviderSpec = {
  id: string;
  discovery: {
    kind: "openai" | "mocin";
    endpoint?: string;
    timeoutMs?: number;
  };
  legacyStatePath?: string;
};

export type FileSystem = {
  chmod(path: string, mode: number): Promise<void>;
  mkdir(path: string): Promise<void>;
  readFile(path: string): Promise<string>;
  writeFile(path: string, data: string): Promise<void>;
  rename(from: string, to: string): Promise<void>;
  unlink(path: string): Promise<void>;
};

export type WarningEntry = {
  level: "warn";
  message: string;
  extra: { provider: string; category: string };
};

export type Logger = (entry: WarningEntry) => void | Promise<void>;

export type PluginOptions = {
  fetch?: typeof fetch;
  fileSystem?: Partial<FileSystem>;
  logger?: Logger;
  stateHome?: string;
  timeoutMs?: number;
};

export type OpenCodePluginInput = {
  client?: {
    app?: {
      log?: (options: { body: WarningEntry & { service: string } }) => Promise<unknown>;
    };
  };
};

type FailureCategory = "request" | "timeout" | "http" | "payload";

class DiscoveryError extends Error {
  constructor(readonly category: FailureCategory) {
    super(category);
  }
}

const nodeFileSystem: FileSystem = {
  chmod,
  mkdir: async (path) => {
    await mkdir(path, { mode: 0o700, recursive: true });
  },
  readFile: (path) => readFile(path, "utf8"),
  writeFile: async (path, data) => {
    await writeFile(path, data, { mode: 0o600 });
  },
  rename,
  unlink,
};

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function resolveStateHome(configured = process.env.XDG_STATE_HOME): string {
  return configured && isAbsolute(configured) ? configured : join(homedir(), ".local", "state");
}

function resolveTimeout(timeoutMs: number | undefined): number {
  return Number.isFinite(timeoutMs) && (timeoutMs ?? 0) > 0 ? timeoutMs! : DEFAULT_TIMEOUT_MS;
}

function providerStatePath(stateHome: string, providerId: string): string {
  return join(stateHome, "opencode", "dynamic-models", `${encodeURIComponent(providerId)}.json`);
}

function legacyStatePath(stateHome: string, spec: DynamicProviderSpec): string | undefined {
  return spec.legacyStatePath ? join(stateHome, spec.legacyStatePath) : undefined;
}

export function encodeSelectorId(callableId: string): string {
  return encodeURIComponent(callableId);
}

export function decodeSelectorId(selectorId: string): string {
  return decodeURIComponent(selectorId);
}

function runtimeModels(callableIds: string[], authoredModels: unknown): Record<string, ProviderModel> {
  const overrides = isRecord(authoredModels) ? authoredModels : {};
  return Object.fromEntries(callableIds.map((callableId) => {
    const authored = isRecord(overrides[callableId]) ? overrides[callableId] : {};
    return [encodeSelectorId(callableId), {
      ...authored,
      id: callableId,
      name: typeof authored.name === "string" ? authored.name : callableId,
    }];
  }));
}

function resolveOpenAIEndpoint(provider: ProviderConfig): string {
  const baseURL = provider.options?.baseURL;
  if (typeof baseURL !== "string" || baseURL.length === 0) throw new DiscoveryError("payload");

  try {
    const base = new URL(baseURL);
    base.hash = "";
    base.search = "";
    if (!base.pathname.endsWith("/")) base.pathname += "/";
    return new URL("models", base).href;
  } catch {
    throw new DiscoveryError("payload");
  }
}

function resolveEndpoint(spec: DynamicProviderSpec, provider: ProviderConfig): string {
  if (spec.discovery.kind === "mocin") {
    if (typeof spec.discovery.endpoint !== "string" || spec.discovery.endpoint.length === 0) {
      throw new DiscoveryError("payload");
    }
    return spec.discovery.endpoint;
  }
  return resolveOpenAIEndpoint(provider);
}

function parseCallableIds(spec: DynamicProviderSpec, value: unknown): string[] {
  try {
    return spec.discovery.kind === "mocin" ? parseMocinCallableIds(value) : parseOpenAIModelIds(value);
  } catch (error) {
    if (error instanceof AdapterPayloadError) throw new DiscoveryError("payload");
    throw error;
  }
}

async function discoverCallableIds(
  endpoint: string,
  spec: DynamicProviderSpec,
  fetcher: typeof fetch,
  timeoutMs: number,
): Promise<string[]> {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const response = await fetcher(endpoint, {
      headers: { Accept: "application/json" },
      signal: controller.signal,
    });
    if (!response.ok) throw new DiscoveryError("http");
    let value: unknown;
    try {
      value = await response.json();
    } catch {
      throw new DiscoveryError("payload");
    }
    return parseCallableIds(spec, value);
  } catch (error) {
    if (error instanceof DiscoveryError) throw error;
    throw new DiscoveryError(controller.signal.aborted ? "timeout" : "request");
  } finally {
    clearTimeout(timer);
  }
}

function isCallableId(value: unknown): value is string {
  return typeof value === "string" && value.length > 0 && value.trim() === value;
}

function validateLkg(value: unknown, spec: DynamicProviderSpec, endpoint: string): string[] {
  if (!isRecord(value) || value.version !== LKG_VERSION || value.provider !== spec.id || value.source !== endpoint || !Array.isArray(value.models)) {
    throw new Error("invalid");
  }
  const ids = value.models;
  if (!ids.every(isCallableId)) throw new Error("invalid");
  const uniqueIds = [...new Set(ids)];
  if (uniqueIds.length === 0) throw new Error("invalid");
  return uniqueIds;
}

type LkgResult =
  | { status: "valid"; callableIds: string[] }
  | { status: "missing" | "invalid" | "unreadable" | "legacy" };

async function readProviderLkg(
  fileSystem: FileSystem,
  path: string,
  oldPath: string | undefined,
  spec: DynamicProviderSpec,
  endpoint: string,
): Promise<LkgResult> {
  let contents: string;
  try {
    contents = await fileSystem.readFile(path);
  } catch (error) {
    if (!isRecord(error) || error.code !== "ENOENT") return { status: "unreadable" };
    if (!oldPath) return { status: "missing" };
    try {
      await fileSystem.readFile(oldPath);
      return { status: "legacy" };
    } catch (legacyError) {
      if (isRecord(legacyError) && legacyError.code === "ENOENT") return { status: "missing" };
      return { status: "unreadable" };
    }
  }

  try {
    return { status: "valid", callableIds: validateLkg(JSON.parse(contents), spec, endpoint) };
  } catch {
    return { status: "invalid" };
  }
}

async function persistProviderLkg(fileSystem: FileSystem, path: string, spec: DynamicProviderSpec, endpoint: string, callableIds: string[]): Promise<void> {
  const directory = dirname(path);
  await fileSystem.mkdir(directory);
  await fileSystem.chmod(directory, 0o700);
  const temporary = `${path}.tmp.${process.pid}.${randomUUID()}`;
  const contents = `${JSON.stringify({
    version: LKG_VERSION,
    provider: spec.id,
    source: endpoint,
    models: callableIds,
  })}\n`;
  try {
    await fileSystem.writeFile(temporary, contents);
    await fileSystem.rename(temporary, path);
  } catch (error) {
    try {
      await fileSystem.unlink(temporary);
    } catch {
      void 0;
    }
    throw error;
  }
}

async function emit(logger: Logger, provider: string, category: string, message: string): Promise<void> {
  try {
    await logger({ level: "warn", message, extra: { provider, category } });
  } catch {
    void 0;
  }
}

async function configureDynamicProvider(
  config: OpenCodeConfig,
  spec: DynamicProviderSpec,
  options: Required<Pick<PluginOptions, "fetch" | "fileSystem" | "logger" | "stateHome" | "timeoutMs">>,
): Promise<void> {
  const provider = config.provider?.[spec.id];
  if (!provider) return;

  const path = providerStatePath(options.stateHome, spec.id);
  let endpoint: string;
  try {
    endpoint = resolveEndpoint(spec, provider);
  } catch (error) {
    const category = error instanceof DiscoveryError ? error.category : "payload";
    provider.models = {};
    await emit(options.logger, spec.id, category, "dynamic provider configuration is invalid");
    return;
  }

  try {
    const callableIds = await discoverCallableIds(endpoint, spec, options.fetch, options.timeoutMs);
    provider.models = runtimeModels(callableIds, provider.models);
    try {
      await persistProviderLkg(options.fileSystem, path, spec, endpoint, callableIds);
    } catch {
      await emit(options.logger, spec.id, "lkg-write", "last-known-good inventory could not be persisted");
    }
    return;
  } catch (error) {
    const category = error instanceof DiscoveryError ? error.category : "request";
    const lkg = await readProviderLkg(options.fileSystem, path, legacyStatePath(options.stateHome, spec), spec, endpoint);
    if (lkg.status === "valid") {
      provider.models = runtimeModels(lkg.callableIds, provider.models);
      await emit(options.logger, spec.id, category, "remote model discovery failed; using last-known-good inventory");
      return;
    }

    provider.models = {};
    if (lkg.status === "legacy") {
      await emit(options.logger, spec.id, "lkg-legacy", "legacy model inventory is incompatible and was ignored");
    } else if (lkg.status === "invalid") {
      await emit(options.logger, spec.id, "lkg-invalid", "last-known-good inventory was invalid and was ignored");
    } else if (lkg.status === "unreadable") {
      await emit(options.logger, spec.id, "lkg-read", "last-known-good inventory could not be read");
    } else {
      await emit(options.logger, spec.id, "lkg-missing", "last-known-good inventory was not found");
    }
    await emit(options.logger, spec.id, category, "remote model discovery failed and no compatible inventory is available");
  }
}

export function createDynamicProviderPlugin(spec: DynamicProviderSpec, options: PluginOptions = {}) {
  const resolved: Required<Pick<PluginOptions, "fetch" | "fileSystem" | "logger" | "stateHome" | "timeoutMs">> = {
    fetch: options.fetch ?? ((input, init) => fetch(input, init)),
    fileSystem: { ...nodeFileSystem, ...options.fileSystem },
    logger: options.logger ?? (() => {}),
    stateHome: resolveStateHome(options.stateHome),
    timeoutMs: resolveTimeout(options.timeoutMs ?? spec.discovery.timeoutMs),
  };
  return {
    config: (config: OpenCodeConfig) => configureDynamicProvider(config, spec, resolved),
  };
}

export function createOpenCodeDynamicProviderPlugin(spec: DynamicProviderSpec, input: OpenCodePluginInput = {}) {
  const appLog = input.client?.app?.log;
  const logger: Logger = async ({ level, message, extra }) => {
    if (appLog) {
      try {
        await appLog({ body: { service: SERVICE_ID, level, message, extra } });
        return;
      } catch {
        void 0;
      }
    }
    console.warn(`[${SERVICE_ID}] provider=${extra.provider} category=${extra.category} ${message}`);
  };
  return createDynamicProviderPlugin(spec, { logger });
}
