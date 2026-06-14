// Cost estimation for proxied OpenAI requests. Rates are USD per 1,000 tokens
// (text/chat) or USD per 1,000 characters (TTS). These are estimates for
// internal monitoring only — not billed to users — so an unknown model falls
// back to a conservative default rather than failing the request.
//
// Keep this table updated as models change; it is the single source of truth
// for the `estimated_cost_usd` column.

interface ChatRate {
  /** USD per 1K input (prompt) tokens. */
  input: number;
  /** USD per 1K output (completion) tokens. */
  output: number;
}

const CHAT_RATES: Record<string, ChatRate> = {
  'gpt-5.4-mini': { input: 0.00015, output: 0.0006 },
  'gpt-4o-mini': { input: 0.00015, output: 0.0006 },
  'gpt-4o': { input: 0.0025, output: 0.01 },
};

/** Default applied to unknown chat models (mirrors the mini tier). */
const DEFAULT_CHAT_RATE: ChatRate = { input: 0.00015, output: 0.0006 };

/** USD per 1K characters for TTS (OpenAI tts-1 family). */
const TTS_RATE_PER_1K_CHARS = 0.015;

/** Estimate USD cost for a chat completion given token counts and model. */
export function estimateChatCost(
  model: string | null,
  inputTokens: number | null,
  outputTokens: number | null,
): number {
  const rate = (model && CHAT_RATES[model]) || DEFAULT_CHAT_RATE;
  const inUsd = ((inputTokens ?? 0) / 1000) * rate.input;
  const outUsd = ((outputTokens ?? 0) / 1000) * rate.output;
  return round6(inUsd + outUsd);
}

/** Estimate USD cost for a TTS request given character count. */
export function estimateTtsCost(characters: number | null): number {
  return round6(((characters ?? 0) / 1000) * TTS_RATE_PER_1K_CHARS);
}

/** numeric(10,6) in the schema — round to 6 dp so inserts never truncate-error. */
function round6(n: number): number {
  return Math.round(n * 1e6) / 1e6;
}
