import assert from "node:assert/strict";
import { once } from "node:events";
import test from "node:test";
import express from "express";
import { buildAnalytics } from "./analytics.mjs";
import { createAnalyticsRouter } from "./analytics_routes.mjs";

// -----------------------------------------------------------------------------
// FICTIONAL REFERENCE RECORDS
// -----------------------------------------------------------------------------
const countries = [
  { id: "japan", name: "Japan" },
  { id: "australia", name: "Australia" },
  { id: "south_korea", name: "South Korea" },
  { id: "united_states", name: "United States" },
  { id: "united_kingdom", name: "United Kingdom" },
];
const rules = [
  { id: "r1", title: "Passport preparation" },
  { id: "r2", title: "Visa preparation" },
];
const item = (sourceRuleId, completed) => ({
  sourceRuleId,
  completed,
  title: "private-title@example.invalid",
});
const dataset = {
  countries,
  rules,
  trips: [
    {
      id: "private-trip-a",
      userId: "private-user-a",
      destinationCountryId: "japan",
      purpose: "tourism",
      departureDate: "2026-10-31T16:00:00Z",
      items: [item("r1", true)],
    },
    {
      id: "private-trip-b",
      userId: "private-user-a",
      destinationCountryId: "japan",
      purpose: "business",
      departureDate: "2027-02-15T00:00:00Z",
      items: [item("r1", false), item("r2", false), item("r2", false)],
    },
    {
      id: "private-trip-c",
      userId: "private-user-b",
      destinationCountryId: "australia",
      purpose: "study",
      departureDate: "2026-11-05T00:00:00Z",
      items: [item("r2", true), item("r1", false)],
    },
    {
      id: "private-trip-empty",
      userId: "private-user-c",
      destinationCountryId: "united_kingdom",
      purpose: "tourism",
      departureDate: "invalid",
      items: [],
    },
  ],
};

// -----------------------------------------------------------------------------
// CALCULATION REGRESSIONS AND RESPONSE PRIVACY
// -----------------------------------------------------------------------------
test("Overview counts unique travellers without returning their identifiers", () => {
  assert.deepEqual(buildAnalytics("overview", dataset), {
    totalTrips: 4,
    uniqueTravellers: 3,
    topDestination: "Japan",
    topDestinationTrips: 2,
    supportedDestinations: 5,
  });
});

test("Destination shares include all five countries and zero-count destinations", () => {
  const result = buildAnalytics("destinations", dataset);
  assert.equal(result.length, 5);
  assert.deepEqual(result[0], {
    countryId: "japan",
    name: "Japan",
    count: 2,
    percentage: 50,
  });
  assert.equal(result.filter((row) => row.count === 0).length, 2);
});

test("Malaysia month boundaries and missing months remain correct", () => {
  const result = buildAnalytics("monthly", dataset);
  assert.deepEqual(
    result.map((row) => row.label),
    ["November 2026", "December 2026", "January 2027", "February 2027"],
  );
  assert.deepEqual(
    result.map((row) => row.count),
    [2, 0, 0, 1],
  );
});

test("Purpose filtering counts only the selected destination", () => {
  assert.deepEqual(
    buildAnalytics("purpose", dataset, { destinationId: "japan" }),
    {
      total: 2,
      counts: { tourism: 1, business: 1, study: 0 },
    },
  );
});

test("Corrupted dates cannot allocate an excessive monthly series", () => {
  assert.throws(
    () =>
      buildAnalytics("monthly", {
        countries,
        trips: [
          { departureDate: "1900-01-01" },
          { departureDate: "2200-01-01" },
        ],
      }),
    /period is too large/,
  );
});

test("Completion is an average of nonempty trip rates, not an item-weighted rate", () => {
  const result = buildAnalytics("completion", dataset);
  assert.equal(result.overallCompletionRate, 50);
  assert.equal(result.tripsWithChecklist, 3);
  assert.equal(result.totalChecklistItems, 6);
  assert.equal(result.completedChecklistItems, 2);
  assert.equal(result.incompleteChecklistItems, 4);
  assert.equal(
    result.destinationComparison.find((row) => row.countryId === "japan")
      .completionRate,
    50,
  );
});

test("Requirement frequency counts a duplicated requirement only once per trip", () => {
  const result = buildAnalytics("requirements", dataset);
  assert.equal(result.analysedTrips, 3);
  assert.equal(
    result.requirementPatterns.find((row) => row.requirementKey === "r1")
      .tripCount,
    3,
  );
  assert.equal(
    result.requirementPatterns.find((row) => row.requirementKey === "r2")
      .tripCount,
    2,
  );
});

test("Combined destination and purpose filters apply before checklist aggregation", () => {
  const result = buildAnalytics("completion", dataset, {
    destinationId: "japan",
    purpose: "business",
  });
  assert.equal(result.tripsWithChecklist, 1);
  assert.equal(result.totalChecklistItems, 3);
  assert.equal(result.overallCompletionRate, 0);
});

for (const metric of [
  "countries",
  "overview",
  "destinations",
  "monthly",
  "purpose",
  "completion",
  "requirements",
]) {
  test(`Empty records produce defined results for ${metric}`, () => {
    const output = buildAnalytics(metric, { countries, rules, trips: [] });
    assert.ok(output);
    assert.doesNotMatch(JSON.stringify(output), /NaN|Infinity|undefined/);
  });

  test(`${metric} never returns private records or traveller-provided titles`, () => {
    assert.doesNotMatch(
      JSON.stringify(buildAnalytics(metric, dataset)),
      /private-|userId|departureDate|"items"/,
    );
  });
}

test("Unrecognised source identifiers and text are replaced with a safe summary label", () => {
  const data = {
    countries,
    rules,
    trips: [
      {
        destinationCountryId: "japan",
        purpose: "tourism",
        items: [
          {
            sourceRuleId: "private-source",
            title: "private-contact@example.invalid",
            completed: false,
          },
        ],
      },
    ],
  };
  for (const metric of ["completion", "requirements"]) {
    const result = JSON.stringify(buildAnalytics(metric, data));
    assert.doesNotMatch(result, /private-/);
    assert.match(result, /Unnamed requirement/);
  }
});

// -----------------------------------------------------------------------------
// REAL HTTP AUTHENTICATION AND AUTHORISATION
// -----------------------------------------------------------------------------
async function setup(t, initialRole = "analyst") {
  let role = initialRole;
  let roleReads = 0;
  let loads = 0;
  const app = express();
  app.use(express.json());
  app.use(
    "/api/analytics",
    createAnalyticsRouter({
      projectId: "test-project",
      verifyToken: async (token) => {
        if (token !== "valid-token")
          throw Object.assign(new Error("Expired"), {
            code: "auth/id-token-expired",
          });
        return { uid: "analyst-account" };
      },
      store: {
        async getRole(uid) {
          assert.equal(uid, "analyst-account");
          roleReads++;
          return role;
        },
        async load() {
          loads++;
          return dataset;
        },
      },
    }),
  );
  const server = app.listen(0, "127.0.0.1");
  await once(server, "listening");
  t.after(() => new Promise((resolve) => server.close(resolve)));
  return {
    counts: () => ({ roleReads, loads }),
    setRole: (value) => {
      role = value;
    },
    async request(body, token = "valid-token") {
      const response = await fetch(
        `http://127.0.0.1:${server.address().port}/api/analytics/query`,
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            ...(token ? { Authorization: `Bearer ${token}` } : {}),
          },
          body: JSON.stringify(body),
        },
      );
      return {
        status: response.status,
        body: await response.json(),
        headers: response.headers,
      };
    },
  };
}

for (const token of [null, "expired-token"]) {
  test(`Missing or expired token blocks every analytics database read: ${token}`, async (t) => {
    const api = await setup(t);
    assert.equal(
      (await api.request({ metric: "overview" }, token)).status,
      401,
    );
    assert.deepEqual(api.counts(), { roleReads: 0, loads: 0 });
  });
}

for (const role of ["traveller", "contentManager", "admin", undefined]) {
  test(`Role ${role} cannot load analytics`, async (t) => {
    const api = await setup(t, role === undefined ? "missing" : role);
    assert.equal((await api.request({ metric: "overview" })).status, 403);
    assert.equal(api.counts().loads, 0);
  });
}

test("An analyst receives aggregates and no-store headers", async (t) => {
  const api = await setup(t);
  const result = await api.request({ metric: "completion" });
  assert.equal(result.status, 200);
  assert.equal(result.headers.get("cache-control"), "no-store");
  assert.equal(result.body.data.overallCompletionRate, 50);
  assert.doesNotMatch(
    JSON.stringify(result.body),
    /private-|userId|departureDate/,
  );
});

test("A role change is enforced on the next request", async (t) => {
  const api = await setup(t);
  assert.equal((await api.request({ metric: "overview" })).status, 200);
  api.setRole("traveller");
  assert.equal((await api.request({ metric: "overview" })).status, 403);
  assert.equal(api.counts().loads, 1);
});

for (const body of [
  { metric: "rawTrips" },
  { metric: "completion", destinationId: { $ne: "" } },
  { metric: "completion", purpose: ["study"] },
  { metric: "overview", userId: "another-user" },
]) {
  test(`Invalid query cannot control database access: ${JSON.stringify(body)}`, async (t) => {
    const api = await setup(t);
    assert.equal((await api.request(body)).status, 400);
    assert.equal(api.counts().loads, 0);
  });
}
