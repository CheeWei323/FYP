import assert from 'node:assert/strict';
import { once } from 'node:events';
import test from 'node:test';
import express from 'express';
import { createTravelRouter } from './travel_routes.mjs';

// -----------------------------------------------------------------------------
// TEST SERVER
// -----------------------------------------------------------------------------
// Replace external services so checks do not use real keys or Google quota.
async function setup(
  t,
  { data = {}, upstreamStatus = 200, ...overrides } = {},
) {
  const calls = [];
  const app = express();

  app.use(express.json());

  app.use('/api/travel', createTravelRouter({
    apiKey: 'test-server-key',
    projectId: 'travelguard-my-fyp-2026',
    verifyToken: async (token) => {
      if (token !== 'test-token') {
        throw Object.assign(new Error('Expired'), {
          code: 'auth/id-token-expired',
        });
      }

      return { uid: 'test-traveller' };
    },
    fetchImpl: async (url, options) => {
      calls.push({ url: String(url), options });
      return Response.json(data, { status: upstreamStatus });
    },
    ...overrides,
  }));

  const server = app.listen(0, '127.0.0.1');
  await once(server, 'listening');

  t.after(() => new Promise(
    (resolve) => server.close(resolve),
  ));

  // Exercise the real HTTP middleware and endpoints.
  async function request(path, body, token = 'test-token') {
    const response = await fetch(
      `http://127.0.0.1:${server.address().port}/api/travel${path}`,
      {
        method: body === undefined ? 'GET' : 'POST',
        headers: {
          'Content-Type': 'application/json',
          ...(token
            ? { Authorization: `Bearer ${token}` }
            : {}),
        },
        ...(body === undefined
          ? {}
          : { body: JSON.stringify(body) }),
      },
    );

    return {
      status: response.status,
      body: await response.json(),
      headers: response.headers,
    };
  }

  return { request, calls };
}

// -----------------------------------------------------------------------------
// CONFIGURATION AND AUTHENTICATION
// -----------------------------------------------------------------------------
test('Status reveals configuration without keys or Google calls', async (t) => {
  const { request, calls } = await setup(t);
  const result = await request('/status');

  assert.equal(result.status, 200);
  assert.deepEqual(result.body, { configured: true });
  assert.equal(result.headers.get('cache-control'), 'no-store');
  assert.equal(calls.length, 0);
});

test('Missing configuration returns 503', async (t) => {
  const { request, calls } = await setup(t, { apiKey: '' });

  assert.equal((await request('/status')).status, 503);
  assert.equal((await request('/routes/compute', {})).status, 503);
  assert.equal(calls.length, 0);
});

for (const token of [null, 'expired-token']) {
  test(`Reject ${token ?? 'missing'} token before Google calls`, async (t) => {
    const { request, calls } = await setup(t);

    assert.equal(
      (await request('/routes/compute', {}, token)).status,
      401,
    );
    assert.equal(calls.length, 0);
  });
}

test('Production Firebase verifier rejects malformed tokens', async (t) => {
  const { request, calls } = await setup(t, {
    verifyToken: undefined,
  });

  assert.equal((await request('/routes/compute', {})).status, 401);
  assert.equal(calls.length, 0);
});

// -----------------------------------------------------------------------------
// PLACE SEARCH AND SELECTION
// -----------------------------------------------------------------------------
const countries = [
  ['japan', 'jp'],
  ['australia', 'au'],
  ['united_states', 'us'],
  ['united_kingdom', 'gb'],
  ['south_korea', 'kr'],
];

for (const [countryId, code] of countries) {
  test(`Autocomplete restricts results to ${countryId}`, async (t) => {
    const { request, calls } = await setup(t, {
      data: {
        suggestions: [{
          placePrediction: {
            placeId: 'TokyoStation',
            text: { text: 'Tokyo Station, Japan' },
          },
        }],
      },
    });

    const result = await request('/places/autocomplete', {
      countryId,
      input: 'Tokyo',
      sessionToken: 'session-1',
    });

    assert.equal(result.status, 200);
    assert.deepEqual(result.body.places, [{
      placeId: 'TokyoStation',
      label: 'Tokyo Station, Japan',
    }]);

    const sent = JSON.parse(calls[0].options.body);

    assert.deepEqual(sent.includedRegionCodes, [code]);
    assert.equal(sent.sessionToken, 'session-1');
    assert.equal(
      calls[0].options.headers['X-Goog-Api-Key'],
      'test-server-key',
    );
  });
}

const invalidSearches = [
  { countryId: 'unknown', input: 'Tokyo' },
  { countryId: 'japan', input: 'T' },
  {
    countryId: 'japan',
    input: 'Tokyo',
    sessionToken: 'bad token',
  },
];

for (const body of invalidSearches) {
  test(`Reject invalid search: ${JSON.stringify(body)}`, async (t) => {
    const { request, calls } = await setup(t);

    assert.equal(
      (await request('/places/autocomplete', body)).status,
      400,
    );
    assert.equal(calls.length, 0);
  });
}

test('No autocomplete matches returns an empty list', async (t) => {
  const { request } = await setup(t);

  const result = await request('/places/autocomplete', {
    countryId: 'japan',
    input: 'Nowhere',
  });

  assert.deepEqual(result.body, { places: [] });
});

test('Details returns coordinates and forwards the search session', async (t) => {
  const { request, calls } = await setup(t, {
    data: {
      id: 'TokyoStation',
      formattedAddress: 'Tokyo, Japan',
      location: {
        latitude: 35.6812,
        longitude: 139.7671,
      },
      addressComponents: [{
        shortText: 'JP',
        types: ['country'],
      }],
    },
  });

  const result = await request('/places/details', {
    countryId: 'japan',
    placeId: 'TokyoStation',
    sessionToken: 'session-1',
  });

  assert.equal(result.status, 200);
  assert.equal(result.body.latitude, 35.6812);
  assert.equal(
    new URL(calls[0].url).searchParams.get('sessionToken'),
    'session-1',
  );
  assert.equal(
    calls[0].options.headers['X-Goog-FieldMask']
      .includes('displayName'),
    false,
  );
});

test('Reject a place outside the trip destination country', async (t) => {
  const { request } = await setup(t, {
    data: {
      addressComponents: [{
        shortText: 'US',
        types: ['country'],
      }],
    },
  });

  const result = await request('/places/details', {
    countryId: 'japan',
    placeId: 'OtherPlace',
  });

  assert.equal(result.status, 400);
});

// -----------------------------------------------------------------------------
// ROUTES AND FAILURE HANDLING
// -----------------------------------------------------------------------------
const routeInput = {
  originPlaceId: 'TokyoStation',
  destinationPlaceId: 'TokyoTower',
};

for (const travelMode of ['DRIVE', 'WALK']) {
  test(`${travelMode} returns route information and warnings`, async (t) => {
    const { request, calls } = await setup(t, {
      data: {
        routes: [{
          distanceMeters: 5000,
          duration: '600.5s',
          polyline: {
            encodedPolyline: 'encoded-shape',
          },
          description: 'Test route',
          warnings: ['Test route warning'],
        }],
      },
    });

    const result = await request('/routes/compute', {
      ...routeInput,
      travelMode,
    });

    assert.equal(result.status, 200);
    assert.equal(result.body.routes[0].durationSeconds, 600.5);
    assert.equal(
      result.body.routes[0].encodedPolyline,
      'encoded-shape',
    );
    assert.deepEqual(
      result.body.routes[0].warnings,
      ['Test route warning'],
    );
    assert.equal(result.body.trafficAware, false);

    const sent = JSON.parse(calls[0].options.body);

    assert.equal(
      sent.routingPreference,
      travelMode === 'DRIVE'
        ? 'TRAFFIC_UNAWARE'
        : undefined,
    );
    assert.equal(sent.computeAlternativeRoutes, true);
  });
}

const invalidRoutes = [
  { ...routeInput, travelMode: 'FLY' },
  {
    originPlaceId: 'Same',
    destinationPlaceId: 'Same',
  },
  {
    ...routeInput,
    originPlaceId: '../unsafe',
  },
];

for (const body of invalidRoutes) {
  test(`Reject invalid route: ${JSON.stringify(body)}`, async (t) => {
    const { request, calls } = await setup(t);

    assert.equal(
      (await request('/routes/compute', body)).status,
      400,
    );
    assert.equal(calls.length, 0);
  });
}

test('An unavailable route returns 404', async (t) => {
  const { request } = await setup(t, {
    data: { routes: [] },
  });

  assert.equal(
    (await request('/routes/compute', routeInput)).status,
    404,
  );
});

test('Incomplete geometry returns 502', async (t) => {
  const { request } = await setup(t, {
    data: {
      routes: [{
        distanceMeters: 10,
        duration: '1s',
      }],
    },
  });

  assert.equal(
    (await request('/routes/compute', routeInput)).status,
    502,
  );
});

test('Google failures do not expose its response or server key', async (t) => {
  const { request } = await setup(t, {
    upstreamStatus: 403,
    data: {
      error: { message: 'SECRET UPSTREAM DETAIL' },
    },
  });

  const result = await request('/routes/compute', routeInput);
  const returned = JSON.stringify(result.body);

  assert.equal(result.status, 503);
  assert.equal(returned.includes('SECRET'), false);
  assert.equal(returned.includes('test-server-key'), false);
});

test('Timeouts return 504', async (t) => {
  const { request } = await setup(t, {
    fetchImpl: async () => {
      throw new DOMException('Slow', 'TimeoutError');
    },
  });

  assert.equal(
    (await request('/routes/compute', routeInput)).status,
    504,
  );
});

test('User limits stop repeated requests before more Google calls', async (t) => {
  const { request, calls } = await setup(t);

  const search = {
    countryId: 'japan',
    input: 'Tokyo',
  };

  for (let index = 0; index < 60; index++) {
    assert.equal(
      (await request('/places/autocomplete', search)).status,
      200,
    );
  }

  assert.equal(
    (await request('/places/autocomplete', search)).status,
    429,
  );
  assert.equal(calls.length, 60);
});

// -----------------------------------------------------------------------------
// JOURNEYS WITH SEVERAL STOPS
// -----------------------------------------------------------------------------
// Check stop order, return trips and complete segments without Google calls.
const journeyResult = {
  routes: [{
    distanceMeters: 3000,
    duration: '900s',
    polyline: { encodedPolyline: 'encoded-shape' },
    legs: [
      { distanceMeters: 1000, duration: '300s' },
      { distanceMeters: 2000, duration: '600s' },
    ],
  }],
};

for (const travelMode of ['DRIVE', 'WALK']) {
  test(`Ordered stops are forwarded for ${travelMode}`, async (t) => {
    const { request, calls } = await setup(t, {
      data: {
        routes: [{
          ...journeyResult.routes[0],
          legs: [
            ...journeyResult.routes[0].legs,
            { distanceMeters: 0, duration: '0s' },
          ],
        }],
      },
    });

    const result = await request('/routes/compute', {
      ...routeInput,
      travelMode,
      intermediatePlaceIds: ['StopB', 'StopA'],
    });

    assert.equal(result.status, 200);
    assert.equal(result.body.routes[0].legs.length, 3);

    assert.deepEqual(result.body.routes[0].legs[1], {
      distanceMeters: 2000,
      durationSeconds: 600,
    });

    const sent = JSON.parse(calls[0].options.body);

    assert.deepEqual(sent.intermediates, [
      { placeId: 'StopB' },
      { placeId: 'StopA' },
    ]);

    assert.equal(sent.computeAlternativeRoutes, false);
    assert.equal(sent.optimizeWaypointOrder, false);

    assert.match(
      calls[0].options.headers['X-Goog-FieldMask'],
      /routes\.legs\.duration/,
    );
  });
}

test('A return trip is allowed with a different intermediate stop', async (t) => {
  const { request } = await setup(t, { data: journeyResult });

  const result = await request('/routes/compute', {
    originPlaceId: 'Hotel',
    destinationPlaceId: 'Hotel',
    intermediatePlaceIds: ['Museum'],
  });

  assert.equal(result.status, 200);
});

for (const intermediatePlaceIds of [
  null,
  'Museum',
  ['../unsafe'],
  Array.from({ length: 6 }, (_, i) => `Stop${i}`),
  ['TokyoStation'],
  ['Museum', 'Museum'],
  ['TokyoTower'],
]) {
  test(`Invalid stops are rejected: ${JSON.stringify(intermediatePlaceIds)}`, async (t) => {
    const { request, calls } = await setup(t);

    const result = await request('/routes/compute', {
      ...routeInput,
      intermediatePlaceIds,
    });

    assert.equal(result.status, 400);
    assert.equal(calls.length, 0);
  });
}

test('Five intermediate stops are accepted', async (t) => {
  const { request, calls } = await setup(t, {
    data: {
      routes: [{
        ...journeyResult.routes[0],
        legs: Array.from(
          { length: 6 },
          () => ({ distanceMeters: 100, duration: '10s' }),
        ),
      }],
    },
  });

  const result = await request('/routes/compute', {
    ...routeInput,
    intermediatePlaceIds: ['A', 'B', 'C', 'D', 'E'],
  });

  assert.equal(result.status, 200);
  assert.equal(
    JSON.parse(calls[0].options.body).intermediates.length,
    5,
  );
});

for (const legs of [
  undefined,
  [{ distanceMeters: 100, duration: '10s' }],
  [
    { distanceMeters: -1, duration: '10s' },
    { distanceMeters: 1, duration: '10s' },
  ],
]) {
  test(`Incomplete or invalid segments are rejected: ${JSON.stringify(legs)}`, async (t) => {
    const { request } = await setup(t, {
      data: {
        routes: [{ ...journeyResult.routes[0], legs }],
      },
    });

    const result = await request('/routes/compute', {
      ...routeInput,
      intermediatePlaceIds: ['Museum'],
    });

    assert.equal(result.status, 502);
  });
}