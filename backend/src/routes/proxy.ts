// /api/v1/proxy/* — OpenAI proxy (Project 3).
//
// Non-BYOK users' OpenAI calls route through here so the backend can: validate
// the request shape, run conservative off-topic detection, enforce the recipe
// cap on new-recipe requests, forward to OpenAI with the SERVER's key, stream
// the response back unchanged, and record a usage_events row + run abuse checks.
//
// The iOS client must not be able to tell it is talking to a proxy vs. OpenAI
// directly — the response body/headers are relayed verbatim.

import { Hono } from 'hono';
import { z } from 'zod';
import type { HonoEnv } from '../types.js';
import type { AppDeps } from '../types.js';
import type { RequestType, RequestOutcome } from '../db/types.js';
import { authMiddleware } from '../middleware/auth.js';
import { resolveAccess } from '../lib/access.js';
import { paidRecipeCap, trialRecipeCap } from '../lib/config.js';
import { detectOffTopic, offTopicThresholdFrom } from '../lib/offTopicDetector.js';
import { usageFromJson, usageFromSse } from '../lib/openai.js';
import { estimateChatCost, estimateTtsCost } from '../lib/cost.js';
import { currentBillingPeriod } from '../lib/billingPeriod.js';
import { abuseConfigFrom, checkAbuse } from '../lib/abuseDetector.js';

// Lenient chat-completions schema: validate the fields we use, passthrough the
// rest (temperature, response_format, stream_options, …) so OpenAI features keep
// working without this proxy needing to know about them.
const messageSchema = z
  .object({
    role: z.string(),
    // content is a string (text) or an array of parts (multimodal).
    content: z.union([z.string(), z.array(z.any()), z.null()]).optional(),
  })
  .passthrough();

const chatBodySchema = z
  .object({
    model: z.string().min(1),
    messages: z.array(messageSchema).min(1),
    stream: z.boolean().optional(),
  })
  .passthrough();

const ttsBodySchema = z
  .object({
    model: z.string().min(1),
    input: z.string(),
    voice: z.string().optional(),
  })
  .passthrough();

const NEW_RECIPE_HEADER = 'X-Sous-Is-New-Recipe';

/** Extract plain text from the last user message (handles multimodal arrays). */
function lastUserText(messages: z.infer<typeof messageSchema>[]): string {
  for (let i = messages.length - 1; i >= 0; i--) {
    const m = messages[i]!;
    if (m.role !== 'user') continue;
    if (typeof m.content === 'string') return m.content;
    if (Array.isArray(m.content)) {
      return m.content
        .map((part) =>
          part && typeof part === 'object' && typeof (part as { text?: unknown }).text === 'string'
            ? (part as { text: string }).text
            : '',
        )
        .join(' ')
        .trim();
    }
    return '';
  }
  return '';
}

/** Pick a request_type for logging from the message content. */
function requestTypeFor(messages: z.infer<typeof messageSchema>[]): RequestType {
  const hasImage = messages.some(
    (m) =>
      Array.isArray(m.content) &&
      m.content.some(
        (p) => p && typeof p === 'object' && (p as { type?: string }).type === 'image_url',
      ),
  );
  return hasImage ? 'image' : 'text';
}

interface RecordArgs {
  deps: AppDeps;
  userId: string;
  recipeId: string | null;
  requestType: RequestType;
  isNewRecipe: boolean;
  model: string | null;
  inputTokens: number | null;
  outputTokens: number | null;
  outcome: RequestOutcome;
  offTopicFlagged: boolean;
  billingPeriod: string;
  voiceTtsCharacters?: number | null;
}

async function recordUsage(a: RecordArgs): Promise<void> {
  const estimatedCostUsd = a.voiceTtsCharacters != null
    ? estimateTtsCost(a.voiceTtsCharacters)
    : estimateChatCost(a.model, a.inputTokens, a.outputTokens);
  await a.deps.repo.insertUsageEvent({
    userId: a.userId,
    recipeId: a.recipeId,
    requestType: a.requestType,
    isNewRecipe: a.isNewRecipe,
    inputTokens: a.inputTokens,
    outputTokens: a.outputTokens,
    model: a.model,
    estimatedCostUsd,
    requestOutcome: a.outcome,
    voiceTtsCharacters: a.voiceTtsCharacters ?? null,
    offTopicFlagged: a.offTopicFlagged,
    billingPeriod: a.billingPeriod,
  });
}

export function proxyRoutes(): Hono<HonoEnv> {
  const app = new Hono<HonoEnv>();
  app.use('*', authMiddleware);

  // POST /proxy/chat
  app.post('/chat', async (c) => {
    const deps = c.get('deps');
    const userId = c.get('userId');
    const period = currentBillingPeriod(deps.now());
    const recipeId = c.req.header('X-Sous-Recipe-Id') ?? null;
    const isNewRecipe = (c.req.header(NEW_RECIPE_HEADER) ?? '').toLowerCase() === 'true';

    const parsed = chatBodySchema.safeParse(await c.req.json().catch(() => null));
    if (!parsed.success) {
      return c.json({ error: 'bad_request', message: 'Invalid chat request body' }, 400);
    }
    const body = parsed.data;
    const requestType = requestTypeFor(body.messages);

    // 1. Off-topic detection on the last user message.
    const access = await resolveAccess(deps, userId);
    if (!access) return c.json({ error: 'not_found', message: 'User not found' }, 404);

    const threshold = offTopicThresholdFrom(access.rawConfig);
    const offTopic = detectOffTopic(lastUserText(body.messages), threshold);
    if (offTopic.isOffTopic) {
      await recordUsage({
        deps, userId, recipeId, requestType, isNewRecipe,
        model: body.model, inputTokens: null, outputTokens: null,
        outcome: 'validation_failure', offTopicFlagged: true, billingPeriod: period,
      });
      return c.json(
        {
          error: 'off_topic',
          message: "I'm your cooking assistant — let's keep it in the kitchen. Ask me about a recipe, technique, or ingredient.",
        },
        400,
      );
    }

    // 2. New-recipe cap enforcement (before forwarding / spending tokens).
    if (isNewRecipe) {
      const decision = await enforceNewRecipeCap(access, deps, period);
      if (!decision.allowed) {
        await recordUsage({
          deps, userId, recipeId, requestType, isNewRecipe: true,
          model: null, inputTokens: null, outputTokens: null,
          outcome: 'error', offTopicFlagged: false, billingPeriod: period,
        });
        return c.json({ error: 'cap_reached', message: decision.message }, 402);
      }
    }

    // 3. Forward to OpenAI. When streaming, ask OpenAI to include a final usage
    //    chunk so we can record token counts (the iOS SSE parser ignores it).
    const isStream = body.stream === true;
    const forwardBody = isStream
      ? { ...body, stream_options: { include_usage: true } }
      : body;

    let upstream: Response;
    try {
      upstream = await deps.openai.forwardChat(forwardBody);
    } catch {
      await recordUsage({
        deps, userId, recipeId, requestType, isNewRecipe,
        model: body.model, inputTokens: null, outputTokens: null,
        outcome: 'error', offTopicFlagged: false, billingPeriod: period,
      });
      return c.json({ error: 'upstream_error', message: 'Upstream request failed' }, 502);
    }

    const fireAbuse = () => {
      checkAbuse({
        repo: deps.repo,
        config: abuseConfigFrom(access.rawConfig),
        userId, recipeId, billingPeriod: period, now: deps.now(),
      }).catch(() => {});
    };

    // Non-200 from OpenAI: relay status + body, record an error event.
    if (upstream.status !== 200 || !upstream.body) {
      const text = await upstream.text();
      await recordUsage({
        deps, userId, recipeId, requestType, isNewRecipe,
        model: body.model, inputTokens: null, outputTokens: null,
        outcome: 'error', offTopicFlagged: false, billingPeriod: period,
      });
      return new Response(text, {
        status: upstream.status,
        headers: { 'Content-Type': upstream.headers.get('content-type') ?? 'application/json' },
      });
    }

    if (!isStream) {
      const text = await upstream.text();
      let usage = { inputTokens: null as number | null, outputTokens: null as number | null };
      try { usage = usageFromJson(JSON.parse(text)); } catch { /* leave nulls */ }
      await recordUsage({
        deps, userId, recipeId, requestType, isNewRecipe,
        model: body.model, inputTokens: usage.inputTokens, outputTokens: usage.outputTokens,
        outcome: 'success', offTopicFlagged: false, billingPeriod: period,
      });
      fireAbuse();
      return new Response(text, {
        status: 200,
        headers: { 'Content-Type': upstream.headers.get('content-type') ?? 'application/json' },
      });
    }

    // Streaming: tee bytes to the client while accumulating to parse the final
    // usage chunk, then record usage on flush.
    let acc = '';
    const decoder = new TextDecoder();
    const transform = new TransformStream<Uint8Array, Uint8Array>({
      transform(chunk, controller) {
        acc += decoder.decode(chunk, { stream: true });
        controller.enqueue(chunk);
      },
      async flush() {
        const usage = usageFromSse(acc);
        try {
          await recordUsage({
            deps, userId, recipeId, requestType, isNewRecipe,
            model: body.model, inputTokens: usage.inputTokens, outputTokens: usage.outputTokens,
            outcome: 'success', offTopicFlagged: false, billingPeriod: period,
          });
          fireAbuse();
        } catch { /* never break the stream on a recording failure */ }
      },
    });

    return new Response(upstream.body.pipeThrough(transform), {
      status: 200,
      headers: { 'Content-Type': upstream.headers.get('content-type') ?? 'text/event-stream' },
    });
  });

  // POST /proxy/tts — forward a TTS request, stream audio back, record characters.
  app.post('/tts', async (c) => {
    const deps = c.get('deps');
    const userId = c.get('userId');
    const period = currentBillingPeriod(deps.now());
    const recipeId = c.req.header('X-Sous-Recipe-Id') ?? null;

    const parsed = ttsBodySchema.safeParse(await c.req.json().catch(() => null));
    if (!parsed.success) {
      return c.json({ error: 'bad_request', message: 'Invalid TTS request body' }, 400);
    }
    const body = parsed.data;
    const characters = body.input.length;

    let upstream: Response;
    try {
      upstream = await deps.openai.forwardTTS(body);
    } catch {
      await recordUsage({
        deps, userId, recipeId, requestType: 'voice', isNewRecipe: false,
        model: body.model, inputTokens: null, outputTokens: null,
        outcome: 'error', offTopicFlagged: false, billingPeriod: period,
        voiceTtsCharacters: characters,
      });
      return c.json({ error: 'upstream_error', message: 'Upstream request failed' }, 502);
    }

    const outcome: RequestOutcome = upstream.status === 200 ? 'success' : 'error';
    await recordUsage({
      deps, userId, recipeId, requestType: 'voice', isNewRecipe: false,
      model: body.model, inputTokens: null, outputTokens: null,
      outcome, offTopicFlagged: false, billingPeriod: period,
      voiceTtsCharacters: characters,
    });

    return new Response(upstream.body, {
      status: upstream.status,
      headers: { 'Content-Type': upstream.headers.get('content-type') ?? 'audio/mpeg' },
    });
  });

  return app;
}

interface CapDecision {
  allowed: boolean;
  message: string;
}

/**
 * Decide whether a new-recipe request may proceed and, if so, increment the
 * relevant counter(s). Trial users are bound by the trial recipe cap
 * (subscriptions.trial_recipes_used); subscribers/grace by the monthly paid cap
 * (recipe_cap_counters). recipe_cap_counters is always incremented for
 * monitoring. BYOK never reaches the proxy but is treated as unlimited if it does.
 */
async function enforceNewRecipeCap(
  access: NonNullable<Awaited<ReturnType<typeof resolveAccess>>>,
  deps: AppDeps,
  period: string,
): Promise<CapDecision> {
  const userId = access.user.id;
  const status = access.entitlement.status;

  if (status === 'byok') {
    await deps.repo.incrementRecipeCapCounter(userId, period);
    return { allowed: true, message: '' };
  }

  if (status === 'trialing') {
    const cap = trialRecipeCap(access.rawConfig);
    const used = access.subscription?.trial_recipes_used ?? 0;
    if (used >= cap) {
      return { allowed: false, message: `Trial recipe limit reached (${cap}).` };
    }
    await deps.repo.incrementTrialRecipesUsed(userId);
    await deps.repo.incrementRecipeCapCounter(userId, period);
    return { allowed: true, message: '' };
  }

  if (status === 'subscriber' || status === 'grace') {
    const cap = paidRecipeCap(access.rawConfig);
    const used = await deps.repo.getRecipeCapCount(userId, period);
    if (used >= cap) {
      return { allowed: false, message: `Monthly recipe limit reached (${cap}).` };
    }
    await deps.repo.incrementRecipeCapCounter(userId, period);
    return { allowed: true, message: '' };
  }

  // soft_wall (or anything else): no access to create new recipes.
  return { allowed: false, message: 'Your trial has ended. Subscribe to keep cooking.' };
}
