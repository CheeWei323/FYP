import assert from "node:assert/strict";
import test from "node:test";
import { createFirebaseAuth } from "./firebase_auth.mjs";

// -----------------------------------------------------------------------------
// AUTHENTICATION TEST HELPERS
// -----------------------------------------------------------------------------
// Replace token verification so these tests need no credentials or paid services.
async function checkAuth({
  header,
  projectId = "test-project",
  decoded = { uid: "test-traveller" },
  errorCode,
} = {}) {
  let verified = 0;
  let continued = 0;
  let status = 200;
  let body;
  const headers = {};
  const req = { get: () => header };

  const res = {
    set(name, value) {
      headers[name] = value;
    },
    status(value) {
      status = value;
      return this;
    },
    json(value) {
      body = value;
      return this;
    },
  };

  const middleware = createFirebaseAuth({
    projectId,
    verifyToken: async (token) => {
      verified++;
      assert.equal(token, "test-token");

      if (errorCode) {
        throw Object.assign(new Error("Private verification details."), {
          code: errorCode,
        });
      }

      return decoded;
    },
  });

  await middleware(req, res, () => {
    continued++;
  });

  return { req, status, body, headers, verified, continued };
}

// -----------------------------------------------------------------------------
// REQUEST AND SESSION VALIDATION
// -----------------------------------------------------------------------------
for (const header of [
  undefined,
  "Basic test-token",
  "Bearer",
  "Bearer one two",
]) {
  test(`Reject missing or malformed authorization: ${header}`, async () => {
    const result = await checkAuth({ header });

    assert.equal(result.status, 401);
    assert.equal(result.verified, 0);
    assert.equal(result.continued, 0);
    assert.equal(result.headers["Cache-Control"], "no-store");
  });
}

for (const errorCode of [
  "auth/id-token-expired",
  "auth/invalid-id-token",
  "auth/argument-error",
]) {
  test(`Reject invalid session: ${errorCode}`, async () => {
    const result = await checkAuth({
      header: "Bearer test-token",
      errorCode,
    });

    assert.equal(result.status, 401);
    assert.equal(result.continued, 0);
    assert.equal(result.req.travellerUid, undefined);
    assert.match(result.body.error, /sign in again/i);
    assert.doesNotMatch(result.body.error, /Private verification details/);
  });
}

test("Reject decoded tokens without a user ID", async () => {
  const result = await checkAuth({
    header: "Bearer test-token",
    decoded: {},
  });

  assert.equal(result.status, 401);
  assert.equal(result.continued, 0);
});

test("Missing Firebase configuration blocks protected logic", async () => {
  const result = await checkAuth({
    header: "Bearer test-token",
    projectId: "",
  });

  assert.equal(result.status, 503);
  assert.equal(result.verified, 0);
  assert.equal(result.continued, 0);
});

test("Verification outages return a safe service error", async () => {
  const result = await checkAuth({
    header: "Bearer test-token",
    errorCode: "auth/internal-error",
  });

  assert.equal(result.status, 503);
  assert.equal(result.continued, 0);
  assert.doesNotMatch(result.body.error, /Private verification details/);
});

test("A valid session supplies its verified user ID exactly once", async () => {
  const result = await checkAuth({ header: "Bearer test-token" });

  assert.equal(result.status, 200);
  assert.equal(result.verified, 1);
  assert.equal(result.continued, 1);
  assert.equal(result.req.travellerUid, "test-traveller");
});
