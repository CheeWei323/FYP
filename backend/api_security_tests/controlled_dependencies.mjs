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
  analystA: 'fixture-analyst-a',
  analystB: 'fixture-analyst-b',
  traveller: 'fixture-traveller-a',
});

export const expectedOverview = Object.freeze({
  totalTrips: 3,
  uniqueTravellers: 2,
  topDestination: 'Japan',
  topDestinationTrips: 2,
  supportedDestinations: 5,
});

const records = {
  countries: [
    { id: 'japan', name: 'Japan' },
    { id: 'australia', name: 'Australia' },
    { id: 'south_korea', name: 'South Korea' },
    { id: 'united_states', name: 'United States' },
    { id: 'united_kingdom', name: 'United Kingdom' },
  ],
  trips: [
    { id: 'fixture-trip-a', userId: 'fixture-user-a', destinationCountryId: 'japan', purpose: 'tourism', departureDate: '2026-11-06T00:00:00Z' },
    { id: 'fixture-trip-b', userId: 'fixture-user-a', destinationCountryId: 'japan', purpose: 'business', departureDate: '2026-11-07T00:00:00Z' },
    { id: 'fixture-trip-c', userId: 'fixture-user-b', destinationCountryId: 'australia', purpose: 'study', departureDate: '2026-11-08T00:00:00Z' },
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
    caseId,
    server: undefined,
    verificationCalls: 0,
    roleReads: 0,
    datasetLoads: 0,
    providerCalls: 0,
    requests: [],
  };
  return activeContext;
}

function context() {
  if (!activeContext) throw new Error('A test context must be set before starting the app.');
  return activeContext;
}

function verifier(ctx) {
  return async (token) => {
    ctx.verificationCalls++;
    if (!Object.values(fixtureTokens).includes(token)) {
      throw Object.assign(new Error('Fictional token rejected.'), { code: 'auth/invalid-id-token' });
    }
    return { uid: token };
  };
}

// Real Express app and middleware, with only the listen address/port constrained.
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
    ...options,
    projectId: 'demo-travelguard-local-api',
    verifyToken: verifier(ctx),
    store: {
      async getRole(uid) {
        ctx.roleReads++;
        return uid === fixtureTokens.traveller ? 'traveller' :
          [fixtureTokens.analystA, fixtureTokens.analystB].includes(uid) ? 'analyst' : undefined;
      },
      async load() {
        ctx.datasetLoads++;
        return structuredClone(records);
      },
    },
  });
}

export function createTravelRouter(options = {}) {
  const ctx = context();
  return realCreateTravelRouter({
    ...options,
    apiKey: 'fixture-google-key',
    projectId: 'demo-travelguard-local-api',
    verifyToken: verifier(ctx),
    fetchImpl: async () => {
      ctx.providerCalls++;
      throw new Error('A provider call is outside this analytics security batch.');
    },
  });
}

export function createFirebaseAuth(options = {}) {
  const ctx = context();
  return realCreateAuth({
    ...options,
    projectId: 'demo-travelguard-local-api',
    verifyToken: verifier(ctx),
  });
}

export class GoogleGenAI {
  constructor() {
    const ctx = context();
    this.models = {
      async generateContent() {
        ctx.providerCalls++;
        throw new Error('Gemini is outside this controlled security batch.');
      },
    };
  }
}

