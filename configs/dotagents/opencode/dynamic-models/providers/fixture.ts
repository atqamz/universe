import { createOpenCodeDynamicProviderPlugin } from "../engine.ts";

export default async function FixtureProviderPlugin(input: Parameters<typeof createOpenCodeDynamicProviderPlugin>[1] = {}) {
  return createOpenCodeDynamicProviderPlugin({
    id: "fixture-provider",
    discovery: { kind: "openai" },
  }, input);
}
