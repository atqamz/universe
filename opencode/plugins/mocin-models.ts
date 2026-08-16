import { randomUUID } from "node:crypto";
import { chmod, mkdir, readFile, rename, unlink, writeFile } from "node:fs/promises";
import { homedir } from "node:os";
import { dirname, isAbsolute, join } from "node:path";

const DISCOVERY_ENDPOINT = "https://beta.masven.dev/webapi/models";
const SERVICE_ID = "mocin-models";
const LKG_VERSION = 1;
const DEFAULT_TIMEOUT_MS = 8_000;

export type OpenCodeConfig = {
  provider?: Record<string, {
    models?: Record<string, unknown>;
    [key: string]: unknown;
  }>;
};

export type FileSystem = {
  chmod(path: string, mode: number): Promise<void>;
  mkdir(path: string): Promise<void>;
  readFile(path: string): Promise<string>;
  writeFile(path: string, data: string): Promise<void>;
  rename(from: string, to: string): Promise<void>;
  unlink(path: string): Promise<void>;
};

type Logger = (entry: {
  level: "warn";
  message: string;
  extra?: Record<string, unknown>;
}) => void | Promise<void>;

type PluginOptions = {
  fetch?: typeof fetch;
  fileSystem?: FileSystem;
  logger?: Logger;
  stateHome?: string;
  timeoutMs?: number;
};

type PluginInput = {
  client?: {
    app?: {
      log?: (options: {
        body: {
          service: string;
          level: "warn";
          message: string;
          extra?: Record<string, unknown>;
        };
      }) => Promise<unknown>;
    };
  };
};

class DiscoveryError extends Error {
  constructor(public readonly category: "request" | "payload" | "http") {
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

function isModelId(value: unknown): value is string {
  return typeof value === "string" && value.length > 0 && value.trim() === value;
}

function uniqueModelIds(ids: string[]): string[] {
  return [...new Set(ids)];
}

function invalidPayload(): never {
  throw new DiscoveryError("payload");
}

function extractModelIds(value: unknown): string[] {
  if (!isRecord(value) || !Array.isArray(value.models)) {
    return invalidPayload();
  }

  const availability = new Map<string, boolean>();
  for (const item of value.models) {
    if (!isRecord(item) || typeof item.active !== "boolean") {
      return invalidPayload();
    }
    if (item.active && !isModelId(item.model)) return invalidPayload();
    if (isModelId(item.model)) {
      const previous = availability.get(item.model);
      if (previous !== undefined && previous !== item.active) return invalidPayload();
      availability.set(item.model, item.active);
    }
  }

  const ids = uniqueModelIds([...availability].filter(([, active]) => active).map(([id]) => id));
  if (ids.length === 0) return invalidPayload();
  return ids;
}

function validateLkg(value: unknown): string[] {
  if (
    !isRecord(value) ||
    value.version !== LKG_VERSION ||
    value.provider !== "mocin" ||
    value.endpoint !== DISCOVERY_ENDPOINT ||
    !Array.isArray(value.models)
  ) {
    return invalidPayload();
  }

  const ids = value.models;
  if (!ids.every(isModelId)) return invalidPayload();
  const uniqueIds = uniqueModelIds(ids);
  if (uniqueIds.length === 0) return invalidPayload();
  return uniqueIds;
}

function stateHome(configured = process.env.XDG_STATE_HOME): string {
  return configured && isAbsolute(configured) ? configured : join(homedir(), ".local", "state");
}

function lkgPath(home = stateHome()): string {
  return join(home, "opencode", "mocin-models.json");
}

function runtimeModels(ids: string[], overrides: Record<string, unknown>): Record<string, unknown> {
  return Object.fromEntries(ids.map((id) => [id, Object.hasOwn(overrides, id) ? overrides[id] : {}]));
}

async function fetchModelIds(fetcher: typeof fetch, timeoutMs: number): Promise<string[]> {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const response = await fetcher(DISCOVERY_ENDPOINT, {
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
    return extractModelIds(value);
  } catch (error) {
    if (error instanceof DiscoveryError) throw error;
    throw new DiscoveryError("request");
  } finally {
    clearTimeout(timer);
  }
}

type LkgReadResult =
  | { status: "valid"; ids: string[] }
  | { status: "missing" | "invalid" | "unreadable" };

async function readLkg(fileSystem: FileSystem, path: string): Promise<LkgReadResult> {
  let contents: string;
  try {
    contents = await fileSystem.readFile(path);
  } catch (error) {
    if (isRecord(error) && error.code === "ENOENT") return { status: "missing" };
    return { status: "unreadable" };
  }

  try {
    return { status: "valid", ids: validateLkg(JSON.parse(contents)) };
  } catch {
    return { status: "invalid" };
  }
}

async function persistLkg(fileSystem: FileSystem, path: string, ids: string[]): Promise<void> {
  const directory = dirname(path);
  await fileSystem.mkdir(directory);
  await fileSystem.chmod(directory, 0o700);
  const temporary = `${path}.tmp.${process.pid}.${randomUUID()}`;
  const contents = `${JSON.stringify({
    version: LKG_VERSION,
    provider: "mocin",
    endpoint: DISCOVERY_ENDPOINT,
    models: ids,
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

async function configureMocin(config: OpenCodeConfig, options: Required<Pick<PluginOptions, "fetch" | "fileSystem" | "logger" | "stateHome" | "timeoutMs">>): Promise<void> {
  const provider = config.provider?.mocin;
  if (!provider) return;

  const overrides = isRecord(provider.models) ? provider.models : {};
  const path = lkgPath(options.stateHome);
  try {
    const ids = await fetchModelIds(options.fetch, options.timeoutMs);
    provider.models = runtimeModels(ids, overrides);
    try {
      await persistLkg(options.fileSystem, path, ids);
    } catch {
      await options.logger({
        level: "warn",
        message: "last-known-good inventory could not be persisted",
        extra: { category: "lkg-write" },
      });
    }
    return;
  } catch (error) {
    const category = error instanceof DiscoveryError ? error.category : "request";
    const lkg = await readLkg(options.fileSystem, path);
    if (lkg.status === "valid") {
      provider.models = runtimeModels(lkg.ids, overrides);
      await options.logger({
        level: "warn",
        message: category === "payload" ? "remote model inventory was rejected; using last-known-good inventory" : "Mocin model discovery failed; using last-known-good inventory",
        extra: { category },
      });
      return;
    }

    if (lkg.status === "invalid") {
      await options.logger({
        level: "warn",
        message: "last-known-good inventory was invalid; ignoring it",
        extra: { category: "lkg-invalid" },
      });
    } else if (lkg.status === "unreadable") {
      await options.logger({
        level: "warn",
        message: "last-known-good inventory could not be read",
        extra: { category: "lkg-read" },
      });
    } else if (lkg.status === "missing") {
      await options.logger({
        level: "warn",
        message: "last-known-good inventory was not found",
        extra: { category: "lkg-missing" },
      });
    }

    provider.models = {};
    await options.logger({
      level: "warn",
      message: category === "payload" ? "remote model inventory was rejected; no valid last-known-good inventory is available" : "Mocin model discovery failed and no valid last-known-good inventory is available",
      extra: { category },
    });
  }
}

function createMocinPlugin(options: PluginOptions = {}) {
  const resolved: Required<Pick<PluginOptions, "fetch" | "fileSystem" | "logger" | "stateHome" | "timeoutMs">> = {
    fetch: options.fetch ?? ((input, init) => fetch(input, init)),
    fileSystem: options.fileSystem ?? nodeFileSystem,
    logger: options.logger ?? (() => {}),
    stateHome: stateHome(options.stateHome),
    timeoutMs: Number.isFinite(options.timeoutMs) && (options.timeoutMs ?? 0) > 0 ? options.timeoutMs! : DEFAULT_TIMEOUT_MS,
  };
  return {
    config: (config: OpenCodeConfig) => configureMocin(config, resolved),
  };
}

async function MocinModelsPlugin(input: PluginInput = {}) {
  const log: Logger = async ({ message, extra }) => {
    const appLog = input.client?.app?.log;
    if (appLog) {
      try {
        await appLog({ body: { service: SERVICE_ID, level: "warn", message, extra } });
        return;
      } catch {
        void 0;
      }
    }
    console.warn(`[${SERVICE_ID}] ${message}`);
  };
  return createMocinPlugin({ logger: log });
}

const plugin = Object.assign(MocinModelsPlugin, {
  DISCOVERY_ENDPOINT,
  createMocinPlugin,
  extractModelIds,
  lkgPath,
});

export default plugin;
