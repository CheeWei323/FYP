import { createRequire } from 'node:module';
import { readFile } from 'node:fs/promises';
import { join } from 'node:path';
import { pathToFileURL } from 'node:url';

let realExpress;
let realCreateAuth;
let realCreateAnalyticsRouter;
let realCreateTravelRouter;
let activeContext;

export const fixtureTokens = Object.freeze({
  analystA: 'fixture-privacy-analyst-a',
  traveller: 'fixture-privacy-traveller-a',
  rejected: 'fixture-privacy-invalid-token',
  unavailable: 'fixture-privacy-verifier-unavailable',
});

// Public test values only. No environment file or live account is read.
export const sensitiveMarkers = Object.freeze([
  'PRIVATE_TRIP_ALPHA_729', 'PRIVATE_TRIP_BETA_729', 'PRIVATE_TRIP_GAMMA_729',
  'PRIVATE_PERSON_ALPHA_729', 'PRIVATE_PERSON_BETA_729',
  'PRIVATE_NAME_729', 'privacy-canary-729@example.invalid',
  'PRIVATE_PASSPORT_729', 'PRIVATE_NOTE_729', 'PRIVATE_ITEM_TEXT_729',
  'PRIVATE_CREDENTIAL_729', 'PRIVATE_STACK_729',
  'C:/private-fixture-729/service-account.json',
  ...Object.values(fixtureTokens),
]);

export const expectedOverview = Object.freeze({
  totalTrips: 3,
  uniqueTravellers: 2,
  topDestination: 'Japan',
  topDestinationTrips: 2,
  supportedDestinations: 5,
});

const privateFields = {
  fullName: 'PRIVATE_NAME_729',
  email: 'privacy-canary-729@example.invalid',
  passportNumber: 'PRIVATE_PASSPORT_729',
  notes: 'PRIVATE_NOTE_729',
};
const item = (sourceRuleId, completed) => ({
  sourceRuleId, completed, title: 'PRIVATE_ITEM_TEXT_729',
  userId: 'PRIVATE_PERSON_ALPHA_729', ...privateFields,
});
const records = {
  countries: [
    { id: 'japan', name: 'Japan' },
    { id: 'australia', name: 'Australia' },
    { id: 'south_korea', name: 'South Korea' },
    { id: 'united_states', name: 'United States' },
    { id: 'united_kingdom', name: 'United Kingdom' },
  ],
  rules: [
    { id: 'rule_passport', title: 'Passport requirement' },
    { id: 'rule_visa', title: 'Visa requirement' },
  ],
  trips: [
    { id: 'PRIVATE_TRIP_ALPHA_729', userId: 'PRIVATE_PERSON_ALPHA_729',
      destinationCountryId: 'japan', purpose: 'tourism', departureDate: '2026-11-06T00:00:00Z',
      ...privateFields, items: [item('rule_passport', true), item('rule_visa', false)] },
    { id: 'PRIVATE_TRIP_BETA_729', userId: 'PRIVATE_PERSON_ALPHA_729',
      destinationCountryId: 'japan', purpose: 'business', departureDate: '2026-11-07T00:00:00Z',
      ...privateFields, items: [item('rule_passport', false)] },
    { id: 'PRIVATE_TRIP_GAMMA_729', userId: 'PRIVATE_PERSON_BETA_729',
      destinationCountryId: 'australia', purpose: 'study', departureDate: '2026-11-08T00:00:00Z',
      ...privateFields, items: [item('rule_passport', true)] },
  ],
};

export async function configure(projectRoot) {
  const backend = join(projectRoot, 'backend');
  const requireBackend = createRequire(join(backend, 'package.json'));
  realExpress = requireBackend('express');
  Object.assign(controlledExpress, realExpress);
  [
    { createFirebaseAuth: realCreateAuth },
    { createAnalyticsRouter: realCreateAnalyticsRouter },
    { createTravelRouter: realCreateTravelRouter },
  ] = await Promise.all([
    import(pathToFileURL(join(backend, 'firebase_auth.mjs')).href),
    import(pathToFileURL(join(backend, 'analytics_routes.mjs')).href),
    import(pathToFileURL(join(backend, 'travel_routes.mjs')).href),
  ]);
  return {
    express: requireBackend('express/package.json').version,
    firebaseAdmin: JSON.parse(await readFile(join(backend, 'node_modules', 'firebase-admin', 'package.json'), 'utf8')).version,
  };
}

export function newContext(caseId) {
  activeContext = {
    caseId, server: undefined, verificationCalls: 0, roleReads: 0,
    datasetLoads: 0, providerCalls: 0, requests: [], errorLogs: [],
    roleFailure: false, datasetFailure: false,
  };
  return activeContext;
}

function context() {
  if (!activeContext) throw new Error('Set the test context before starting the app.');
  return activeContext;
}

function privateFailure(code) {
  const error = new Error(
    'PRIVATE_CREDENTIAL_729 C:/private-fixture-729/service-account.json privacy-canary-729@example.invalid',
  );
  error.code = code;
  error.stack = 'PRIVATE_STACK_729 ' + error.message;
  return error;
}

function verifier(ctx) {
  return async (token) => {
    ctx.verificationCalls++;
    if (token === fixtureTokens.rejected) throw privateFailure('auth/invalid-id-token');
    if (token === fixtureTokens.unavailable) throw privateFailure('auth/network-request-failed');
    if (![fixtureTokens.analystA, fixtureTokens.traveller].includes(token)) {
      throw privateFailure('auth/invalid-id-token');
    }
    return { uid: token };
  };
}

// Execute the real app, restricting its listener to an ephemeral loopback port.
export default function controlledExpress(...args) {
  const ctx = context();
  const app = realExpress(...args);
  const realListen = app.listen.bind(app);
  app.listen = (...listenArgs) => {
    const callback = listenArgs.findLast((value) => typeof value === 'function');
    ctx.server = realListen(0, '127.0.0.1', callback);
    return ctx.server;
  };
  return app;
}

export function createAnalyticsRouter(options = {}) {
  const ctx = context();
  return realCreateAnalyticsRouter({
    ...options, projectId: 'demo-travelguard-local-api', verifyToken: verifier(ctx),
    store: {
      async getRole(uid) {
        ctx.roleReads++;
        if (ctx.roleFailure) throw privateFailure('permission-denied');
        return uid === fixtureTokens.traveller ? 'traveller' :
          uid === fixtureTokens.analystA ? 'analyst' : undefined;
      },
      async load() {
        ctx.datasetLoads++;
        if (ctx.datasetFailure) throw privateFailure('unavailable');
        return structuredClone(records);
      },
    },
  });
}

export function createTravelRouter(options = {}) {
  const ctx = context();
  return realCreateTravelRouter({
    ...options, apiKey: 'fixture-google-key', projectId: 'demo-travelguard-local-api',
    verifyToken: verifier(ctx),
    fetchImpl: async () => {
      ctx.providerCalls++;
      throw new Error('Travel provider calls are outside this privacy batch.');
    },
  });
}

export function createFirebaseAuth(options = {}) {
  const ctx = context();
  return realCreateAuth({
    ...options, projectId: 'demo-travelguard-local-api', verifyToken: verifier(ctx),
  });
}

export class GoogleGenAI {
  constructor() {
    const ctx = context();
    this.models = {
      async generateContent() {
        ctx.providerCalls++;
        throw new Error('Gemini calls are outside this privacy batch.');
      },
    };
  }
}
