import "dotenv/config";
import express from "express";
import { rateLimit } from "express-rate-limit";
import { GoogleGenAI } from "@google/genai";
import { generatePackingWithFallback, isTemporaryGeminiError } from "./packing_generation.mjs";
import { createTravelRouter } from "./travel_routes.mjs";
import { createFirebaseAuth } from "./firebase_auth.mjs";
import { createAnalyticsRouter } from "./analytics_routes.mjs";

const app = express();
app.disable("x-powered-by");

const port = process.env.PORT || 3000;

app.set("trust proxy", 1);

app.use(express.json({ limit: "16kb" }));

// -----------------------------------------------------------------------------
// TRAVEL PLANNING API
// -----------------------------------------------------------------------------
// Add authenticated place searches and route calculations to the existing server.
app.use("/api/travel", createTravelRouter());

// Serve analyst aggregates without exposing traveller records.
app.use("/api/analytics", createAnalyticsRouter());

const apiKey = process.env.GEMINI_API_KEY;

if (!apiKey) {
  throw new Error("GEMINI_API_KEY environment variable is not configured.");
}

const ai = new GoogleGenAI({
  apiKey,
});

const allowedPurposes = ["tourism", "business", "study"];

const allowedCategories = [
  "clothing",
  "toiletries",
  "electronics",
  "healthComfort",
  "activityEssentials",
  "generalEssentials",
  "other",
];

// Limits repeated requests from the same client.
const packingGenerationLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: 5,
  standardHeaders: true,
  legacyHeaders: false,
  message: {
    error: "Too many packing-generation requests. Please try again later.",
  },
});

// Builds standard practical packing essentials.
// Everyday clothing is capped at a one-week packing cycle for longer trips.
function buildBaselinePackingItems(durationDays) {
  const clothingDays = Math.min(durationDays, 7);

  const bottomsQuantity = Math.min(4, Math.max(1, Math.ceil(clothingDays / 2)));

  const sleepwearQuantity = durationDays > 7 ? 2 : 1;

  return [
    {
      name: "Everyday tops",
      category: "clothing",
      quantity: clothingDays,
    },
    {
      name: "Everyday bottoms",
      category: "clothing",
      quantity: bottomsQuantity,
    },
    {
      name: "Underwear",
      category: "clothing",
      quantity: clothingDays,
    },
    {
      name: "Socks",
      category: "clothing",
      quantity: clothingDays,
    },
    {
      name: "Sleepwear",
      category: "clothing",
      quantity: sleepwearQuantity,
    },
    {
      name: "Toothbrush",
      category: "toiletries",
      quantity: 1,
    },
    {
      name: "Toothpaste",
      category: "toiletries",
      quantity: 1,
    },
    {
      name: "Deodorant",
      category: "toiletries",
      quantity: 1,
    },
    {
      name: "Phone charger",
      category: "electronics",
      quantity: 1,
    },
    {
      name: "Universal travel adapter",
      category: "electronics",
      quantity: 1,
    },
  ];
}

// Normalises names for duplicate checking.
function normalizeItemName(name) {
  return name.trim().toLowerCase().replace(/\s+/g, " ");
}

function addDependentPackingItems(items) {
  const normalizedNames = new Set(
    items.map((item) => normalizeItemName(item.name)),
  );

  const finalItems = [...items];

  const hasLaptop = normalizedNames.has("laptop");
  const hasLaptopCharger = normalizedNames.has("laptop charger");

  if (hasLaptop && !hasLaptopCharger) {
    finalItems.push({
      name: "Laptop charger",
      category: "electronics",
      quantity: 1,
    });
  }

  return finalItems;
}

// Retry temporary capacity failures using a second free Gemini model.
async function generateWithRetry(prompt) {
  return generatePackingWithFallback({
    ai,
    primaryModel: process.env.GEMINI_MODEL,
    fallbackModel: process.env.GEMINI_FALLBACK_MODEL,
    request: {
      contents: prompt,
      config: {
        responseMimeType: "application/json",
        responseSchema: {
          type: "object",
          properties: {
            items: {
              type: "array",
              minItems: 8,
              maxItems: 15,
              items: {
                type: "object",
                properties: {
                  name: {
                    type: "string",
                    description: "Short name of the packing item.",
                  },
                  category: {
                    type: "string",
                    enum: allowedCategories,
                    description: "One of the TravelGuard packing categories.",
                  },
                  quantity: {
                    type: "integer",
                    minimum: 1,
                    description: "Recommended quantity for the trip.",
                  },
                },
                required: ["name", "category", "quantity"],
              },
            },
          },
          required: ["items"],
        },
      },
    },
  });
}

// Simple backend health-check endpoint.
app.get("/", (req, res) => {
  res.json({
    message: "TravelGuard AI backend is running.",
  });
});

// Generates contextual packing recommendations.
app.post(
  "/api/packing/generate",
  packingGenerationLimiter,
  createFirebaseAuth({
    signInMessage: "Please sign in to generate packing suggestions.",
  }),
  async (req, res) => {
    try {
      const { destination, purpose, durationDays, departureDate } = req.body;

      // Validate destination.
      if (typeof destination !== "string" || destination.trim().length === 0) {
        return res.status(400).json({
          error: "A valid destination is required.",
        });
      }

      // Validate travel purpose.
      if (
        typeof purpose !== "string" ||
        !allowedPurposes.includes(purpose.trim().toLowerCase())
      ) {
        return res.status(400).json({
          error: "A valid travel purpose is required.",
        });
      }

      // Validate trip duration.
      if (!Number.isInteger(durationDays) || durationDays < 1) {
        return res.status(400).json({
          error: "Duration must be at least one day.",
        });
      }

      // Validate departure date.
      if (
        typeof departureDate !== "string" ||
        departureDate.trim().length === 0
      ) {
        return res.status(400).json({
          error: "A valid departure date is required.",
        });
      }

      const cleanedDestination = destination.trim();

      const cleanedPurpose = purpose.trim().toLowerCase();

      const cleanedDepartureDate = departureDate.trim();

      const prompt = `
Generate practical and personalised contextual packing recommendations
for a Malaysian traveller.

Trip information:
Destination: ${cleanedDestination}
Travel purpose: ${cleanedPurpose}
Duration: ${durationDays} days
Departure date: ${cleanedDepartureDate}

The packing recommendations are supplementary to TravelGuard MY's
separate rule-based regulatory travel checklist.

TravelGuard MY already adds these standard packing essentials:
- Everyday tops
- Everyday bottoms
- Underwear
- Socks
- Sleepwear
- Toothbrush
- Toothpaste
- Deodorant
- Phone charger

Do not repeat those standard items. You may still recommend a distinct
specialised item when the trip context justifies it, such as thermal
base layers, a winter coat, swimwear, formal business attire, hiking
footwear or other purpose-specific clothing.

General requirements:
- Generate between 8 and 15 additional contextual packing items.
- Personalise the recommendations using the destination,
  travel purpose, duration and departure date.
- Use sensible quantities for the specific item and trip context.
- For trips longer than one week, assume routine clothing can be
  washed or reused rather than recommending one item for every day.
- For long stays, assume that consumable toiletries and other replaceable
  everyday supplies can be replenished at the destination rather than
  recommending quantities for the entire trip duration.
- Keep item names concise and understandable.
- Avoid unnecessary duplicate or near-duplicate items.
- Quantity must always be at least 1.
- When recommending a laptop, also recommend a laptop charger.
- Include Local Sim Card or Roaming also, both must write in the name of that item
- Type of destination country adapter, universal adapter and universal travel adapter recommend only one

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

      const response = await generateWithRetry(prompt);

      if (!response.text) {
        throw new Error("Gemini returned an empty response.");
      }

      const result = JSON.parse(response.text);

      if (!result || !Array.isArray(result.items)) {
        throw new Error("Gemini returned an invalid packing list.");
      }

      // Validates Gemini output before it is merged with standard items.
      const contextualItems = result.items
        .filter((item) => {
          return (
            typeof item.name === "string" &&
            item.name.trim().length > 0 &&
            allowedCategories.includes(item.category) &&
            Number.isInteger(item.quantity) &&
            item.quantity >= 1
          );
        })
        .map((item) => ({
          name: item.name.trim(),
          category: item.category,
          quantity: item.quantity,
        }));

      if (contextualItems.length === 0) {
        throw new Error("Gemini did not return any valid packing items.");
      }

      const baselineItems = buildBaselinePackingItems(durationDays);

      // Removes exact-name duplicates from Gemini output and also
      // prevents duplicate contextual items from being returned.
      const seenNames = new Set(
        baselineItems.map((item) => normalizeItemName(item.name)),
      );

      const uniqueContextualItems = [];

      for (const item of contextualItems) {
        const normalizedName = normalizeItemName(item.name);

        if (seenNames.has(normalizedName)) {
          continue;
        }

        seenNames.add(normalizedName);
        uniqueContextualItems.push(item);
      }

      const mergedItems = [...baselineItems, ...uniqueContextualItems];

      const finalItems = addDependentPackingItems(mergedItems);

      return res.status(200).json({
        items: finalItems,
      });
    } catch (error) {
      console.error("PACKING GENERATION ERROR:", error);

      // Return a specific response for temporary Gemini congestion.
      if (isTemporaryGeminiError(error)) {
        return res.status(503).json({
          error: "Gemini is temporarily busy. Please try again shortly.",
        });
      }

      return res.status(500).json({
        error: "Unable to generate packing recommendations.",
      });
    }
  },
);

// Return safe JSON for malformed bodies and unexpected request failures.
app.use((error, req, res, next) => {
  if (res.headersSent) return next(error);
  const status = error.status === 413 ? 413 : error.status === 400 ? 400 : 500;
  return res.status(status).json({
    error:
      status === 413
        ? "The request is too large."
        : status === 400
          ? "The request body must contain valid JSON."
          : "The request could not be completed.",
  });
});

app.listen(port, "0.0.0.0", () => {
  console.log(`TravelGuard AI backend running on port ${port}`);
});
