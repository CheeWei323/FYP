import { getApps, initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";

// -----------------------------------------------------------------------------
// FIREBASE AUTHENTICATION
// -----------------------------------------------------------------------------
// Separate invalid sessions from temporary verification or configuration failures.
const invalidTokenCodes = new Set([
  "auth/argument-error",
  "auth/invalid-argument",
  "auth/invalid-id-token",
  "auth/id-token-expired",
  "auth/id-token-revoked",
  "auth/user-disabled",
  "auth/user-not-found",
]);

// Share ID-token verification between packing and route-planning requests.
export function createFirebaseAuth({
  projectId = process.env.FIREBASE_PROJECT_ID?.trim(),
  verifyToken,
  signInMessage = "Please sign in to continue.",
} = {}) {
  let firebaseAuth;

  // Reuse one Admin SDK instance for this Firebase project.
  const verify =
    verifyToken ??
    ((token) => {
      if (!firebaseAuth) {
        const name = `travelguard-api-${projectId}`;
        const firebaseApp =
          getApps().find((item) => item.name === name) ??
          initializeApp({ projectId }, name);

        firebaseAuth = getAuth(firebaseApp);
      }

      return firebaseAuth.verifyIdToken(token);
    });

  // Reject unauthenticated requests before protected feature logic runs.
  return async (req, res, next) => {
    res.set("Cache-Control", "no-store");

    if (!projectId) {
      return res.status(503).json({
        error: "Sign-in verification is not configured yet.",
      });
    }

    const match = /^Bearer ([^\s]{1,8192})$/i.exec(
      req.get("Authorization") ?? "",
    );

    if (!match) {
      return res.status(401).json({ error: signInMessage });
    }

    try {
      const decoded = await verify(match[1]);

      if (typeof decoded?.uid !== "string" || !decoded.uid.trim()) {
        throw Object.assign(new Error("Missing Firebase user."), {
          code: "auth/invalid-id-token",
        });
      }

      req.travellerUid = decoded.uid;
    } catch (error) {
      const invalidSession = invalidTokenCodes.has(error?.code);

      return res.status(invalidSession ? 401 : 503).json({
        error: invalidSession
          ? "Your session is invalid or expired. Please sign in again."
          : "Sign-in verification is temporarily unavailable. Please try again.",
      });
    }

    return next();
  };
}
