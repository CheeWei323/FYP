import { getApps, initializeApp, applicationDefault } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";

// -----------------------------------------------------------------------------
// SERVER-ONLY FIRESTORE READS
// -----------------------------------------------------------------------------
// Resolve credentials lazily so other features can start before analytics setup.
export function createAnalyticsStore() {
  let firestore;
  function database() {
    if (firestore) return firestore;
    const projectId = process.env.FIREBASE_PROJECT_ID?.trim();
    if (
      !projectId ||
      (!process.env.GOOGLE_APPLICATION_CREDENTIALS &&
        !process.env.FIRESTORE_EMULATOR_HOST)
    ) {
      throw new Error("Analytics service credentials are not configured.");
    }
    const name = `travelguard-analytics-${projectId}`;
    const app =
      getApps().find((item) => item.name === name) ??
      initializeApp({ projectId, credential: applicationDefault() }, name);
    firestore = getFirestore(app);
    return firestore;
  }

  return {
    // Authorise against the current stored role, never a client-supplied role.
    async getRole(uid) {
      const user = await database().collection("users").doc(uid).get();
      return user.data()?.role;
    },

    // Fetch only the fields needed for the requested aggregate.
    async load(metric, filters) {
      const db = database();
      const countries = (
        await db.collection("countries").select("name").get()
      ).docs.map((doc) => ({ id: doc.id, ...doc.data() }));
      if (metric === "countries") return { countries };
      const snapshot = await db
        .collection("trips")
        .select("destinationCountryId", "purpose", "departureDate", "userId")
        .limit(10001)
        .get();
      // Fail visibly rather than return totals calculated from a truncated dataset.
      if (snapshot.size > 10000)
        throw new Error("Analytics dataset requires paginated processing.");
      const trips = snapshot.docs.map((doc) => ({ id: doc.id, ...doc.data() }));
      if (!["completion", "requirements"].includes(metric))
        return { countries, trips };

      const rules = (
        await db
          .collection("travelRules")
          .select("title", "checklistLabel")
          .get()
      ).docs.map((doc) => ({ id: doc.id, ...doc.data() }));
      const selected = trips.filter(
        (trip) =>
          (!filters.destinationId ||
            trip.destinationCountryId === filters.destinationId) &&
          (!filters.purpose || trip.purpose === filters.purpose),
      );

      // Bound concurrent reads without dropping any selected trips.
      for (let offset = 0; offset < selected.length; offset += 10) {
        await Promise.all(
          selected.slice(offset, offset + 10).map(async (trip) => {
            const checklist = await db
              .collection("trips")
              .doc(trip.id)
              .collection("checklistItems")
              .select("sourceRuleId", "completed")
              .get();
            trip.items = checklist.docs.map((doc) => doc.data());
          }),
        );
      }
      return { countries, trips, rules };
    },
  };
}
