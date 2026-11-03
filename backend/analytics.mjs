// -----------------------------------------------------------------------------
// AGGREGATE CALCULATIONS
// -----------------------------------------------------------------------------
const purposes = ["tourism", "business", "study"];
const months = [
  "January",
  "February",
  "March",
  "April",
  "May",
  "June",
  "July",
  "August",
  "September",
  "October",
  "November",
  "December",
];
const monthFormatter = new Intl.DateTimeFormat("en", {
  timeZone: "Asia/Kuala_Lumpur",
  year: "numeric",
  month: "numeric",
});

// Use maps for database-derived keys and keep user records inside the server.
function increment(map, key, value = 1) {
  map.set(key, (map.get(key) ?? 0) + value);
}

// Group departure timestamps by the Malaysian calendar month.
function monthNumber(value) {
  const date =
    value?.toDate instanceof Function ? value.toDate() : new Date(value);
  if (value == null || Number.isNaN(date.getTime())) return null;
  const parts = Object.fromEntries(
    monthFormatter
      .formatToParts(date)
      .map(({ type, value: part }) => [type, part]),
  );
  return Number(parts.year) * 12 + Number(parts.month) - 1;
}

// Produce explicit aggregate response fields; never return the source records.
export function buildAnalytics(
  metric,
  { countries = [], trips = [], rules = [] },
  filters = {},
) {
  const names = new Map(
    countries.map((country) => [country.id, country.name || country.id]),
  );
  const selected = trips.filter(
    (trip) =>
      (!filters.destinationId ||
        trip.destinationCountryId === filters.destinationId) &&
      (!filters.purpose || trip.purpose === filters.purpose),
  );

  if (metric === "countries") {
    return countries
      .map((country) => ({ id: country.id, name: names.get(country.id) }))
      .sort((a, b) => a.name.localeCompare(b.name, "en"));
  }

  if (metric === "overview") {
    const counts = new Map();
    for (const trip of trips) {
      if (names.has(trip.destinationCountryId))
        increment(counts, trip.destinationCountryId);
    }
    const top = [...counts].sort((a, b) => b[1] - a[1])[0];
    return {
      totalTrips: trips.length,
      uniqueTravellers: new Set(
        trips.map((trip) => trip.userId).filter(Boolean),
      ).size,
      topDestination: top ? names.get(top[0]) : "No trip data",
      topDestinationTrips: top?.[1] ?? 0,
      supportedDestinations: countries.length,
    };
  }

  if (metric === "destinations") {
    const counts = new Map();
    for (const trip of selected) increment(counts, trip.destinationCountryId);
    return countries
      .filter(
        (country) =>
          !filters.destinationId || country.id === filters.destinationId,
      )
      .map((country) => ({
        countryId: country.id,
        name: names.get(country.id),
        count: counts.get(country.id) ?? 0,
        percentage: selected.length
          ? ((counts.get(country.id) ?? 0) / selected.length) * 100
          : 0,
      }))
      .sort((a, b) => b.count - a.count || a.name.localeCompare(b.name, "en"));
  }

  if (metric === "monthly") {
    const counts = new Map();
    for (const trip of selected) {
      const month = monthNumber(trip.departureDate);
      if (month !== null) increment(counts, month);
    }
    if (!counts.size) return [];
    const first = Math.min(...counts.keys());
    const last = Math.max(...counts.keys());
    // Reject corrupted dates instead of allocating an unbounded monthly series.
    if (last - first >= 1200)
      throw new Error("Monthly reporting period is too large.");
    return Array.from({ length: last - first + 1 }, (_, index) => {
      const key = first + index;
      const year = Math.floor(key / 12);
      const month = key % 12;
      return {
        year,
        month: month + 1,
        label: `${months[month]} ${year}`,
        shortLabel: `${months[month].slice(0, 3)} ${String(year).slice(-2)}`,
        count: counts.get(key) ?? 0,
      };
    });
  }

  if (metric === "purpose") {
    const counts = { tourism: 0, business: 0, study: 0 };
    for (const trip of selected) {
      if (purposes.includes(trip.purpose)) counts[trip.purpose]++;
    }
    return {
      total: Object.values(counts).reduce((sum, count) => sum + count, 0),
      counts,
    };
  }

  // Resolve requirement labels from curated regulations, not traveller text.
  const trustedRules = new Map(rules.map((rule) => [rule.id, rule]));
  const descriptor = (item) => {
    const rule = trustedRules.get(item.sourceRuleId);
    return rule
      ? {
          key: rule.id,
          sourceRuleId: rule.id,
          title:
            rule.title?.trim() ||
            rule.checklistLabel?.trim() ||
            "Unnamed requirement",
        }
      : { key: "unmapped", sourceRuleId: "", title: "Unnamed requirement" };
  };

  if (metric === "completion") {
    let total = 0;
    let completed = 0;
    let analysed = 0;
    let rateTotal = 0;
    const destinations = new Map();
    const purposeGroups = new Map();
    const requirements = new Map();

    // Average unrounded per-trip rates; empty checklists do not enter the average.
    for (const trip of selected) {
      const items = trip.items ?? [];
      if (!items.length) continue;
      const tripCompleted = items.filter(
        (item) => item.completed === true,
      ).length;
      const rate = (tripCompleted / items.length) * 100;
      total += items.length;
      completed += tripCompleted;
      analysed++;
      rateTotal += rate;

      for (const [key, groups] of [
        [trip.destinationCountryId, destinations],
        [trip.purpose, purposeGroups],
      ]) {
        if (
          !(groups === destinations ? names.has(key) : purposes.includes(key))
        )
          continue;
        const group = groups.get(key) ?? { count: 0, rate: 0 };
        group.count++;
        group.rate += rate;
        groups.set(key, group);
      }
      for (const item of items) {
        const { key, ...label } = descriptor(item);
        const group = requirements.get(key) ?? {
          ...label,
          generated: 0,
          completed: 0,
        };
        group.generated++;
        if (item.completed === true) group.completed++;
        requirements.set(key, group);
      }
    }

    return {
      overallCompletionRate: analysed ? rateTotal / analysed : 0,
      completedChecklistItems: completed,
      incompleteChecklistItems: total - completed,
      totalChecklistItems: total,
      tripsWithChecklist: analysed,
      destinationComparison: [...destinations]
        .map(([countryId, group]) => ({
          countryId,
          name: names.get(countryId),
          tripCount: group.count,
          completionRate: group.rate / group.count,
        }))
        .sort(
          (a, b) =>
            a.completionRate - b.completionRate ||
            a.name.localeCompare(b.name, "en"),
        ),
      purposeComparison: [...purposeGroups]
        .map(([purpose, group]) => ({
          purpose,
          tripCount: group.count,
          completionRate: group.rate / group.count,
        }))
        .sort(
          (a, b) =>
            a.completionRate - b.completionRate ||
            a.purpose.localeCompare(b.purpose, "en"),
        ),
      requirementsNeedingAttention: [...requirements.values()]
        .filter((group) => group.completed < group.generated)
        .map((group) => ({
          ...group,
          incomplete: group.generated - group.completed,
          completionRate: (group.completed / group.generated) * 100,
        }))
        .sort(
          (a, b) =>
            a.completionRate - b.completionRate ||
            b.generated - a.generated ||
            a.title.localeCompare(b.title, "en"),
        ),
    };
  }

  if (metric === "requirements") {
    let analysedTrips = 0;
    const requirements = new Map();
    for (const trip of selected) {
      if (!trip.items?.length) continue;
      analysedTrips++;
      const seen = new Set();
      for (const item of trip.items) {
        const label = descriptor(item);
        if (seen.has(label.key)) continue;
        seen.add(label.key);
        const group = requirements.get(label.key) ?? {
          title: label.title,
          tripCount: 0,
          destinations: new Map(),
          purposes: new Map(),
        };
        group.tripCount++;
        if (names.has(trip.destinationCountryId))
          increment(group.destinations, trip.destinationCountryId);
        if (purposes.includes(trip.purpose))
          increment(group.purposes, trip.purpose);
        requirements.set(label.key, group);
      }
    }
    return {
      analysedTrips,
      requirementPatterns: [...requirements]
        .map(([requirementKey, group]) => ({
          requirementKey,
          title: group.title,
          tripCount: group.tripCount,
          percentage: analysedTrips
            ? (group.tripCount / analysedTrips) * 100
            : 0,
          destinationBreakdown: [...group.destinations]
            .map(([countryId, tripCount]) => ({
              countryId,
              name: names.get(countryId),
              tripCount,
            }))
            .sort(
              (a, b) =>
                b.tripCount - a.tripCount || a.name.localeCompare(b.name, "en"),
            ),
          purposeBreakdown: [...group.purposes]
            .map(([purpose, tripCount]) => ({ purpose, tripCount }))
            .sort(
              (a, b) =>
                b.tripCount - a.tripCount ||
                a.purpose.localeCompare(b.purpose, "en"),
            ),
        }))
        .sort(
          (a, b) =>
            b.tripCount - a.tripCount || a.title.localeCompare(b.title, "en"),
        ),
    };
  }
  throw new Error("Unsupported analytics metric.");
}
