const DEFAULT_PRIMARY_MODEL = "gemini-3.1-flash-lite";
const DEFAULT_FALLBACK_MODEL = "gemini-3.5-flash-lite";

// Only capacity errors should move a request to the fallback model.
export function isTemporaryGeminiError(error) {
  if (error?.status !== undefined) return Number(error.status) === 503;

  const message = String(error?.message ?? error);
  return (
    /"code"\s*:\s*503\b/.test(message) ||
    /"status"\s*:\s*"UNAVAILABLE"/.test(message)
  );
}

// Keep the schema unchanged and cap the complete operation at three API calls.
export async function generatePackingWithFallback({
  ai,
  request,
  primaryModel = DEFAULT_PRIMARY_MODEL,
  fallbackModel = DEFAULT_FALLBACK_MODEL,
  wait = (milliseconds) => new Promise((resolve) => setTimeout(resolve, milliseconds)),
  warn = (message) => console.warn(message),
}) {
  const primary = primaryModel.trim() || DEFAULT_PRIMARY_MODEL;
  const fallback = fallbackModel.trim() || DEFAULT_FALLBACK_MODEL;
  const models = [primary, fallback, fallback];

  for (let attempt = 0; attempt < models.length; attempt++) {
    const model = models[attempt];
    try {
      return await ai.models.generateContent({
        ...request,
        model,
        config: {
          ...request.config,
          httpOptions: {
            ...request.config?.httpOptions,
            retryOptions: {
              ...request.config?.httpOptions?.retryOptions,
              // The surrounding loop owns retries, avoiding nested SDK retries.
              attempts: 1,
            },
          },
        },
      });
    } catch (error) {
      if (!isTemporaryGeminiError(error) || attempt === models.length - 1) {
        throw error;
      }

      const milliseconds = 2000 * 2 ** attempt;
      warn(
        `Gemini model ${model} is temporarily unavailable. ` +
          `Retrying with ${models[attempt + 1]} in ${milliseconds / 1000} seconds...`,
      );
      await wait(milliseconds);
    }
  }
}
