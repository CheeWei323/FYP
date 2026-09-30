import 'dotenv/config';
import express from 'express';
import { rateLimit } from 'express-rate-limit';
import { GoogleGenAI } from '@google/genai';

const app = express();
const port = 3000;

app.use(express.json());

const apiKey = process.env.GEMINI_API_KEY;

if (!apiKey) {
  throw new Error(
    'GEMINI_API_KEY was not found in backend/.env',
  );
}

const ai = new GoogleGenAI({
  apiKey,
});

const allowedPurposes = [
  'tourism',
  'business',
  'study',
];

const allowedCategories = [
  'clothing',
  'toiletries',
  'electronics',
  'healthComfort',
  'activityEssentials',
  'generalEssentials',
  'other',
];

// Limits repeated requests from the same client.
const packingGenerationLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: 5,
  standardHeaders: true,
  legacyHeaders: false,
  message: {
    error:
      'Too many packing-generation requests. Please try again later.',
  },
});

// Waits before retrying a temporary Gemini failure.
function delay(milliseconds) {
  return new Promise((resolve) => {
    setTimeout(resolve, milliseconds);
  });
}

// Checks whether Gemini returned a temporary high-demand error.
function isTemporaryGeminiError(error) {
  if (error?.status === 503) {
    return true;
  }

  const message = String(error?.message ?? error);

  return (
    message.includes('"code":503') ||
    message.includes('503') ||
    message.toLowerCase().includes('high demand') ||
    message.includes('UNAVAILABLE')
  );
}

// Calls Gemini and retries temporary 503 errors.
async function generateWithRetry(prompt) {
  const maximumAttempts = 3;

  for (
    let attempt = 1;
    attempt <= maximumAttempts;
    attempt++
  ) {
    try {
      return await ai.models.generateContent({
        model: 'gemini-3.1-flash-lite',
        contents: prompt,
        config: {
          responseMimeType: 'application/json',
          responseSchema: {
            type: 'object',
            properties: {
              items: {
                type: 'array',
                minItems: 15,
                maxItems: 25,
                items: {
                  type: 'object',
                  properties: {
                    name: {
                      type: 'string',
                      description:
                        'Short name of the packing item.',
                    },
                    category: {
                      type: 'string',
                      enum: allowedCategories,
                      description:
                        'One of the TravelGuard packing categories.',
                    },
                    quantity: {
                      type: 'integer',
                      minimum: 1,
                      description:
                        'Recommended quantity for the trip.',
                    },
                  },
                  required: [
                    'name',
                    'category',
                    'quantity',
                  ],
                },
              },
            },
            required: [
              'items',
            ],
          },
        },
      });
    } catch (error) {
      const temporaryError =
          isTemporaryGeminiError(error);

      if (
        !temporaryError ||
        attempt === maximumAttempts
      ) {
        throw error;
      }

      // 2 seconds after attempt 1, then 4 seconds after attempt 2.
      const waitTime =
          2000 * Math.pow(2, attempt - 1);

      console.warn(
        `Gemini temporarily unavailable. ` +
        `Retrying attempt ${attempt + 1} ` +
        `in ${waitTime / 1000} seconds...`,
      );

      await delay(waitTime);
    }
  }

  throw new Error(
    'Gemini generation failed after retries.',
  );
}

// Simple backend health-check endpoint.
app.get('/', (req, res) => {
  res.json({
    message: 'TravelGuard AI backend is running.',
  });
});

// Generates contextual packing recommendations.
app.post(
  '/api/packing/generate',
  packingGenerationLimiter,
  async (req, res) => {
    try {
      const {
        destination,
        purpose,
        durationDays,
        departureDate,
      } = req.body;

      // Validate destination.
      if (
        typeof destination !== 'string' ||
        destination.trim().length === 0
      ) {
        return res.status(400).json({
          error: 'A valid destination is required.',
        });
      }

      // Validate travel purpose.
      if (
        typeof purpose !== 'string' ||
        !allowedPurposes.includes(
          purpose.trim().toLowerCase(),
        )
      ) {
        return res.status(400).json({
          error: 'A valid travel purpose is required.',
        });
      }

      // Validate trip duration.
      if (
        !Number.isInteger(durationDays) ||
        durationDays < 1
      ) {
        return res.status(400).json({
          error: 'Duration must be at least one day.',
        });
      }

      // Validate departure date.
      if (
        typeof departureDate !== 'string' ||
        departureDate.trim().length === 0
      ) {
        return res.status(400).json({
          error: 'A valid departure date is required.',
        });
      }

      const cleanedDestination =
          destination.trim();

      const cleanedPurpose =
          purpose.trim().toLowerCase();

      const cleanedDepartureDate =
          departureDate.trim();

      const prompt = `
Generate a practical and personalised packing list for a Malaysian traveller.

Trip information:
Destination: ${cleanedDestination}
Travel purpose: ${cleanedPurpose}
Duration: ${durationDays} days
Departure date: ${cleanedDepartureDate}

The packing list is supplementary to TravelGuard MY's separate
rule-based regulatory travel checklist.

General requirements:
- Generate between 15 and 25 useful packing items.
- Personalise the recommendations using the destination,
  travel purpose, duration and departure date.
- Adjust reasonable quantities according to the duration of the trip.
- Keep item names concise and understandable.
- Avoid unnecessary duplicate items.
- Quantity must always be at least 1.

Season and climate:
- Use the destination and departure date to infer the likely season
  and general climate conditions for packing purposes.
- Recommend season-appropriate items when relevant.
- Examples may include jackets, warm layers, thermal clothing,
  rain protection, sunscreen, moisturiser or lip balm.
- Consider that the traveller is from Malaysia and may therefore
  benefit from additional preparation for substantially colder climates.
- Do not claim to know exact real-time weather conditions.
- Do not claim specific forecast temperatures, rainfall, snowfall
  or other current weather information unless such information
  has explicitly been provided to the system.

Travel-purpose personalisation:
- For tourism, consider practical sightseeing, walking and
  general travel essentials.
- For business, consider suitable business attire, work equipment,
  presentation-related essentials and other practical business items.
- For study, consider study equipment, stationery, electronics
  and practical items for an educational stay.

Regulatory boundary:
- Do not determine whether any travel document is mandatory.
- Do not provide visa, passport, immigration, customs,
  vaccination, health-entry or legal-entry requirements.
- Do not recommend documents such as invitation letters,
  admission letters, offer letters, Certificates of Eligibility,
  visa documents or immigration forms as regulatory requirements.
- TravelGuard MY handles those requirements separately using
  its validated rule-based regulatory checklist.
- Gemini is responsible only for supplementary contextual
  packing recommendations.

Allowed categories:
- clothing
- toiletries
- electronics
- healthComfort
- activityEssentials
- generalEssentials
- other

Return only the structured packing items requested by the schema.
`;

      const response =
          await generateWithRetry(prompt);

      if (!response.text) {
        throw new Error(
          'Gemini returned an empty response.',
        );
      }

      const result =
          JSON.parse(response.text);

      if (
        !result ||
        !Array.isArray(result.items)
      ) {
        throw new Error(
          'Gemini returned an invalid packing list.',
        );
      }

      // Validates Gemini output before returning it to Flutter.
      const items = result.items
        .filter((item) => {
          return (
            typeof item.name === 'string' &&
            item.name.trim().length > 0 &&
            allowedCategories.includes(
              item.category,
            ) &&
            Number.isInteger(item.quantity) &&
            item.quantity >= 1
          );
        })
        .map((item) => ({
          name: item.name.trim(),
          category: item.category,
          quantity: item.quantity,
        }));

      if (items.length === 0) {
        throw new Error(
          'Gemini did not return any valid packing items.',
        );
      }

      return res.status(200).json({
        items,
      });
    } catch (error) {
      console.error(
        'PACKING GENERATION ERROR:',
        error,
      );

      // Return a specific response for temporary Gemini congestion.
      if (isTemporaryGeminiError(error)) {
        return res.status(503).json({
          error:
            'Gemini is temporarily busy. Please try again shortly.',
        });
      }

      return res.status(500).json({
        error:
          'Unable to generate packing recommendations.',
      });
    }
  },
);

app.listen(port, () => {
  console.log(
    `TravelGuard AI backend running on http://localhost:${port}`,
  );
});