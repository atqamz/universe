import { AdapterPayloadError } from "./openai.ts";

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function isUnchangedComponent(value: unknown): value is string {
  return typeof value === "string" && value.length > 0 && value.trim() === value;
}

function isRouteProvider(value: unknown): value is string {
  return isUnchangedComponent(value) && !value.includes("/");
}

function callableId(provider: string, model: string): string {
  return `${provider}/${model}`;
}

export function parseMocinCallableIds(value: unknown): string[] {
  if (!isRecord(value) || !Array.isArray(value.models)) throw new AdapterPayloadError();

  const availability = new Map<string, boolean>();
  for (const item of value.models) {
    if (!isRecord(item) || typeof item.active !== "boolean") throw new AdapterPayloadError();
    if (!item.active && (!isRouteProvider(item.provider) || !isUnchangedComponent(item.model))) continue;
    if (!isRouteProvider(item.provider) || !isUnchangedComponent(item.model)) throw new AdapterPayloadError();

    const id = callableId(item.provider, item.model);
    const previous = availability.get(id);
    if (previous !== undefined && previous !== item.active) throw new AdapterPayloadError();
    availability.set(id, item.active);
  }

  const ids = [...availability].filter(([, active]) => active).map(([id]) => id);
  if (ids.length === 0) throw new AdapterPayloadError();
  return ids;
}
