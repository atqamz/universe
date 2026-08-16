export class AdapterPayloadError extends Error {}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function isUnchangedModelId(value: unknown): value is string {
  return typeof value === "string" && value.length > 0 && value.trim() === value;
}

export function parseOpenAIModelIds(value: unknown): string[] {
  if (!isRecord(value) || !Array.isArray(value.data)) throw new AdapterPayloadError();

  const ids: string[] = [];
  const seen = new Set<string>();
  for (const item of value.data) {
    if (!isRecord(item) || !isUnchangedModelId(item.id)) throw new AdapterPayloadError();
    if (!seen.has(item.id)) {
      seen.add(item.id);
      ids.push(item.id);
    }
  }
  if (ids.length === 0) throw new AdapterPayloadError();
  return ids;
}
