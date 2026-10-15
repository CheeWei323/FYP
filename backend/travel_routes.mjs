import { Router } from 'express';
import { rateLimit } from 'express-rate-limit';
import { getApps, initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';

// -----------------------------------------------------------------------------
// INPUT VALIDATION
// -----------------------------------------------------------------------------
const countryCodes = new Map([
  ['japan', 'JP'],
  ['australia', 'AU'],
  ['united_states', 'US'],
  ['usa', 'US'],
  ['us', 'US'],
  ['united_kingdom', 'GB'],
  ['uk', 'GB'],
  ['south_korea', 'KR'],
]);

// Attach safe messages and HTTP statuses to expected failures.
function apiError(status, message) {
  return Object.assign(new Error(message), { status });
}

// Reject empty, oversized or non-text input before calling Google.
function text(value, name, maximum = 200) {
  if (
    typeof value !== 'string' ||
    !value.trim() ||
    value.trim().length > maximum
  ) {
    throw apiError(400, `A valid ${name} is required.`);
  }

  return value.trim();
}

// Restrict place searches to the project's supported destinations.
function countryCode(value) {
  const id = text(value, 'destination country')
    .toLowerCase()
    .replace(/[\s-]+/g, '_');

  const code = countryCodes.get(id);

  if (!code) {
    throw apiError(400, 'This destination is not supported.');
  }

  return code;
}

// Keep place identifiers separate from addresses and URL paths.
function placeId(value) {
  const id = text(value, 'place ID', 512);

  if (!/^[A-Za-z0-9_-]+$/.test(id)) {
    throw apiError(400, 'The place ID is invalid.');
  }

  return id;
}

// Forward an optional search-session token to both Places endpoints.
function sessionToken(value) {
  if (value === undefined) return undefined;

  if (
    typeof value !== 'string' ||
    !/^[A-Za-z0-9_-]{1,36}$/.test(value)
  ) {
    throw apiError(400, 'The search-session token is invalid.');
  }

  return value;
}

// -----------------------------------------------------------------------------
// ROUTER CONFIGURATION
// -----------------------------------------------------------------------------
// Dependencies can be replaced in tests without changing production credentials.
export function createTravelRouter({
  apiKey = process.env.GOOGLE_MAPS_SERVER_KEY?.trim(),
  projectId = process.env.FIREBASE_PROJECT_ID?.trim(),
  fetchImpl = globalThis.fetch,
  verifyToken,
} = {}) {
  const router = Router();
  let firebaseAuth;

  // Verify Firebase signatures and claims for the app's Firebase project.
  const verify = verifyToken ?? ((token) => {
    const name = 'travelguard-routing';

    const firebaseApp =
      getApps().find((item) => item.name === name) ??
      initializeApp({ projectId }, name);

    firebaseAuth ??= getAuth(firebaseApp);

    return firebaseAuth.verifyIdToken(token);
  });

  // Prevent browsers and proxies from caching travel queries and results.
  router.use((req, res, next) => {
    res.set('Cache-Control', 'no-store');
    next();
  });

  // Report configuration presence without returning keys or making billable calls.
  router.get('/status', (req, res) => {
    const configured = Boolean(apiKey && projectId);

    res.status(configured ? 200 : 503).json({ configured });
  });

  // Limit unauthenticated traffic before token verification.
  router.use(rateLimit({
    windowMs: 60_000,
    limit: 120,
    standardHeaders: true,
    legacyHeaders: false,
    message: {
      error: 'Too many requests. Please wait a minute.',
    },
  }));

  // Require a signed-in Firebase user before any Google request.
  router.use(async (req, res, next) => {
    if (!apiKey || !projectId) {
      throw apiError(503, 'Route planning is not configured yet.');
    }

    const match = /^Bearer ([^\s]{1,8192})$/i.exec(
      req.get('Authorization') ?? '',
    );

    if (!match) {
      throw apiError(401, 'Please sign in to use route planning.');
    }

    try {
      const decoded = await verify(match[1]);

      if (!decoded.uid) {
        throw new Error('Missing Firebase user.');
      }

      req.travellerUid = decoded.uid;
    } catch (error) {
      if (error.code === 'auth/internal-error') {
        throw apiError(
          503,
          'Sign-in verification is temporarily unavailable.',
        );
      }

      throw apiError(
        401,
        'Your session is invalid or expired. Please sign in again.',
      );
    }

    next();
  });

  // Share the allowance across a user's devices and network addresses.
  router.use(rateLimit({
    windowMs: 60_000,
    limit: 60,
    keyGenerator: (req) => req.travellerUid,
    standardHeaders: true,
    legacyHeaders: false,
    message: {
      error: 'Too many travel searches. Please wait a minute.',
    },
  }));

  // ---------------------------------------------------------------------------
  // GOOGLE REQUESTS
  // ---------------------------------------------------------------------------
  // Keep the key on the server and bound each upstream request to 12 seconds.
  async function googleJson(url, fieldMask, body) {
    let response;
    let data;

    try {
      response = await fetchImpl(url, {
        method: body === undefined ? 'GET' : 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': apiKey,
          'X-Goog-FieldMask': fieldMask,
        },
        ...(body === undefined
          ? {}
          : { body: JSON.stringify(body) }),
        signal: AbortSignal.timeout(12_000),
      });

      data = await response.json();
    } catch (error) {
      if (
        error.name === 'TimeoutError' ||
        error.name === 'AbortError'
      ) {
        throw apiError(
          504,
          'The map service took too long. Please try again.',
        );
      }

      throw apiError(
        502,
        'The map service could not be reached. Please try again.',
      );
    }

    if (!response.ok) {
      console.error(
        'GOOGLE MAPS REQUEST FAILED:',
        response.status,
      );

      if (response.status === 404) {
        throw apiError(404, 'This place could not be found.');
      }

      throw apiError(
        503,
        'The map service is unavailable. Please try again later.',
      );
    }

    if (
      !data ||
      typeof data !== 'object' ||
      Array.isArray(data)
    ) {
      throw apiError(
        502,
        'The map service returned an invalid response.',
      );
    }

    return data;
  }

  // ---------------------------------------------------------------------------
  // PLACE SEARCH
  // ---------------------------------------------------------------------------
  // Return selectable place predictions within the selected country.
  router.post('/places/autocomplete', async (req, res) => {
    const body = req.body ?? {};
    const code = countryCode(body.countryId);
    const input = text(body.input, 'search text');

    if (input.length < 2) {
      throw apiError(400, 'Enter at least two characters.');
    }

    const data = await googleJson(
      'https://places.googleapis.com/v1/places:autocomplete',
      'suggestions.placePrediction.placeId,suggestions.placePrediction.text.text',
      {
        input,
        includedRegionCodes: [code.toLowerCase()],
        languageCode: 'en',
        sessionToken: sessionToken(body.sessionToken),
      },
    );

    const places = (data.suggestions ?? [])
      .map((item) => item.placePrediction)
      .filter((item) => item?.placeId && item.text?.text)
      .map((item) => ({
        placeId: item.placeId,
        label: item.text.text,
      }));

    res.json({ places });
  });

  // Resolve a selection to coordinates and confirm its destination country.
  router.post('/places/details', async (req, res) => {
    const body = req.body ?? {};
    const code = countryCode(body.countryId);
    const id = placeId(body.placeId);

    const url = new URL(
      `https://places.googleapis.com/v1/places/${encodeURIComponent(id)}`,
    );

    url.searchParams.set('languageCode', 'en');

    const token = sessionToken(body.sessionToken);

    if (token) {
      url.searchParams.set('sessionToken', token);
    }

    const data = await googleJson(
      url,
      'id,formattedAddress,location,addressComponents',
    );

    const country = data.addressComponents?.find(
      (item) => item.types?.includes('country'),
    );

    if (country?.shortText?.toUpperCase() !== code) {
      throw apiError(
        400,
        'Choose a place within your trip destination country.',
      );
    }

    const latitude = data.location?.latitude;
    const longitude = data.location?.longitude;

    if (
      !Number.isFinite(latitude) ||
      !Number.isFinite(longitude)
    ) {
      throw apiError(
        502,
        'Coordinates are unavailable for this place.',
      );
    }

    res.json({
      placeId: data.id,
      address: data.formattedAddress ?? '',
      latitude,
      longitude,
    });
  });

  // ---------------------------------------------------------------------------
  // ROUTE CALCULATION
  // ---------------------------------------------------------------------------
  // Return driving or walking options with distance, estimated time and geometry.
  router.post('/routes/compute', async (req, res) => {
    const body = req.body ?? {};
    const origin = placeId(body.originPlaceId);
    const destination = placeId(body.destinationPlaceId);
    const travelMode = body.travelMode ?? 'DRIVE';

    if (origin === destination) {
      throw apiError(400, 'Choose two different places.');
    }

    if (!['DRIVE', 'WALK'].includes(travelMode)) {
      throw apiError(400, 'Choose driving or walking.');
    }

    const data = await googleJson(
      'https://routes.googleapis.com/directions/v2:computeRoutes',
      'routes.distanceMeters,routes.duration,routes.polyline.encodedPolyline,routes.description,routes.warnings',
      {
        origin: { placeId: origin },
        destination: { placeId: destination },
        travelMode,
        ...(travelMode === 'DRIVE'
          ? { routingPreference: 'TRAFFIC_UNAWARE' }
          : {}),
        computeAlternativeRoutes: true,
        languageCode: 'en-US',
        units: 'METRIC',
      },
    );

    if (
      !Array.isArray(data.routes) ||
      data.routes.length === 0
    ) {
      throw apiError(
        404,
        'No route was found. Try different places or a different travel mode.',
      );
    }

    const routes = data.routes.map((route) => {
      const duration = /^(\d+(?:\.\d+)?)s$/.exec(
        route.duration ?? '0s',
      );

      const distanceMeters = route.distanceMeters ?? 0;
      const encodedPolyline = route.polyline?.encodedPolyline;

      if (
        !duration ||
        !Number.isFinite(distanceMeters) ||
        distanceMeters < 0 ||
        !encodedPolyline
      ) {
        throw apiError(
          502,
          'The map service returned incomplete route information.',
        );
      }

      return {
        distanceMeters,
        durationSeconds: Number(duration[1]),
        encodedPolyline,
        description: route.description ?? '',
        warnings: route.warnings ?? [],
      };
    });

    res.json({
      routes,
      travelMode,
      trafficAware: false,
    });
  });

  // ---------------------------------------------------------------------------
  // ERROR RESPONSES
  // ---------------------------------------------------------------------------
  // Return useful messages without exposing credentials or upstream error bodies.
  router.use((error, req, res, next) => {
    if (res.headersSent) return next(error);

    const status = error.status ?? 500;

    if (status === 500) {
      console.error(
        'TRAVEL API ERROR:',
        error.code ?? 'unexpected',
      );
    }

    res.status(status).json({
      error: error.status
        ? error.message
        : 'Travel planning failed. Please try again.',
    });
  });

  return router;
}