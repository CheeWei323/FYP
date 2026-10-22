import assert from "node:assert/strict";
import test from "node:test";
import {
  generatePackingWithFallback,
  isTemporaryGeminiError,
} from "./packing_generation.mjs";

const primary = "gemini-3.1-flash-lite";
const fallback = "gemini-3.5-flash-lite";
const capacityError = () => Object.assign(new Error("High demand"), { status: 503 });

function fixture(outcomes) {
  const calls = [];
  const waits = [];
  const warnings = [];
  const request = {
    contents: "Synthetic packing request",
    config: {
      responseMimeType: "application/json",
      responseSchema: { type: "object", required: ["items"] },
      httpOptions: { timeout: 45000, retryOptions: { attempts: 5 } },
    },
  };
  return {
    calls,
    waits,
    warnings,
    request,
    run: (options = {}) =>
      generatePackingWithFallback({
        ai: {
          models: {
            async generateContent(call) {
              calls.push(call);
              const result = outcomes[calls.length - 1];
              if (result instanceof Error) throw result;
              return result;
            },
          },
        },
        request,
        wait: async (milliseconds) => waits.push(milliseconds),
        warn: (message) => warnings.push(message),
        ...options,
      }),
  };
}

test("Return a primary success without changing the request or schema", async () => {
  const response = { text: '{"items":[]}' };
  const f = fixture([response]);
  assert.equal(await f.run(), response);
  assert.deepEqual(f.calls.map((call) => call.model), [primary]);
  assert.equal(f.calls[0].contents, f.request.contents);
  assert.equal(f.calls[0].config.responseSchema, f.request.config.responseSchema);
  assert.equal(f.calls[0].config.responseMimeType, "application/json");
  assert.equal(f.calls[0].config.httpOptions.timeout, 45000);
  assert.equal(f.calls[0].config.httpOptions.retryOptions.attempts, 1);
  assert.equal(f.request.config.httpOptions.retryOptions.attempts, 5);
  assert.deepEqual(f.waits, []);
});

test("Use the second model after a primary 503", async () => {
  const response = { text: '{"items":[]}' };
  const f = fixture([capacityError(), response]);
  assert.equal(await f.run(), response);
  assert.deepEqual(f.calls.map((call) => call.model), [primary, fallback]);
  assert.deepEqual(f.waits, [2000]);
  assert.equal(f.warnings.length, 1);
  assert.equal(f.calls[1].config.responseSchema, f.request.config.responseSchema);
});

test("Retry a busy fallback once and then return its response", async () => {
  const response = { text: '{"items":[]}' };
  const f = fixture([capacityError(), capacityError(), response]);
  assert.equal(await f.run(), response);
  assert.deepEqual(f.calls.map((call) => call.model), [primary, fallback, fallback]);
  assert.deepEqual(f.waits, [2000, 4000]);
  assert.ok(f.calls.every((call) => call.config.httpOptions.retryOptions.attempts === 1));
});

test("Stop after three capacity failures and preserve the final error", async () => {
  const lastError = capacityError();
  const f = fixture([capacityError(), capacityError(), lastError]);
  await assert.rejects(f.run(), (error) => error === lastError);
  assert.equal(f.calls.length, 3);
  assert.deepEqual(f.waits, [2000, 4000]);
});

for (const status of [400, 402, 403, 429, 500]) {
  test(`Do not retry or switch models for HTTP ${status}`, async () => {
    const failure = Object.assign(new Error("Request unavailable"), { status });
    const f = fixture([failure]);
    await assert.rejects(f.run(), (error) => error === failure);
    assert.equal(f.calls.length, 1);
    assert.deepEqual(f.waits, []);
  });
}

test("Support configured model names while retaining the three-call bound", async () => {
  const f = fixture([capacityError(), { text: "ok" }]);
  await f.run({ primaryModel: " primary-model ", fallbackModel: " backup-model " });
  assert.deepEqual(f.calls.map((call) => call.model), ["primary-model", "backup-model"]);
});

test("Recognize wrapped 503 errors without misclassifying other failures", () => {
  assert.equal(isTemporaryGeminiError({ status: "503" }), true);
  assert.equal(isTemporaryGeminiError(new Error('{"error":{"code":503}}')), true);
  assert.equal(isTemporaryGeminiError(new Error('{"status":"UNAVAILABLE"}')), true);
  assert.equal(isTemporaryGeminiError({ status: 403, message: "UNAVAILABLE 503" }), false);
  assert.equal(isTemporaryGeminiError(new Error("Invalid schema on line 503")), false);
});
