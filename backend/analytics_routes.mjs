import { Router } from "express";
import { rateLimit } from "express-rate-limit";
import { createFirebaseAuth } from "./firebase_auth.mjs";
import { createAnalyticsStore } from "./analytics_store.mjs";
import { buildAnalytics } from "./analytics.mjs";

// -----------------------------------------------------------------------------
// PROTECTED AGGREGATE API
// -----------------------------------------------------------------------------
// Inject token verification and storage only for isolated tests.
export function createAnalyticsRouter({
  projectId = process.env.FIREBASE_PROJECT_ID?.trim(),
  verifyToken,
  store = createAnalyticsStore(),
} = {}) {
  const router = Router();
  router.use((req, res, next) => {
    res.set("Cache-Control", "no-store");
    res.set("X-Content-Type-Options", "nosniff");
    next();
  });
  router.use(
    rateLimit({
      windowMs: 60_000,
      limit: 120,
      standardHeaders: true,
      legacyHeaders: false,
    }),
  );
  router.use(createFirebaseAuth({ projectId, verifyToken }));
  router.use(
    rateLimit({
      windowMs: 60_000,
      limit: 60,
      keyGenerator: (req) => req.travellerUid,
      standardHeaders: true,
      legacyHeaders: false,
    }),
  );

  router.post("/query", async (req, res) => {
    try {
      // Admin SDK reads bypass client rules, so enforce the role before loading data.
      if ((await store.getRole(req.travellerUid)) !== "analyst") {
        return res.status(403).json({
          error: "This feature is available to Tourism Data Analysts only.",
        });
      }

      const body = req.body;
      const metrics = [
        "countries",
        "overview",
        "destinations",
        "monthly",
        "purpose",
        "completion",
        "requirements",
      ];
      const validFilter = (value) =>
        value == null ||
        (typeof value === "string" && /^[A-Za-z0-9_-]{1,128}$/.test(value));
      if (
        !body ||
        typeof body !== "object" ||
        Array.isArray(body) ||
        Object.keys(body).some(
          (key) => !["metric", "destinationId", "purpose"].includes(key),
        ) ||
        !metrics.includes(body.metric) ||
        !validFilter(body.destinationId) ||
        (body.purpose != null &&
          !["tourism", "business", "study"].includes(body.purpose))
      ) {
        return res
          .status(400)
          .json({ error: "Select a valid analytics type and filters." });
      }

      const filters = {
        destinationId: body.destinationId,
        purpose: body.purpose,
      };
      const dataset = await store.load(body.metric, filters);
      return res.json({ data: buildAnalytics(body.metric, dataset, filters) });
    } catch (error) {
      // Log an error code only; records, tokens and credential details stay private.
      console.error("ANALYTICS ERROR:", error?.code ?? "unavailable");
      return res.status(503).json({
        error: "Analytics is temporarily unavailable. Please try again.",
      });
    }
  });
  return router;
}
