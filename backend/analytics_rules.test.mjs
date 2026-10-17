import assert from "node:assert/strict";
import { once } from "node:events";
import test, { after } from "node:test";
import express from "express";
import { getApps } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { createAnalyticsRouter } from "./analytics_routes.mjs";

// -----------------------------------------------------------------------------
// LOCAL EMULATOR ONLY
// -----------------------------------------------------------------------------
const host = process.env.FIRESTORE_EMULATOR_HOST;
if (!host || !/^(127\.0\.0\.1|localhost):\d+$/.test(host)) {
  throw new Error("Run this test through the local Firestore emulator.");
}
const projectId = "demo-travelguard-privacy";
process.env.FIREBASE_PROJECT_ID = projectId;
const base = `http://${host}/v1/projects/${projectId}/databases/(default)/documents`;

// Unsigned identities are accepted only by the emulator, never production Firebase.
function identity(uid) {
  if (!uid) return undefined;
  const now = Math.floor(Date.now() / 1000);
  const encode = (value) =>
    Buffer.from(JSON.stringify(value)).toString("base64url");
  return `${encode({ alg: "none", typ: "JWT" })}.${encode({
    aud: projectId,
    iss: `https://securetoken.google.com/${projectId}`,
    sub: uid,
    user_id: uid,
    iat: now,
    exp: now + 3600,
    auth_time: now,
    firebase: { sign_in_provider: "custom", identities: {} },
  })}.`;
}

// Seed a disposable demo project using the emulator's administrative identity.
async function seed(path, fields) {
  const response = await fetch(`${base}/${path}`, {
    method: "PATCH",
    headers: {
      Authorization: "Bearer owner",
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ fields }),
  });
  assert.equal(response.status, 200, await response.text());
}
const string = (value) => ({ stringValue: value });
for (const [uid, role] of [
  ["traveller-a", "traveller"],
  ["traveller-b", "traveller"],
  ["analyst-account", "analyst"],
  ["manager-account", "contentManager"],
  ["admin-account", "admin"],
])
  await seed(`users/${uid}`, { role: string(role) });
await seed("countries/japan", { name: string("Japan") });
await seed("travelRules/r1", { title: string("Passport preparation") });
await seed("trips/trip-a", {
  userId: string("traveller-a"),
  destinationCountryId: string("japan"),
  purpose: string("tourism"),
});
await seed("trips/trip-a/checklistItems/r1", {
  sourceRuleId: string("r1"),
  completed: { booleanValue: false },
});
await seed("trips/former-traveller-trip", {
  userId: string("analyst-account"),
  destinationCountryId: string("japan"),
  purpose: string("tourism"),
});
await seed("analystReports/own-report", {
  analystId: string("analyst-account"),
});
await seed("analystReports/other-report", {
  analystId: string("other-analyst"),
});

// -----------------------------------------------------------------------------
// DIRECT CLIENT ACCESS
// -----------------------------------------------------------------------------
for (const [uid, path, status] of [
  [null, "trips/trip-a", 403],
  ["traveller-a", "trips/trip-a", 200],
  ["traveller-b", "trips/trip-a", 403],
  ["analyst-account", "trips/trip-a", 403],
  ["analyst-account", "trips/former-traveller-trip", 403],
  ["manager-account", "trips/trip-a", 403],
  ["admin-account", "trips/trip-a", 403],
  ["traveller-a", "trips/trip-a/checklistItems/r1", 200],
  ["traveller-b", "trips/trip-a/checklistItems/r1", 403],
  ["analyst-account", "trips/trip-a/checklistItems/r1", 403],
  ["analyst-account", "trips", 403],
  ["analyst-account", "analystReports/own-report", 200],
  ["analyst-account", "analystReports/other-report", 403],
]) {
  test(`${uid ?? "anonymous"} reading ${path} returns ${status}`, async () => {
    const token = identity(uid);
    const response = await fetch(`${base}/${path}`, {
      headers: token ? { Authorization: `Bearer ${token}` } : {},
    });
    assert.equal(response.status, status);
  });
}

test("Traveller completion updates still work", async () => {
  const response = await fetch(
    `${base}/trips/trip-a/checklistItems/r1?updateMask.fieldPaths=completed`,
    {
      method: "PATCH",
      headers: {
        Authorization: `Bearer ${identity("traveller-a")}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ fields: { completed: { booleanValue: true } } }),
    },
  );
  assert.equal(response.status, 200);
});

test("The backend can compute aggregates after direct analyst access is denied", async (t) => {
  const app = express();
  app.use(express.json());
  app.use(
    "/api/analytics",
    createAnalyticsRouter({
      projectId,
      verifyToken: async () => ({ uid: "analyst-account" }),
    }),
  );
  const server = app.listen(0, "127.0.0.1");
  await once(server, "listening");
  t.after(() => new Promise((resolve) => server.close(resolve)));
  const response = await fetch(
    `http://127.0.0.1:${server.address().port}/api/analytics/query`,
    {
      method: "POST",
      headers: {
        Authorization: "Bearer emulator-test",
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ metric: "completion" }),
    },
  );
  const body = await response.json();
  assert.equal(response.status, 200, JSON.stringify(body));
  assert.equal(body.data.tripsWithChecklist, 1);
  assert.equal(body.data.totalChecklistItems, 1);
  assert.equal(body.data.overallCompletionRate, 100);
  assert.doesNotMatch(
    JSON.stringify(body),
    /traveller-a|trip-a|analyst-account|userId/,
  );
});

// Close emulator connections so the test process exits cleanly.
after(async () => {
  for (const app of getApps()) await getFirestore(app).terminate();
});
