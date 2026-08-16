import { createOpenCodeDynamicProviderPlugin } from "../engine.ts";

const spec = {
  id: "mocin",
  discovery: {
    kind: "mocin" as const,
    endpoint: "https://beta.masven.dev/webapi/models",
  },
  legacyStatePath: "opencode/mocin-models.json",
};

export default async function MocinDynamicModelsPlugin(input: Parameters<typeof createOpenCodeDynamicProviderPlugin>[1] = {}) {
  return createOpenCodeDynamicProviderPlugin(spec, input);
}
