import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { once } from 'node:events';
import { existsSync } from 'node:fs';
import { readFile, mkdir, writeFile } from 'node:fs/promises';
import { registerHooks } from 'node:module';
import { platform, release, arch } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { configure, newContext, fixtureTokens, expectedOverview, sensitiveMarkers } from './controlled_dependencies.mjs';

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
  { id: 'API06', title: 'Restricted analytics access', expected: 'A fixture Traveller receives only the predefined 403 error before dataset loading. An Analyst comparison receives the fixed 200 aggregate.' },
  { id: 'API07', title: 'Aggregate response privacy', expected: 'All seven analytics selections return 200 with only their permitted response fields, no private canaries, no-store and nosniff headers, and the fixed aggregate checks.' },
  { id: 'API08', title: 'Storage failure response privacy', expected: 'Injected role-read and dataset-load failures each return only the predefined 503 error. Error logs contain only fixed error codes. No private canaries appear in responses or logs. A permitted comparison receives 200.' },
  { id: 'API09', title: 'Authentication failure response privacy', expected: 'Injected invalid-token and verifier-service failures return only their respective predefined 401 and 503 errors before any storage read. No private canaries appear in responses. An Analyst comparison receives 200.' },
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
line('TRAVELGUARD MY - LOCAL API PRIVACY BATCH B');
line('Run: ' + runId + ' | ' + localTime + ' Asia/Kuala_Lumpur');
line('Node ' + process.version + ' | Express ' + dependencyVersions.express + ' | ' + platform() + ' ' + arch());
line('Actual backend, authentication middleware, analytics route and aggregate builder.');
line('Substituted: token verifier, stored records and external services.');
line('Fictional private data and dependency failures only. Target: localhost.');

function assertPrivateAbsent(value, label) {
  const text = JSON.stringify(value);
  for (const marker of sensitiveMarkers) {
    assert.ok(!text.includes(marker), label + ' must not contain private marker: ' + marker);
  }
}

function keys(value, expected, label) {
  assert.ok(value && typeof value === 'object' && !Array.isArray(value), label + ' must be an object.');
  assert.deepEqual(Object.keys(value).sort(), [...expected].sort(), label + ' field contract.');
}

function rows(value, allowed, label) {
  assert.ok(Array.isArray(value), label + ' must be an array.');
  for (const row of value) keys(row, allowed, label);
}

// Independent response-field contracts, not a second invocation of buildAnalytics.
function assertAggregateContract(metric, data) {
  if (metric === 'countries') {
    rows(data, ['id', 'name'], metric);
    assert.equal(data.length, 5);
  } else if (metric === 'overview') {
    assert.deepEqual(data, expectedOverview);
  } else if (metric === 'destinations') {
    rows(data, ['countryId', 'name', 'count', 'percentage'], metric);
    assert.equal(data.reduce((sum, row) => sum + row.count, 0), 3);
    assert.equal(data.find((row) => row.countryId === 'japan').count, 2);
  } else if (metric === 'monthly') {
    rows(data, ['year', 'month', 'label', 'shortLabel', 'count'], metric);
    assert.equal(data.length, 1);
    assert.equal(data[0].year, 2026);
    assert.equal(data[0].month, 11);
    assert.equal(data[0].count, 3);
  } else if (metric === 'purpose') {
    keys(data, ['total', 'counts'], metric);
    assert.deepEqual(data, { total: 3, counts: { tourism: 1, business: 1, study: 1 } });
  } else if (metric === 'completion') {
    keys(data, ['overallCompletionRate', 'completedChecklistItems', 'incompleteChecklistItems',
      'totalChecklistItems', 'tripsWithChecklist', 'destinationComparison',
      'purposeComparison', 'requirementsNeedingAttention'], metric);
    assert.equal(data.totalChecklistItems, 4);
    assert.equal(data.completedChecklistItems, 2);
    assert.equal(data.tripsWithChecklist, 3);
    assert.equal(data.overallCompletionRate, 50);
    rows(data.destinationComparison, ['countryId', 'name', 'tripCount', 'completionRate'], 'completion destinations');
    rows(data.purposeComparison, ['purpose', 'tripCount', 'completionRate'], 'completion purposes');
    rows(data.requirementsNeedingAttention,
      ['sourceRuleId', 'title', 'generated', 'completed', 'incomplete', 'completionRate'], 'completion requirements');
    assert.equal(data.requirementsNeedingAttention.length, 2);
  } else if (metric === 'requirements') {
    keys(data, ['analysedTrips', 'requirementPatterns'], metric);
    assert.equal(data.analysedTrips, 3);
    rows(data.requirementPatterns,
      ['requirementKey', 'title', 'tripCount', 'percentage', 'destinationBreakdown', 'purposeBreakdown'], metric);
    assert.equal(data.requirementPatterns.length, 2);
    for (const row of data.requirementPatterns) {
      rows(row.destinationBreakdown, ['countryId', 'name', 'tripCount'], 'requirement destinations');
      rows(row.purposeBreakdown, ['purpose', 'tripCount'], 'requirement purposes');
    }
  }
}

async function withServer(id, action) {
  const ctx = newContext(id);
  const savedLog = console.log;
  const savedError = console.error;
  console.error = (...values) => ctx.errorLogs.push(values.map(String).join(' '));
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
    assertPrivateAbsent(observed, 'HTTP response');
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
    return { ...result, requests: ctx.requests, errorLogs: ctx.errorLogs, counters: { verificationCalls: ctx.verificationCalls, roleReads: ctx.roleReads, datasetLoads: ctx.datasetLoads, providerCalls: ctx.providerCalls } };
  } catch (error) {
    error.testEvidence = { requests: ctx.requests, errorLogs: ctx.errorLogs, counters: { verificationCalls: ctx.verificationCalls, roleReads: ctx.roleReads, datasetLoads: ctx.datasetLoads, providerCalls: ctx.providerCalls } };
    throw error;
  } finally {
    console.error = savedError;
    ctx.server.closeAllConnections();
    await new Promise((done, reject) => ctx.server.close((error) => error ? reject(error) : done()));
  }
}

const implementations = {
  API06: async ({ ctx, request, control }) => {
    const result = await request({ metric: 'overview' }, 'Bearer ' + fixtureTokens.traveller);
    assert.equal(result.status, 403);
    assert.deepEqual(result.body, { error: 'This feature is available to Tourism Data Analysts only.' });
    assert.equal(ctx.verificationCalls, 1);
    assert.equal(ctx.roleReads, 1);
    assert.equal(ctx.datasetLoads, 0);
    await control();
    return { observations: 'Traveller: 403 | dataset loads: 0 before control | Analyst: 200 | private markers: absent' };
  },
  API07: async ({ ctx, request }) => {
    const selections = ['countries', 'overview', 'destinations', 'monthly', 'purpose', 'completion', 'requirements'];
    for (const metric of selections) {
      const result = await request({ metric });
      assert.equal(result.status, 200);
      keys(result.body, ['data'], 'HTTP body');
      assertAggregateContract(metric, result.body.data);
      assert.equal(result.headers['cache-control'], 'no-store');
      assert.equal(result.headers['x-content-type-options'], 'nosniff');
    }
    assert.equal(ctx.datasetLoads, 7);
    return { observations: '7 selections: 200 | field contracts and aggregate checks: PASS | private markers: absent | no-store: 7/7' };
  },
  API08: async ({ ctx, request, control }) => {
    ctx.roleFailure = true;
    const roleFailure = await request({ metric: 'overview' });
    assert.equal(roleFailure.status, 503);
    assert.deepEqual(roleFailure.body, { error: 'Analytics is temporarily unavailable. Please try again.' });
    assert.equal(ctx.datasetLoads, 0);
    ctx.roleFailure = false;
    ctx.datasetFailure = true;
    const datasetFailure = await request({ metric: 'overview' });
    assert.equal(datasetFailure.status, 503);
    assert.deepEqual(datasetFailure.body, { error: 'Analytics is temporarily unavailable. Please try again.' });
    assert.equal(ctx.datasetLoads, 1);
    assert.deepEqual(ctx.errorLogs, ['ANALYTICS ERROR: permission-denied', 'ANALYTICS ERROR: unavailable']);
    assertPrivateAbsent(ctx.errorLogs, 'Error logs');
    ctx.datasetFailure = false;
    await control();
    return { observations: 'Role/dataset failures: 503/503 | exact safe responses | logs: error codes only | permitted control: 200' };
  },
  API09: async ({ ctx, request, control }) => {
    const invalid = await request({ metric: 'overview' }, 'Bearer ' + fixtureTokens.rejected);
    assert.equal(invalid.status, 401);
    assert.deepEqual(invalid.body, { error: 'Your session is invalid or expired. Please sign in again.' });
    const unavailable = await request({ metric: 'overview' }, 'Bearer ' + fixtureTokens.unavailable);
    assert.equal(unavailable.status, 503);
    assert.deepEqual(unavailable.body, { error: 'Sign-in verification is temporarily unavailable. Please try again.' });
    assert.equal(ctx.verificationCalls, 2);
    assert.equal(ctx.roleReads, 0);
    assert.equal(ctx.datasetLoads, 0);
    await control();
    return { observations: 'Invalid/unavailable verifier: 401/503 | exact safe responses | storage: 0 before control | permitted control: 200' };
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
  scope: { actualApplication: join(backend, 'server.mjs'), endpoint: 'POST /api/analytics/query', connection: 'loopback only', substitutions: ['dotenv startup', 'token verifier and its controlled failures', 'stored roles and canary-bearing fictional records', 'role-read and dataset-load failures', 'Google AI client', 'travel provider calls'], claimsExcluded: ['Firebase token cryptography or actual outages', 'production Firestore rules or field projections', 'all endpoint privacy or reidentification resistance', 'hosted deployment security', 'performance or concurrent capacity'] },
  fixture: { expectedOverview, privateMarkers: 'Fictional values only, defined in controlled_dependencies.mjs', completion: { totalItems: 4, completed: 2, tripsWithChecklist: 3, averageRate: 50 } },
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
