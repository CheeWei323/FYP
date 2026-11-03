import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { once } from 'node:events';
import { existsSync } from 'node:fs';
import { readFile, mkdir, writeFile } from 'node:fs/promises';
import { registerHooks } from 'node:module';
import { platform, release, arch } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { configure, newContext, fixtureTokens, expectedOverview } from './controlled_dependencies.mjs';

const here = dirname(fileURLToPath(import.meta.url));
const options = { project: undefined, out: join(here, 'runs') };
for (let i = 2; i < process.argv.length; i += 2) {
  const key = process.argv[i]?.replace(/^--/, '');
  if (!['project', 'out'].includes(key) || !process.argv[i + 1]) {
    throw new Error('Use --project PATH and/or --out PATH.');
  }
  options[key] = resolve(process.argv[i + 1]);
}

function findProject(start) {
  let candidate = resolve(start);
  while (true) {
    if (existsSync(join(candidate, 'backend', 'server.mjs')) &&
        existsSync(join(candidate, 'backend', 'package.json'))) return candidate;
    const parent = dirname(candidate);
    if (parent === candidate) return undefined;
    candidate = parent;
  }
}
options.project ??= findProject(here) ?? findProject(process.cwd());
if (!options.project || !existsSync(join(options.project, 'backend', 'server.mjs'))) {
  throw new Error('Open a terminal in the FYP project or pass --project PATH.');
}

const started = new Date();
const runId = started.toISOString().replace(/[:.]/g, '-') + '-' + process.pid;
const output = join(options.out, runId);
await mkdir(output, { recursive: true });
const transcript = [];
function line(value = '') {
  transcript.push(String(value));
  process.stdout.write(String(value) + '\n');
}

const plan = [
  { id: 'API01', title: 'Missing and malformed authentication headers', expected: 'Three 401 decisions before verification/storage; authorized control 200.' },
  { id: 'API02', title: 'Malformed JSON rejection', expected: '400 with the predefined JSON error before verification/storage; authorized control 200.' },
  { id: 'API03', title: 'Oversized body rejection', expected: '413 with the predefined size error before verification/storage; authorized control 200.' },
  { id: 'API04', title: 'Unexpected fields and unsafe filter rejection', expected: 'Two 400 decisions before dataset loading; authorized control 200.' },
  { id: 'API05', title: 'Configured per-user request limit', expected: 'First 60 valid requests 200, request 61 429 with Retry-After and no extra dataset load; different-identity control 200.' },
];
await writeFile(join(output, 'plan.json'), JSON.stringify({ createdBeforeExecution: true, preparedDate: '2026-10-31', cases: plan }, null, 2));

const backend = join(options.project, 'backend');
const sourceNames = ['server.mjs', 'firebase_auth.mjs', 'analytics_routes.mjs', 'analytics_store.mjs', 'analytics.mjs', 'travel_routes.mjs', 'packing_generation.mjs'];
async function fingerprints() {
  const entries = await Promise.all(sourceNames.map(async (name) => [name, createHash('sha256').update(await readFile(join(backend, name))).digest('hex')]));
  return Object.fromEntries(entries);
}
const before = await fingerprints();
const dependencyVersions = await configure(options.project);

// This process uses only public fixture values. dotenv is replaced below.
process.env.PORT = '0';
process.env.GEMINI_API_KEY = 'fixture-gemini-key';
process.env.FIREBASE_PROJECT_ID = 'demo-travelguard-local-api';
process.env.GOOGLE_MAPS_SERVER_KEY = 'fixture-google-key';
delete process.env.GOOGLE_APPLICATION_CREDENTIALS;
delete process.env.FIRESTORE_EMULATOR_HOST;

const serverUrl = pathToFileURL(join(backend, 'server.mjs')).href;
const dependenciesUrl = new URL('./controlled_dependencies.mjs', import.meta.url).href;
const replacements = new Set(['dotenv/config', 'express', '@google/genai', './analytics_routes.mjs', './travel_routes.mjs', './firebase_auth.mjs']);
const hooks = registerHooks({
  resolve(specifier, context, nextResolve) {
    if (context.parentURL) {
      const parent = new URL(context.parentURL);
      parent.search = '';
      if (parent.href === serverUrl && replacements.has(specifier)) {
        return { url: dependenciesUrl, shortCircuit: true };
      }
    }
    return nextResolve(specifier, context);
  },
});

const realFetch = globalThis.fetch.bind(globalThis);
let blockedExternalRequests = 0;
globalThis.fetch = (target, init) => {
  const url = new URL(typeof target === 'string' || target instanceof URL ? target : target.url);
  if (url.protocol !== 'http:' || url.hostname !== '127.0.0.1') {
    blockedExternalRequests++;
    throw new Error('Only loopback HTTP is permitted by this test runner.');
  }
  return realFetch(target, init);
};

const localTime = new Intl.DateTimeFormat('en-GB', { timeZone: 'Asia/Kuala_Lumpur', dateStyle: 'medium', timeStyle: 'medium' }).format(started);
line('TRAVELGUARD MY - LOCAL API SECURITY BATCH A');
line('Run: ' + runId + ' | ' + localTime + ' Asia/Kuala_Lumpur');
line('Node ' + process.version + ' | Express ' + dependencyVersions.express + ' | ' + platform() + ' ' + arch());
line('Actual server.mjs, JSON parser, error handler, auth middleware and analytics route.');
line('Substituted: token verifier, stored records and external services.');
line('Target: localhost only. This is not a live Firebase or hosted-provider test.');

async function withServer(id, action) {
  const ctx = newContext(id);
  const savedLog = console.log;
  try {
    console.log = () => {};
    await import(serverUrl + '?securityCase=' + id + '-' + runId);
    assert.ok(ctx.server, 'The actual server must start through the constrained listener.');
    if (!ctx.server.listening) await once(ctx.server, 'listening');
  } finally {
    console.log = savedLog;
  }
  const address = ctx.server.address();
  assert.equal(address.address, '127.0.0.1');
  const endpoint = `http://127.0.0.1:${address.port}/api/analytics/query`;
  async function request(body, authorization = 'Bearer ' + fixtureTokens.analystA, raw = false) {
    const response = await fetch(endpoint, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', ...(authorization ? { Authorization: authorization } : {}) },
      body: raw ? body : JSON.stringify(body),
      signal: AbortSignal.timeout(10_000),
    });
    const text = await response.text();
    let data;
    try { data = JSON.parse(text); } catch { data = text; }
    const observed = { status: response.status, body: data, headers: Object.fromEntries(response.headers) };
    ctx.requests.push(observed);
    return observed;
  }
  async function control(token = fixtureTokens.analystA) {
    const result = await request({ metric: 'overview' }, 'Bearer ' + token);
    assert.equal(result.status, 200);
    assert.deepEqual(result.body, { data: expectedOverview });
    return result;
  }
  try {
    const result = await action({ ctx, request, control });
    assert.equal(ctx.providerCalls, 0, 'No provider operation is part of this batch.');
    return { ...result, requests: ctx.requests, counters: { verificationCalls: ctx.verificationCalls, roleReads: ctx.roleReads, datasetLoads: ctx.datasetLoads, providerCalls: ctx.providerCalls } };
  } catch (error) {
    error.testEvidence = { requests: ctx.requests, counters: { verificationCalls: ctx.verificationCalls, roleReads: ctx.roleReads, datasetLoads: ctx.datasetLoads, providerCalls: ctx.providerCalls } };
    throw error;
  } finally {
    ctx.server.closeAllConnections();
    await new Promise((done, reject) => ctx.server.close((error) => error ? reject(error) : done()));
  }
}

const implementations = {
  API01: async ({ ctx, request, control }) => {
    const statuses = [];
    for (const header of [null, 'Basic public-fixture', 'Bearer']) {
      const result = await request({ metric: 'overview' }, header);
      assert.equal(result.status, 401);
      assert.deepEqual(result.body, { error: 'Please sign in to continue.' });
      statuses.push(result.status);
    }
    assert.equal(ctx.verificationCalls, 0);
    assert.equal(ctx.roleReads, 0);
    assert.equal(ctx.datasetLoads, 0);
    await control();
    return { observations: `Missing/Basic/Bearer-only: ${statuses.join('/')} | verification/storage: 0 before control | permitted control: 200` };
  },
  API02: async ({ ctx, request, control }) => {
    const result = await request('{"metric":', 'Bearer ' + fixtureTokens.analystA, true);
    assert.equal(result.status, 400);
    assert.deepEqual(result.body, { error: 'The request body must contain valid JSON.' });
    assert.equal(ctx.verificationCalls, 0);
    assert.equal(ctx.datasetLoads, 0);
    await control();
    return { observations: 'Truncated JSON: 400 | exact safe error | verification/storage: 0 before control | permitted control: 200' };
  },
  API03: async ({ ctx, request, control }) => {
    const body = JSON.stringify({ metric: 'overview', padding: 'x'.repeat(17 * 1024) });
    assert.ok(Buffer.byteLength(body) > 16 * 1024);
    const result = await request(body, 'Bearer ' + fixtureTokens.analystA, true);
    assert.equal(result.status, 413);
    assert.deepEqual(result.body, { error: 'The request is too large.' });
    assert.equal(ctx.verificationCalls, 0);
    assert.equal(ctx.datasetLoads, 0);
    await control();
    return { observations: `Body ${Buffer.byteLength(body)} bytes (>16 KB): 413 | exact safe error | storage: 0 before control | permitted control: 200` };
  },
  API04: async ({ ctx, request, control }) => {
    const bodies = [
      { metric: 'overview', collection: 'users' },
      { metric: 'overview', destinationId: 'japan/../../users' },
    ];
    const statuses = [];
    for (const body of bodies) {
      const result = await request(body);
      assert.equal(result.status, 400);
      assert.deepEqual(result.body, { error: 'Select a valid analytics type and filters.' });
      statuses.push(result.status);
    }
    assert.equal(ctx.datasetLoads, 0);
    await control();
    return { observations: `Unexpected collection / unsafe destination: ${statuses.join('/')} | dataset loads: 0 before control | permitted control: 200` };
  },
  API05: async ({ ctx, request, control }) => {
    const startedBurst = Date.now();
    for (let index = 1; index <= 60; index++) await control();
    const limited = await request({ metric: 'overview' });
    assert.ok(Date.now() - startedBurst < 60_000, 'The request burst must remain within the actual 60-second window.');
    assert.equal(limited.status, 429);
    const retryAfter = Number(limited.headers['retry-after']);
    assert.ok(Number.isFinite(retryAfter) && retryAfter > 0 && retryAfter <= 60, 'The rejection must advertise its retry interval.');
    assert.equal(ctx.datasetLoads, 60);
    await control(fixtureTokens.analystB);
    assert.equal(ctx.datasetLoads, 61);
    return { observations: `Same identity: 60 x 200; request 61: 429 | Retry-After: ${retryAfter}s | limited request: no dataset load | other identity: 200` };
  },
};

const cases = [];
try {
  for (const item of plan) {
    line();
    line(item.id + ' - ' + item.title);
    try {
      const observed = await withServer(item.id, implementations[item.id]);
      cases.push({ ...item, status: 'Pass', ...observed });
      line('Observed: ' + observed.observations);
      line('RESULT: PASS');
    } catch (error) {
      cases.push({ ...item, status: 'Fail', ...error.testEvidence, error: { name: error.name, message: error.message, stack: error.stack } });
      line('RESULT: FAIL - ' + error.message);
    }
  }
} finally {
  hooks.deregister();
  globalThis.fetch = realFetch;
}

const after = await fingerprints();
const sourceUnchanged = JSON.stringify(before) === JSON.stringify(after);
const passed = cases.filter((item) => item.status === 'Pass').length;
const failed = cases.length - passed;
const networkIsolated = blockedExternalRequests === 0 && cases.every((item) => item.counters?.providerCalls === 0);
const report = {
  runId,
  startedAtUtc: started.toISOString(),
  startedAtAsiaKualaLumpur: localTime,
  finishedAtUtc: new Date().toISOString(),
  environment: { node: process.version, platform: platform(), release: release(), arch: arch(), dependencies: dependencyVersions },
  scope: { actualApplication: join(backend, 'server.mjs'), endpoint: 'POST /api/analytics/query', connection: 'loopback only', substitutions: ['dotenv startup', 'token verifier', 'stored roles and records', 'Google AI client', 'travel provider calls'], claimsExcluded: ['Firebase token cryptography', 'production Firestore rules', 'hosted deployment security', 'concurrent capacity or rate-window reset'] },
  fixture: { expectedOverview },
  sourceFingerprintsBefore: before,
  sourceFingerprintsAfter: after,
  sourceUnchanged,
  blockedExternalRequests,
  networkIsolated,
  cases,
  summary: { reportedCases: cases.length, passed, failed, httpRequests: cases.reduce((count, item) => count + (item.requests?.length ?? 0), 0) },
};
await writeFile(join(output, 'results.json'), JSON.stringify(report, null, 2));
line();
line(`SUMMARY: ${cases.length} reported cases | ${passed} PASS | ${failed} FAIL`);
line('Application source unchanged: ' + (sourceUnchanged ? 'YES' : 'NO'));
line('External service operations: ' + (networkIsolated ? 'NONE' : 'CHECK RESULTS'));
line('These are controlled local API results, not hosted-service or capacity results.');
line('Saved evidence: ' + output);
await writeFile(join(output, 'execution.log'), transcript.join('\n') + '\n');
if (failed || !sourceUnchanged || !networkIsolated) process.exitCode = 1;
