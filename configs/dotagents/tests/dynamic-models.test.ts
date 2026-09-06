import { mkdtemp, readFile, readdir, rm, stat, writeFile } from "node:fs/promises";
import { homedir, tmpdir } from "node:os";
import { join } from "node:path";

import { afterEach, describe, expect, test } from "bun:test";

import {
  createDynamicProviderPlugin,
  decodeSelectorId,
  encodeSelectorId,
  type DynamicProviderSpec,
  type FileSystem,
  type OpenCodeConfig,
} from "../opencode/dynamic-models/engine.ts";

const homes: string[] = [];

afterEach(async () => {
  await Promise.all(homes.splice(0).map((path) => rm(path, { force: true, recursive: true })));
});

function response(body: unknown, status = 200): Response {
  return new Response(typeof body === "string" ? body : JSON.stringify(body), {
    headers: { "content-type": "application/json" },
    status,
  });
}

function fetchOnce(body: unknown, status = 200, capture?: (input: RequestInfo | URL, init?: RequestInit) => void): typeof fetch {
  return async (input, init) => {
    capture?.(input, init);
    return response(body, status);
  };
}

function openAiSpec(): DynamicProviderSpec {
  return { id: "fixture-provider", discovery: { kind: "openai" } };
}

async function stateHome(prefix = "dynamic-models-test-"): Promise<string> {
  const path = await mkdtemp(join(tmpdir(), prefix));
  homes.push(path);
  return path;
}

async function run(
  spec: DynamicProviderSpec,
  provider: Record<string, unknown>,
  fetcher: typeof fetch,
  options: Parameters<typeof createDynamicProviderPlugin>[1] = {},
): Promise<{ config: OpenCodeConfig; warnings: Array<{ message: string; extra?: Record<string, unknown> }> }> {
  const warnings: Array<{ message: string; extra?: Record<string, unknown> }> = [];
  const config: OpenCodeConfig = { provider: { unrelated: { models: { untouched: { name: "Other" } } }, [spec.id]: provider } };
  const plugin = createDynamicProviderPlugin(spec, {
    fetch: fetcher,
    logger: (entry) => warnings.push(entry),
    ...options,
  });
  await plugin.config(config);
  return { config, warnings };
}

describe("selector identity", () => {
  test("is deterministic, slash-free, injective, and reversible", () => {
    const callableIds = [
      "nr/foo/bar",
      "nr/foo-bar",
      "nr/foo__bar",
      "nr/foo%2Fbar",
      "tr/deepseek/deepseek-v4-flash-0731",
      "model-with-dash_and__underscore",
    ];
    const selectors = callableIds.map(encodeSelectorId);

    expect(new Set(selectors).size).toBe(callableIds.length);
    expect(selectors.every((selector) => !selector.includes("/"))).toBe(true);
    expect(selectors.map(decodeSelectorId)).toEqual(callableIds);
    expect(encodeSelectorId("nr/foo/bar")).toBe(encodeSelectorId("nr/foo/bar"));
  });
});

describe("standard OpenAI-compatible adapter", () => {
  test("joins /models using URL semantics and preserves exact IDs", async () => {
    let input: RequestInfo | URL | undefined;
    const result = await run(
      openAiSpec(),
      { options: { baseURL: "https://fixture.invalid/v1" }, models: {} },
      fetchOnce({ data: [{ id: "alpha/model-a" }, { id: "model-b" }, { id: "alpha/model-a" }] }, 200, (request) => {
        input = request;
      }),
      { stateHome: await stateHome() },
    );

    expect(String(input)).toBe("https://fixture.invalid/v1/models");
    expect(Object.keys(result.config.provider?.["fixture-provider"]?.models ?? {})).toEqual([
      encodeSelectorId("alpha/model-a"),
      "model-b",
    ]);
  });

  test("sends no guessed credentials and rejects empty or malformed inventories", async () => {
    let init: RequestInit | undefined;
    const result = await run(
      openAiSpec(),
      { options: { baseURL: "https://fixture.invalid/v1" }, models: {} },
      fetchOnce({ data: [] }, 200, (_request, requestInit) => {
        init = requestInit;
      }),
      { stateHome: await stateHome() },
    );
    expect(init?.headers).toEqual({ Accept: "application/json" });
    expect(result.config.provider?.["fixture-provider"]?.models).toEqual({});
    expect(result.warnings.some(({ extra }) => extra?.category === "lkg-missing")).toBe(true);
  });
});

describe("generic lifecycle and LKG", () => {
  test("refreshes provider-scoped callable LKG and regenerates selectors", async () => {
    const state = await stateHome();
    const spec = openAiSpec();
    await run(spec, { options: { baseURL: "https://fixture.invalid/v1" }, models: {} }, fetchOnce({ data: [{ id: "nr/foo" }] }), { stateHome: state });

    const path = join(state, "opencode", "dynamic-models", "fixture-provider.json");
    expect(JSON.parse(await readFile(path, "utf8"))).toEqual({
      version: 2,
      provider: "fixture-provider",
      source: "https://fixture.invalid/v1/models",
      models: ["nr/foo"],
    });
    expect((await stat(path)).mode & 0o777).toBe(0o600);

    const fallback = await run(
      spec,
      { options: { baseURL: "https://fixture.invalid/v1" }, models: {} },
      async () => { throw new Error("offline"); },
      { stateHome: state },
    );
    expect(fallback.config.provider?.["fixture-provider"]?.models).toEqual({
      [encodeSelectorId("nr/foo")]: { id: "nr/foo", name: "nr/foo" },
    });
  });

  test("keeps the previous LKG when atomic replacement fails", async () => {
    const state = await stateHome();
    const spec = openAiSpec();
    await run(spec, { options: { baseURL: "https://fixture.invalid/v1" }, models: {} }, fetchOnce({ data: [{ id: "old/model" }] }), { stateHome: state });
    const fs: Partial<FileSystem> = { rename: async () => { throw new Error("rename failed"); } };
    const result = await run(spec, { options: { baseURL: "https://fixture.invalid/v1" }, models: {} }, fetchOnce({ data: [{ id: "new/model" }] }), { stateHome: state, fileSystem: fs });
    expect(Object.keys(result.config.provider?.["fixture-provider"]?.models ?? {})).toEqual([encodeSelectorId("new/model")]);
    expect(JSON.parse(await readFile(join(state, "opencode", "dynamic-models", "fixture-provider.json"), "utf8")).models).toEqual(["old/model"]);
    expect((await readdir(join(state, "opencode", "dynamic-models"))).filter((name) => name.includes(".tmp.")).length).toBe(0);
  });

  test("rejects corrupt, mismatched, empty, and wrong-schema provider snapshots", async () => {
    const state = await stateHome();
    const path = join(state, "opencode", "dynamic-models", "fixture-provider.json");
    await import("node:fs/promises").then(({ mkdir }) => mkdir(join(state, "opencode", "dynamic-models"), { recursive: true }));
    const invalidSnapshots = [
      "not json",
      JSON.stringify({ version: 1, provider: "fixture-provider", source: "https://fixture.invalid/v1/models", models: ["model"] }),
      JSON.stringify({ version: 2, provider: "other", source: "https://fixture.invalid/v1/models", models: ["model"] }),
      JSON.stringify({ version: 2, provider: "fixture-provider", source: "https://other.invalid/models", models: ["model"] }),
      JSON.stringify({ version: 2, provider: "fixture-provider", source: "https://fixture.invalid/v1/models", models: [] }),
      JSON.stringify({ version: 2, provider: "fixture-provider", source: "https://fixture.invalid/v1/models", models: [" model"] }),
    ];

    for (const snapshot of invalidSnapshots) {
      await writeFile(path, snapshot);
      const result = await run(
        openAiSpec(),
        { options: { baseURL: "https://fixture.invalid/v1" }, models: {} },
        async () => { throw new Error("offline"); },
        { stateHome: state },
      );
      expect(result.config.provider?.["fixture-provider"]?.models).toEqual({});
      expect(result.warnings.some(({ extra }) => extra?.category === "lkg-invalid")).toBe(true);
    }
  });

  test("isolates timeout, HTTP, malformed JSON, and unreadable-state failures", async () => {
    const failures: Array<{ fetch: typeof fetch; category: string }> = [
      {
        fetch: async (_input, init) => {
          await new Promise<never>((_, reject) => init?.signal?.addEventListener("abort", () => reject(new Error("aborted"))));
          throw new Error("unreachable");
        },
        category: "timeout",
      },
      { fetch: fetchOnce({ error: "down" }, 503), category: "http" },
      { fetch: fetchOnce("{"), category: "payload" },
    ];

    for (const failure of failures) {
      const result = await run(
        openAiSpec(),
        { options: { baseURL: "https://fixture.invalid/v1" }, models: {} },
        failure.fetch,
        { stateHome: await stateHome(), timeoutMs: 2 },
      );
      expect(result.config.provider?.["fixture-provider"]?.models).toEqual({});
      expect(result.warnings.some(({ extra }) => extra?.category === failure.category)).toBe(true);
    }

    const unreadable = await run(
      openAiSpec(),
      { options: { baseURL: "https://fixture.invalid/v1" }, models: {} },
      async () => { throw new Error("offline"); },
      {
        stateHome: await stateHome(),
        fileSystem: {
          readFile: async () => { throw Object.assign(new Error("permission denied"), { code: "EACCES" }); },
        },
      },
    );
    expect(unreadable.warnings.some(({ extra }) => extra?.category === "lkg-read")).toBe(true);
  });

  test("isolates provider failure and does not let stale metadata resurrect a model", async () => {
    const state = await stateHome();
    const good = openAiSpec();
    const bad: DynamicProviderSpec = { id: "broken", discovery: { kind: "openai" } };
    const config: OpenCodeConfig = {
      provider: {
        "fixture-provider": { options: { baseURL: "https://fixture.invalid/v1" }, models: { stale: { name: "stale" } } },
        broken: { options: { baseURL: "https://broken.invalid/v1" }, models: {} },
      },
    };
    const pluginA = createDynamicProviderPlugin(good, { fetch: fetchOnce({ data: [{ id: "fresh/model" }] }), stateHome: state });
    const pluginB = createDynamicProviderPlugin(bad, { fetch: async () => { throw new Error("offline"); }, stateHome: state });
    await pluginA.config(config);
    await pluginB.config(config);
    expect(config.provider?.["fixture-provider"]?.models).toEqual({
      [encodeSelectorId("fresh/model")]: { id: "fresh/model", name: "fresh/model" },
    });
    expect(config.provider?.broken?.models).toEqual({});
  });

  test("uses a safe warning shape without exposing request errors", async () => {
    const secret = "bearer-secret-that-must-not-escape";
    const warnings: Array<{ message: string; extra?: Record<string, unknown> }> = [];
    const plugin = createDynamicProviderPlugin(openAiSpec(), {
      fetch: async () => { throw new Error(`Authorization: Bearer ${secret}`); },
      logger: (entry) => warnings.push(entry),
      stateHome: await stateHome(),
    });
    await plugin.config({ provider: { "fixture-provider": { options: { baseURL: "https://fixture.invalid/v1" }, models: {} } } });
    expect(JSON.stringify(warnings)).not.toContain(secret);
    expect(warnings.every(({ extra }) => extra?.provider === "fixture-provider")).toBe(true);
  });
});

describe("persistence path fallback", () => {
  test("uses the default state directory when the override is relative", async () => {
    const paths: string[] = [];
    await run(
      openAiSpec(),
      { options: { baseURL: "https://fixture.invalid/v1" }, models: {} },
      fetchOnce({ data: [{ id: "model" }] }),
      {
        stateHome: "relative-state",
        fileSystem: {
          chmod: async (path) => paths.push(path),
          mkdir: async (path) => paths.push(path),
          readFile: async () => { throw Object.assign(new Error("missing"), { code: "ENOENT" }); },
          writeFile: async (path) => paths.push(path),
          rename: async (from, to) => paths.push(from, to),
          unlink: async (path) => paths.push(path),
        },
      },
    );
    expect(paths.every((path) => path.startsWith(join(homedir(), ".local", "state")))).toBe(true);
  });
});
