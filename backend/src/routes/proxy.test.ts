// Integration tests for /api/v1/proxy/chat and /proxy/tts.
// Run: cd backend && npm test

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { buildTestApp, signInWithApple, readJson } from '../test/harness.js';
import type { OpenAIProxy } from '../lib/openai.js';

function chatBody(text: string, extra: Record<string, unknown> = {}) {
  return {
    model: 'gpt-5.4-mini',
    messages: [
      { role: 'system', content: 'You are a cooking assistant.' },
      { role: 'user', content: text },
    ],
    ...extra,
  };
}

async function authedToken(app: ReturnType<typeof buildTestApp>['app'], sub: string) {
  const { body } = await signInWithApple(app, sub);
  return body.token as string;
}

test('proxy/chat: forwards to OpenAI and records a usage event', async () => {
  const harness = buildTestApp();
  const { app, state } = harness;
  const token = await authedToken(app, 'apple-proxy-1');

  const res = await app.request('/api/v1/proxy/chat', {
    method: 'POST',
    headers: { Authorization: `Bearer ${token}`, 'content-type': 'application/json' },
    body: JSON.stringify(chatBody('How do I bake bread?')),
  });

  assert.equal(res.status, 200);
  const data = await readJson(res);
  // Body relayed verbatim from the (fake) OpenAI completion.
  assert.ok(data.choices[0].message.content.length > 0);

  assert.equal(state.usageEvents.length, 1);
  const ev = state.usageEvents[0]!;
  assert.equal(ev.request_outcome, 'success');
  assert.equal(ev.input_tokens, 100);
  assert.equal(ev.output_tokens, 50);
  assert.equal(ev.off_topic_flagged, false);
  assert.equal(ev.model, 'gpt-5.4-mini');
  assert.ok((ev.estimated_cost_usd ?? 0) > 0);
});

test('proxy/chat: new-recipe request is allowed but does NOT increment counters', async () => {
  // Counting is deferred to POST /usage/recipe (fired when the client confirms a
  // recipe was actually created). The proxy only enforces the cap read-only.
  const harness = buildTestApp();
  const { app, state } = harness;
  const token = await authedToken(app, 'apple-proxy-2');

  const res = await app.request('/api/v1/proxy/chat', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${token}`,
      'content-type': 'application/json',
      'X-Sous-Is-New-Recipe': 'true',
    },
    body: JSON.stringify(chatBody('Make me a lasagna recipe')),
  });

  assert.equal(res.status, 200);
  // Proxy must not mutate counters — that is /usage/recipe's job.
  assert.equal(state.subscriptions[0]!.trial_recipes_used, 0);
  assert.equal(state.recipeCapCounters.length, 0);
  // But the call is still recorded as a usage event flagged new-recipe.
  assert.equal(state.usageEvents[0]!.is_new_recipe, true);
});

test('proxy/chat: returns 402 cap_reached when trial recipe cap is hit', async () => {
  const harness = buildTestApp();
  const { app, state } = harness;
  const token = await authedToken(app, 'apple-proxy-3');

  // Drive the trial usage to the cap (default trial_recipe_cap = 14).
  state.subscriptions[0]!.trial_recipes_used = 14;

  const res = await app.request('/api/v1/proxy/chat', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${token}`,
      'content-type': 'application/json',
      'X-Sous-Is-New-Recipe': 'true',
    },
    body: JSON.stringify(chatBody('Another recipe please')),
  });

  assert.equal(res.status, 402);
  const data = await readJson(res);
  assert.equal(data.error, 'cap_reached');
  // The blocked request is logged (model null distinguishes it from upstream errors).
  const blocked = state.usageEvents.find((e) => e.request_outcome === 'error');
  assert.ok(blocked);
  assert.equal(blocked!.is_new_recipe, true);
  assert.equal(blocked!.model, null);
});

test('proxy/chat: blocks an off-topic message with 400 and logs it', async () => {
  const harness = buildTestApp();
  const { app, state } = harness;
  const token = await authedToken(app, 'apple-proxy-4');

  const res = await app.request('/api/v1/proxy/chat', {
    method: 'POST',
    headers: { Authorization: `Bearer ${token}`, 'content-type': 'application/json' },
    body: JSON.stringify(chatBody('Write me a Python function to sort a list')),
  });

  assert.equal(res.status, 400);
  const data = await readJson(res);
  assert.equal(data.error, 'off_topic');

  assert.equal(state.usageEvents.length, 1);
  assert.equal(state.usageEvents[0]!.off_topic_flagged, true);
  assert.equal(state.usageEvents[0]!.request_outcome, 'validation_failure');
});

test('proxy/chat: streaming response is relayed and usage recorded from final chunk', async () => {
  // Fake OpenAI that streams SSE including a final usage chunk.
  const streamingOpenAI: OpenAIProxy = {
    async forwardChat() {
      const sse = [
        'data: {"choices":[{"delta":{"content":"Hello"}}]}\n\n',
        'data: {"choices":[{"delta":{"content":" world"}}]}\n\n',
        'data: {"choices":[],"usage":{"prompt_tokens":200,"completion_tokens":80}}\n\n',
        'data: [DONE]\n\n',
      ].join('');
      const stream = new ReadableStream<Uint8Array>({
        start(controller) {
          controller.enqueue(new TextEncoder().encode(sse));
          controller.close();
        },
      });
      return new Response(stream, {
        status: 200,
        headers: { 'Content-Type': 'text/event-stream' },
      });
    },
    async forwardTTS() {
      return new Response(null, { status: 200 });
    },
  };

  const harness = buildTestApp({}, { openai: streamingOpenAI });
  const { app, state } = harness;
  const token = await authedToken(app, 'apple-proxy-5');

  const res = await app.request('/api/v1/proxy/chat', {
    method: 'POST',
    headers: { Authorization: `Bearer ${token}`, 'content-type': 'application/json' },
    body: JSON.stringify(chatBody('How do I make pasta?', { stream: true })),
  });

  assert.equal(res.status, 200);
  const text = await res.text(); // fully drains the stream → flush() runs
  assert.ok(text.includes('Hello'));
  assert.ok(text.includes('world'));

  assert.equal(state.usageEvents.length, 1);
  assert.equal(state.usageEvents[0]!.input_tokens, 200);
  assert.equal(state.usageEvents[0]!.output_tokens, 80);
  assert.equal(state.usageEvents[0]!.request_outcome, 'success');
});

test('proxy/chat: rejects a malformed body with 400', async () => {
  const harness = buildTestApp();
  const { app } = harness;
  const token = await authedToken(app, 'apple-proxy-6');

  const res = await app.request('/api/v1/proxy/chat', {
    method: 'POST',
    headers: { Authorization: `Bearer ${token}`, 'content-type': 'application/json' },
    body: JSON.stringify({ messages: [] }), // missing model, empty messages
  });
  assert.equal(res.status, 400);
});

test('proxy/tts: forwards audio and records voice usage', async () => {
  const harness = buildTestApp();
  const { app, state } = harness;
  const token = await authedToken(app, 'apple-proxy-7');

  const res = await app.request('/api/v1/proxy/tts', {
    method: 'POST',
    headers: { Authorization: `Bearer ${token}`, 'content-type': 'application/json' },
    body: JSON.stringify({ model: 'tts-1', input: 'Stir the pot gently.', voice: 'alloy' }),
  });

  assert.equal(res.status, 200);
  assert.equal(state.usageEvents.length, 1);
  const ev = state.usageEvents[0]!;
  assert.equal(ev.request_type, 'voice');
  assert.equal(ev.voice_tts_characters, 'Stir the pot gently.'.length);
  assert.equal(ev.request_outcome, 'success');
});

test('proxy/chat: requires auth', async () => {
  const { app } = buildTestApp();
  const res = await app.request('/api/v1/proxy/chat', {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify(chatBody('hi')),
  });
  assert.equal(res.status, 401);
});
