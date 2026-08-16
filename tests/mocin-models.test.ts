import { chmod, mkdtemp, readFile, readdir, rm, stat, writeFile } from "node:fs/promises";
import { homedir, tmpdir } from "node:os";
import { join } from "node:path";

import { afterEach, describe, expect, test } from "bun:test";

import mocinModelsPlugin, {
  type FileSystem,
  type OpenCodeConfig,
} from "../opencode/plugins/mocin-models.ts";

const { DISCOVERY_ENDPOINT, createMocinPlugin } = mocinModelsPlugin;

const stateHomes: string[] = [];

afterEach(async () => {
  await Promise.all(stateHomes.splice(0).map((stateHome) => rm(stateHome, { force: true, recursive: true })));
});

function entry(model: unknown, active = true): Record<string, unknown> {
  return { model, active };
}

function payload(entries: Record<string, unknown>[]): { models: Record<string, unknown>[] } {
  return { models: entries };
}

function response(body: unknown, status = 200): Response {
  return new Response(typeof body === "string" ? body : JSON.stringify(body), {
    headers: { "content-type": "application/json" },
    status,
  });
}

async function stateHome(): Promise<string> {
  const path = await mkdtemp(join(tmpdir(), "mocin-models-test-"));
  stateHomes.push(path);
  return path;
}

async function run(
  models: Record<string, unknown> = {},
  options: Parameters<typeof createMocinPlugin>[0] = {},
): Promise<{
  config: OpenCodeConfig;
  warnings: string[];
  warningEntries: Array<{ message: string; extra?: Record<string, unknown> }>;
}> {
  const warnings: string[] = [];
  const warningEntries: Array<{ message: string; extra?: Record<string, unknown> }> = [];
  const config: OpenCodeConfig = {
    provider: {
      other: { models: { untouched: { name: "Other" } } },
      mocin: { models },
    },
  };
  const plugin = createMocinPlugin({
    logger: (entry) => {
      warnings.push(entry.message);
      warningEntries.push(entry);
    },
    ...options,
  });
  await plugin.config(config);
  return { config, warnings, warningEntries };
}

function fetchOnce(body: unknown, status = 200, capture?: (init: RequestInit | undefined) => void): typeof fetch {
  return async (_input, init) => {
    capture?.(init);
    return response(body, status);
  };
}

function fsWith(overrides: Partial<FileSystem>): FileSystem {
  return {
    chmod: async (path, mode) => chmod(path, mode),
    mkdir: async (path) => {
      await import("node:fs/promises").then(({ mkdir }) => mkdir(path, { mode: 0o700, recursive: true }));
    },
    readFile: async (path) => readFile(path, "utf8"),
    rename: async (from, to) => import("node:fs/promises").then(({ rename }) => rename(from, to)),
    unlink: async (path) => import("node:fs/promises").then(({ unlink }) => unlink(path)),
    writeFile: async (path, data) => writeFile(path, data, { mode: 0o600 }),
    ...overrides,
  };
}

describe("Mocin discovery", () => {
  test("populates all active model IDs and preserves unrelated providers", async () => {
    const home = await stateHome();
    const { config } = await run({}, {
      fetch: fetchOnce(payload([entry("A"), entry("B"), entry("disabled", false)])),
      stateHome: home,
    });

    expect(Object.keys(config.provider?.mocin?.models ?? {})).toEqual(["A", "B"]);
    expect(config.provider?.other?.models).toEqual({ untouched: { name: "Other" } });
  });

  test("deduplicates IDs and rejects malformed entries", async () => {
    const home = await stateHome();
    const { config } = await run({}, {
      fetch: fetchOnce(payload([entry("A"), entry("A")])),
      stateHome: home,
    });
    expect(Object.keys(config.provider?.mocin?.models ?? {})).toEqual(["A"]);

    const malformed = await run({}, {
      fetch: fetchOnce(payload([entry(" ")])),
      stateHome: await stateHome(),
    });
    expect(malformed.config.provider?.mocin?.models).toEqual({});
    expect(malformed.warnings).toContain("remote model inventory was rejected; no valid last-known-good inventory is available");

    const nonString = await run({}, {
      fetch: fetchOnce(payload([entry(123)])),
      stateHome: await stateHome(),
    });
    expect(nonString.config.provider?.mocin?.models).toEqual({});
  });

  test("uses only active model IDs from the availability contract", async () => {
    const responses = [
      { models: [{ model: "A", active: true }] },
      {
        total: 99,
        models: [{ model: "A", active: true, provider: null, upstream: 123, multiplier: "changed", extra: true }],
      },
      {
        models: [
          { active: false, provider: null, upstream: 123, multiplier: "invalid" },
          { model: "A", active: true },
        ],
      },
    ];

    for (const body of responses) {
      const result = await run({}, { fetch: fetchOnce(body), stateHome: await stateHome() });
      expect(Object.keys(result.config.provider?.mocin?.models ?? {})).toEqual(["A"]);
    }
  });

  test("rejects ambiguous availability data without mutating model IDs", async () => {
    const invalidResponses: unknown[] = [
      null,
      {},
      { models: "A" },
      { models: ["A"] },
      { models: [{}] },
      { models: [{ model: "A" }] },
      { models: [{ model: "A", active: "yes" }] },
      { models: [{ active: true }] },
      { models: [{ model: 123, active: true }] },
      { models: [{ model: "", active: true }] },
      { models: [{ model: " ", active: true }] },
      { models: [{ model: " A", active: true }] },
      { models: [{ model: "A ", active: true }] },
      { models: [{ active: false }] },
      { models: [{ model: "A", active: true }, { model: "A", active: false }] },
      { models: [{ model: "A", active: false }, { model: "A", active: true }] },
    ];

    for (const body of invalidResponses) {
      const result = await run({}, { fetch: fetchOnce(body), stateHome: await stateHome() });
      expect(result.config.provider?.mocin?.models).toEqual({});
      expect(result.warnings).toContain("remote model inventory was rejected; no valid last-known-good inventory is available");
    }
  });

  test("rejects an empty active inventory", async () => {
    const home = await stateHome();
    const result = await run({}, {
      fetch: fetchOnce(payload([entry("disabled", false)])),
      stateHome: home,
    });

    expect(result.config.provider?.mocin?.models).toEqual({});
    expect(result.warnings).toContain("remote model inventory was rejected; no valid last-known-good inventory is available");
  });

  test("does not fetch when the provider is absent", async () => {
    let calls = 0;
    const plugin = createMocinPlugin({
      fetch: async () => {
        calls += 1;
        return response(payload([entry("A")]));
      },
    });

    await plugin.config({ provider: { other: { models: {} } } });
    expect(calls).toBe(0);
  });

  test("falls back to the home-local state directory for a relative override", async () => {
    const paths: string[] = [];
    const result = await run({}, {
      fetch: fetchOnce(payload([entry("A")])),
      stateHome: "relative-state",
      fileSystem: fsWith({
        chmod: async (path) => paths.push(path),
        mkdir: async (path) => paths.push(path),
        writeFile: async (path) => paths.push(path),
        rename: async (from, to) => paths.push(from, to),
        unlink: async (path) => paths.push(path),
      }),
    });

    expect(Object.keys(result.config.provider?.mocin?.models ?? {})).toEqual(["A"]);
    expect(paths).toHaveLength(5);
    expect(paths.every((path) => path.startsWith(join(homedir(), ".local", "state")))).toBe(true);
  });

  test("uses the exact discovery request without copying credentials", async () => {
    const home = await stateHome();
    let request: RequestInit | undefined;
    await run({}, {
      fetch: fetchOnce(payload([entry("A")]), 200, (init) => {
        request = init;
      }),
      stateHome: home,
    });

    expect(request?.headers).toEqual({ Accept: "application/json" });
  });

  test("refreshes on a new startup and adds newly advertised models", async () => {
    const home = await stateHome();
    const first = await run({}, { fetch: fetchOnce(payload([entry("A"), entry("B")])), stateHome: home });
    const second = await run({}, { fetch: fetchOnce(payload([entry("A"), entry("B"), entry("C")])), stateHome: home });

    expect(Object.keys(first.config.provider?.mocin?.models ?? {})).toEqual(["A", "B"]);
    expect(Object.keys(second.config.provider?.mocin?.models ?? {})).toEqual(["A", "B", "C"]);
  });

  test("refreshes on a new startup and removes no-longer-advertised models", async () => {
    const home = await stateHome();
    await run({}, { fetch: fetchOnce(payload([entry("A"), entry("B"), entry("C")])), stateHome: home });
    const second = await run({}, { fetch: fetchOnce(payload([entry("A"), entry("C")])), stateHome: home });

    expect(Object.keys(second.config.provider?.mocin?.models ?? {})).toEqual(["A", "C"]);
    expect(second.config.provider?.mocin?.models).not.toHaveProperty("B");
  });

  test("preserves matching tracked metadata and excludes stale overrides", async () => {
    const home = await stateHome();
    const result = await run(
      {
        A: { name: "Curated A", limit: { context: 123 } },
        stale: { name: "Stale" },
      },
      { fetch: fetchOnce(payload([entry("A")])), stateHome: home },
    );

    expect(result.config.provider?.mocin?.models).toEqual({
      A: { name: "Curated A", limit: { context: 123 } },
    });
  });
});

describe("Mocin last-known-good state", () => {
  test("writes and replaces a validated LKG snapshot", async () => {
    const home = await stateHome();
    await run({}, { fetch: fetchOnce(payload([entry("A")])), stateHome: home });
    const path = join(home, "opencode", "mocin-models.json");
    expect(JSON.parse(await readFile(path, "utf8"))).toEqual({
      version: 1,
      provider: "mocin",
      endpoint: DISCOVERY_ENDPOINT,
      models: ["A"],
    });
    expect((await stat(join(home, "opencode"))).mode & 0o777).toBe(0o700);
    expect((await stat(path)).mode & 0o777).toBe(0o600);

    await run({}, { fetch: fetchOnce(payload([entry("B")])), stateHome: home });
    expect(JSON.parse(await readFile(path, "utf8"))).toEqual({
      version: 1,
      provider: "mocin",
      endpoint: DISCOVERY_ENDPOINT,
      models: ["B"],
    });
  });

  test("falls back to valid LKG state for timeout, network, and HTTP failures", async () => {
    const home = await stateHome();
    await run({}, { fetch: fetchOnce(payload([entry("A")])), stateHome: home });

    const failures = [
      async (_input: RequestInfo | URL, init?: RequestInit) => {
        await new Promise<never>((_, reject) => {
          init?.signal?.addEventListener("abort", () => reject(new DOMException("aborted", "AbortError")));
        });
        throw new Error("unreachable");
      },
      async () => {
        throw new Error("network failure");
      },
      fetchOnce({ error: "down" }, 503),
    ];

    for (const fetch of failures) {
      const result = await run({ A: { name: "Current metadata" } }, {
        fetch,
        stateHome: home,
        timeoutMs: 2,
      });
      expect(result.config.provider?.mocin?.models).toEqual({ A: { name: "Current metadata" } });
      expect(result.warnings.some((warning) => warning.includes("using last-known-good inventory"))).toBe(true);
    }
  });

  test("does not replace LKG for malformed JSON, invalid shape, or empty inventory", async () => {
    const home = await stateHome();
    const path = join(home, "opencode", "mocin-models.json");
    await run({}, { fetch: fetchOnce(payload([entry("A")])), stateHome: home });

    const invalidResponses = [
      response("{"),
      response({ total: 1, models: "A" }),
      response(payload([])),
    ];
    for (const invalid of invalidResponses) {
      const result = await run({}, { fetch: async () => invalid, stateHome: home });
      expect(Object.keys(result.config.provider?.mocin?.models ?? {})).toEqual(["A"]);
      expect(JSON.parse(await readFile(path, "utf8")).models).toEqual(["A"]);
    }
  });

  test("rejects corrupt LKG and leaves Mocin unavailable without crashing OpenCode", async () => {
    const home = await stateHome();
    const directory = join(home, "opencode");
    await import("node:fs/promises").then(({ mkdir }) => mkdir(directory, { recursive: true }));
    await writeFile(join(directory, "mocin-models.json"), "not json");

    const result = await run({}, {
      fetch: async () => {
        throw new Error("offline");
      },
      stateHome: home,
    });
    expect(result.config.provider?.mocin?.models).toEqual({});
    expect(result.warnings).toContain("last-known-good inventory was invalid; ignoring it");
    expect(result.config.provider?.other?.models).toEqual({ untouched: { name: "Other" } });
  });

  test("distinguishes an unreadable LKG from invalid state", async () => {
    const home = await stateHome();
    const result = await run({}, {
      fetch: async () => {
        throw new Error("offline");
      },
      fileSystem: fsWith({
        readFile: async () => {
          throw Object.assign(new Error("permission denied"), { code: "EACCES" });
        },
      }),
      stateHome: home,
    });

    expect(result.config.provider?.mocin?.models).toEqual({});
    expect(result.warningEntries).toContainEqual(expect.objectContaining({
      message: "last-known-good inventory could not be read",
      extra: { category: "lkg-read" },
    }));
    expect(result.warnings).not.toContain("last-known-good inventory was corrupt or invalid; ignoring it");
  });

  test("deduplicates valid IDs restored from LKG", async () => {
    const home = await stateHome();
    const directory = join(home, "opencode");
    await import("node:fs/promises").then(({ mkdir }) => mkdir(directory, { recursive: true }));
    await writeFile(join(directory, "mocin-models.json"), JSON.stringify({
      version: 1,
      provider: "mocin",
      endpoint: DISCOVERY_ENDPOINT,
      models: ["A", "A"],
    }));

    const result = await run({}, {
      fetch: async () => {
        throw new Error("offline");
      },
      stateHome: home,
    });

    expect(Object.keys(result.config.provider?.mocin?.models ?? {})).toEqual(["A"]);
  });

  test("rejects LKG state with an unsupported schema or discovery source", async () => {
    const home = await stateHome();
    const directory = join(home, "opencode");
    await import("node:fs/promises").then(({ mkdir }) => mkdir(directory, { recursive: true }));
    const path = join(directory, "mocin-models.json");
    const invalidStates = [
      { version: 2, provider: "mocin", endpoint: DISCOVERY_ENDPOINT, models: ["A"] },
      { version: 1, provider: "other", endpoint: DISCOVERY_ENDPOINT, models: ["A"] },
      { version: 1, provider: "mocin", endpoint: "https://other.example/models", models: ["A"] },
      { version: 1, provider: "mocin", endpoint: DISCOVERY_ENDPOINT, models: [] },
      { version: 1, provider: "mocin", endpoint: DISCOVERY_ENDPOINT, models: [" "] },
    ];

    for (const invalidState of invalidStates) {
      await writeFile(path, JSON.stringify(invalidState));
      const result = await run({}, {
        fetch: async () => {
          throw new Error("offline");
        },
        stateHome: home,
      });
      expect(result.config.provider?.mocin?.models).toEqual({});
      expect(result.warnings).toContain("last-known-good inventory was invalid; ignoring it");
    }
  });

  test("combines LKG availability with current tracked metadata", async () => {
    const home = await stateHome();
    await run({}, { fetch: fetchOnce(payload([entry("A"), entry("B")])), stateHome: home });
    const result = await run(
      { A: { name: "Current A" }, C: { name: "Stale C" } },
      {
        fetch: async () => {
          throw new Error("offline");
        },
        stateHome: home,
      },
    );

    expect(result.config.provider?.mocin?.models).toEqual({
      A: { name: "Current A" },
      B: {},
    });
  });

  test("leaves Mocin empty and warns when remote failure has no LKG", async () => {
    const home = await stateHome();
    const result = await run({}, {
      fetch: async () => {
        throw new Error("offline");
      },
      stateHome: home,
    });

    expect(result.config.provider?.mocin?.models).toEqual({});
    expect(result.warningEntries).toContainEqual(expect.objectContaining({
      message: "last-known-good inventory was not found",
      extra: { category: "lkg-missing" },
    }));
    expect(result.warnings).toContain("Mocin model discovery failed and no valid last-known-good inventory is available");
  });
});

describe("Mocin persistence failure semantics", () => {
  test("keeps remote models usable when LKG persistence fails", async () => {
    const home = await stateHome();
    const result = await run({}, {
      fetch: fetchOnce(payload([entry("A"), entry("B")])),
      stateHome: home,
      fileSystem: fsWith({
        rename: async () => {
          throw new Error("rename failed");
        },
      }),
    });

    expect(Object.keys(result.config.provider?.mocin?.models ?? {})).toEqual(["A", "B"]);
    expect(result.warnings).toContain("last-known-good inventory could not be persisted");
  });

  test("does not expose a partial final file while the temporary file is being written", async () => {
    const home = await stateHome();
    await run({}, { fetch: fetchOnce(payload([entry("A")])), stateHome: home });
    const path = join(home, "opencode", "mocin-models.json");
    let releaseWrite!: () => void;
    let writeStarted!: () => void;
    const started = new Promise<void>((resolve) => {
      writeStarted = resolve;
    });
    const blocked = new Promise<void>((resolve) => {
      releaseWrite = resolve;
    });
    const fileSystem = fsWith({
      writeFile: async (file, data) => {
        if (file.includes(".tmp.")) {
          writeStarted();
          await blocked;
        }
        await writeFile(file, data, { mode: 0o600 });
      },
    });
    const config: OpenCodeConfig = { provider: { mocin: { models: {} } } };
    const update = createMocinPlugin({
      fetch: fetchOnce(payload([entry("B")])),
      fileSystem,
      stateHome: home,
    }).config(config);

    await started;
    expect(JSON.parse(await readFile(path, "utf8")).models).toEqual(["A"]);
    releaseWrite();
    await update;
    expect(JSON.parse(await readFile(path, "utf8")).models).toEqual(["B"]);
  });

  test("does not delete the existing LKG when rename fails", async () => {
    const home = await stateHome();
    await run({}, { fetch: fetchOnce(payload([entry("A")])), stateHome: home });
    const path = join(home, "opencode", "mocin-models.json");
    await run({}, {
      fetch: fetchOnce(payload([entry("B")])),
      fileSystem: fsWith({
        rename: async () => {
          throw new Error("rename failed");
        },
      }),
      stateHome: home,
    });

    expect(JSON.parse(await readFile(path, "utf8")).models).toEqual(["A"]);
    expect((await readdir(join(home, "opencode"))).filter((name) => name.includes(".tmp."))).toEqual([]);
  });

  test("does not delete the existing LKG when temporary writing fails", async () => {
    const home = await stateHome();
    await run({}, { fetch: fetchOnce(payload([entry("A")])), stateHome: home });
    const path = join(home, "opencode", "mocin-models.json");
    await run({}, {
      fetch: fetchOnce(payload([entry("B")])),
      fileSystem: fsWith({
        writeFile: async (file, data) => {
          if (file.includes(".tmp.")) throw new Error("write failed");
          await writeFile(file, data, { mode: 0o600 });
        },
      }),
      stateHome: home,
    });

    expect(JSON.parse(await readFile(path, "utf8")).models).toEqual(["A"]);
    expect((await readdir(join(home, "opencode"))).filter((name) => name.includes(".tmp."))).toEqual([]);
  });

  test("uses unique temporary paths for concurrent replacements", async () => {
    const home = await stateHome();
    const temporaryPaths: string[] = [];
    const fileSystem = fsWith({
      writeFile: async (path, data) => {
        if (path.includes(".tmp.")) temporaryPaths.push(path);
        await writeFile(path, data, { mode: 0o600 });
      },
    });

    await Promise.all([
      run({}, { fetch: fetchOnce(payload([entry("A")])), fileSystem, stateHome: home }),
      run({}, { fetch: fetchOnce(payload([entry("B")])), fileSystem, stateHome: home }),
    ]);

    expect(temporaryPaths).toHaveLength(2);
    expect(new Set(temporaryPaths).size).toBe(2);
  });
});

describe("Mocin logging and timeout safety", () => {
  test("uses a finite timeout and never logs a secret-bearing error", async () => {
    const home = await stateHome();
    const warnings: string[] = [];
    const plugin = createMocinPlugin({
      fetch: async (_input, init) => {
        expect(init?.signal).toBeDefined();
        await new Promise<never>((_, reject) => {
          init?.signal?.addEventListener("abort", () => reject(new DOMException("aborted", "AbortError")));
        });
        throw new Error("Authorization: test-api-key");
      },
      logger: ({ message }) => warnings.push(message),
      stateHome: home,
      timeoutMs: 2,
    });
    await plugin.config({ provider: { mocin: { models: {} } } });

    expect(warnings.join("\n")).not.toContain("test-api-key");
    expect(warnings.some((warning) => warning.includes("no valid last-known-good inventory"))).toBe(true);
  });
});
