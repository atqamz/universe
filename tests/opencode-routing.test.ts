import { mkdtemp, mkdir, rm, symlink, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";

import { afterEach, describe, expect, test } from "bun:test";

const opencodeCommand = process.env.OPENCODE_BIN
  ? [process.env.OPENCODE_BIN]
  : process.env.OPENCODE_RUNNER
    ? JSON.parse(process.env.OPENCODE_RUNNER) as string[]
    : undefined;
const temporaryDirectories: string[] = [];

afterEach(async () => {
  await Promise.all(temporaryDirectories.splice(0).map((path) => rm(path, { force: true, recursive: true })));
});

async function run(command: string[], args: string[], environment: Record<string, string>, cwd: string) {
  const process = Bun.spawn([...command, ...args], {
    cwd,
    env: { ...globalThis.process.env, ...environment },
    stderr: "pipe",
    stdout: "pipe",
  });
  const [stdout, stderr, exitCode] = await Promise.all([
    new Response(process.stdout).text(),
    new Response(process.stderr).text(),
    process.exited,
  ]);
  return { stdout, stderr, exitCode };
}

describe.skipIf(!opencodeCommand)("OpenCode 1.18.16 provider routing", () => {
  test("keeps the selector and API model IDs separate through inference", async () => {
    const calls: Array<{ path: string; model?: string }> = [];
    const server = Bun.serve({
      port: 0,
      async fetch(request) {
        const url = new URL(request.url);
        if (request.method === "GET" && url.pathname === "/v1/models") {
          return Response.json({ data: [{ id: "alpha/model-a" }, { id: "model-b" }] });
        }
        if (request.method === "POST" && url.pathname === "/v1/chat/completions") {
          const body = await request.json() as { model?: string };
          calls.push({ path: url.pathname, model: body.model });
          const stream = [
            { id: "chatcmpl-fixture", object: "chat.completion.chunk", choices: [{ index: 0, delta: { role: "assistant" }, finish_reason: null }] },
            { id: "chatcmpl-fixture", object: "chat.completion.chunk", choices: [{ index: 0, delta: { content: "ok" }, finish_reason: null }] },
            { id: "chatcmpl-fixture", object: "chat.completion.chunk", choices: [{ index: 0, delta: {}, finish_reason: "stop" }] },
          ].map((chunk) => `data: ${JSON.stringify(chunk)}\n\n`).join("") + "data: [DONE]\n\n";
          return new Response(stream, { headers: { "content-type": "text/event-stream" } });
        }
        return new Response("not found", { status: 404 });
      },
    });
    const root = await mkdtemp(join(tmpdir(), "opencode-routing-test-"));
    temporaryDirectories.push(root);
    const configHome = join(root, "config");
    const configDir = join(configHome, "opencode");
    const stateHome = join(root, "state");
    const dataHome = join(root, "data");
    const project = join(root, "project");
    await Promise.all([mkdir(configDir, { recursive: true }), mkdir(stateHome), mkdir(dataHome), mkdir(project)]);

    const callableId = "alpha/model-a";
    const selectorId = encodeURIComponent(callableId);
    const baseURL = `${server.url}v1`;
    await symlink(join(import.meta.dir, "..", "opencode", "dynamic-models"), join(configDir, "dynamic-models"));
    await writeFile(join(configDir, "opencode.json"), JSON.stringify({
      "$schema": "https://opencode.ai/config.json",
      plugin: ["./dynamic-models/providers/fixture.ts"],
      provider: {
        "fixture-provider": {
          npm: "@ai-sdk/openai-compatible",
          options: { baseURL },
          models: {},
        },
      },
    }));

    const environment = {
      HOME: root,
      XDG_CONFIG_HOME: configHome,
      XDG_DATA_HOME: dataHome,
      XDG_STATE_HOME: stateHome,
      OPENCODE_DISABLE_AUTOUPDATE: "1",
      NO_COLOR: "1",
    };
    try {
      const version = await run(opencodeCommand!, ["--version"], environment, project);
      expect(version.exitCode).toBe(0);
      expect(version.stdout.trim()).toBe("1.18.16");

      const debug = await run(opencodeCommand!, ["debug", "config"], environment, project);
      expect(debug.exitCode).toBe(0);
      const parsed = JSON.parse(debug.stdout) as { provider?: Record<string, { models?: Record<string, { id?: string }> }> };
      expect(parsed.provider?.["fixture-provider"]?.models?.[selectorId]?.id).toBe(callableId);

      const models = await run(opencodeCommand!, ["models", "fixture-provider"], environment, project);
      expect(models.exitCode).toBe(0);
      expect(models.stdout).toContain(selectorId);

      const inference = await run(opencodeCommand!, ["run", "--auto", "--format", "json", "--model", `fixture-provider/${selectorId}`, "say hello"], environment, project);
      expect(inference.exitCode).toBe(0);
      expect(calls.length).toBeGreaterThan(0);
      expect(calls.every(({ path, model }) => path === "/v1/chat/completions" && model === callableId)).toBe(true);
    } finally {
      server.stop(true);
    }
  }, 30_000);
});
