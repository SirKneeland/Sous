// OpenAI forwarding boundary (Project 3).
//
// The proxy routes never call OpenAI directly — they depend on this interface,
// which is injected into AppDeps. Production wires `createOpenAIProxy` (real
// fetch with the server's key); tests inject a fake that returns canned
// Responses, so no network or real key is needed.
//
// SECURITY: The server's OpenAI key lives only inside this module's closure. The
// client never sees it; only the Authorization header on the outbound request to
// api.openai.com carries it. The inbound client request body is forwarded, but
// the inbound Authorization header (the Sous session token) is NOT — it is
// consumed by auth middleware and never reaches OpenAI.

const OPENAI_CHAT_URL = 'https://api.openai.com/v1/chat/completions';
const OPENAI_TTS_URL = 'https://api.openai.com/v1/audio/speech';

export interface OpenAIProxy {
  /** Forward a chat-completions body to OpenAI; returns the upstream Response. */
  forwardChat(body: unknown): Promise<Response>;
  /** Forward a TTS (audio/speech) body to OpenAI; returns the upstream Response. */
  forwardTTS(body: unknown): Promise<Response>;
}

export function createOpenAIProxy(apiKey: string): OpenAIProxy {
  const headers = {
    Authorization: `Bearer ${apiKey}`,
    'Content-Type': 'application/json',
  };
  return {
    async forwardChat(body) {
      return fetch(OPENAI_CHAT_URL, {
        method: 'POST',
        headers,
        body: JSON.stringify(body),
      });
    },
    async forwardTTS(body) {
      return fetch(OPENAI_TTS_URL, {
        method: 'POST',
        headers,
        body: JSON.stringify(body),
      });
    },
  };
}

// ---------------------------------------------------------------------------
// Usage parsing
// ---------------------------------------------------------------------------

export interface ParsedUsage {
  inputTokens: number | null;
  outputTokens: number | null;
}

/** Extract token usage from a non-streaming chat completion JSON body. */
export function usageFromJson(json: unknown): ParsedUsage {
  const usage = (json as { usage?: { prompt_tokens?: number; completion_tokens?: number } })
    ?.usage;
  return {
    inputTokens: usage?.prompt_tokens ?? null,
    outputTokens: usage?.completion_tokens ?? null,
  };
}

/**
 * Extract token usage from accumulated SSE text. OpenAI emits a final
 * `data: {...}` chunk carrying `usage` when `stream_options.include_usage` is set.
 * Returns nulls if no usage chunk was present.
 */
export function usageFromSse(sseText: string): ParsedUsage {
  let result: ParsedUsage = { inputTokens: null, outputTokens: null };
  for (const line of sseText.split('\n')) {
    const trimmed = line.trim();
    if (!trimmed.startsWith('data:')) continue;
    const payload = trimmed.slice(5).trim();
    if (payload === '[DONE]' || payload.length === 0) continue;
    try {
      const obj = JSON.parse(payload) as {
        usage?: { prompt_tokens?: number; completion_tokens?: number } | null;
      };
      if (obj.usage) {
        result = {
          inputTokens: obj.usage.prompt_tokens ?? null,
          outputTokens: obj.usage.completion_tokens ?? null,
        };
      }
    } catch {
      // Ignore non-JSON / partial lines.
    }
  }
  return result;
}
