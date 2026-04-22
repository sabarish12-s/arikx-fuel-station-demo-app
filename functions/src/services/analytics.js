const CreditTransaction = require('../models/CreditTransaction');
const DailySalesSummary = require('../models/DailySalesSummary');
const FuelPrice = require('../models/FuelPrice');
const ShiftEntry = require('../models/ShiftEntry');
const Station = require('../models/Station');
const User = require('../models/User');
const {getFirestore} = require('../config/firebase');
const {
  currentMonthInStationTimeZone,
  nowIso,
  todayInStationTimeZone,
} = require('../utils/time');
const {
  getDailyFuelRecordForDate,
  isCompleteRecord,
} = require('./dailyFuelRecords');

const DAILY_SUMMARY_BACKFILL_COLLECTION_NAME = 'dailySalesSummaryBackfillStatus';
const DAILY_SUMMARY_BACKFILL_VERSION = '2026-04-22-opening-readings';
const stationSummaryBackfillPromises = new Map();

function roundNumber(value) {
  return Math.round((Number(value || 0) + Number.EPSILON) * 100) / 100;
}

function filterEntriesByRange(entries, {month, fromDate, toDate} = {}) {
  return entries.filter((entry) => {
    const date = String(entry.date || '');
    if (month && !date.startsWith(month)) {
      return false;
    }
    if (fromDate && date < fromDate) {
      return false;
    }
    if (toDate && date > toDate) {
      return false;
    }
    return true;
  });
}

function filterTransactionsByRange(transactions, {month, fromDate, toDate} = {}) {
  return transactions.filter((transaction) => {
    const date = String(transaction.date || '');
    if (month && !date.startsWith(month)) {
      return false;
    }
    if (fromDate && date < fromDate) {
      return false;
    }
    if (toDate && date > toDate) {
      return false;
    }
    return true;
  });
}

function approvedEntries(entries) {
  return (entries || []).filter((entry) => ShiftEntry.isFinalized(entry));
}

function submittedEntries(entries) {
  return (entries || []).filter((entry) => String(entry.status || '').trim() !== 'draft');
}

function sumEntries(entries) {
  return entries.reduce(
    (accumulator, entry) => {
      accumulator.petrolSold += Number(entry.totals?.sold?.petrol || 0);
      accumulator.dieselSold += Number(entry.totals?.sold?.diesel || 0);
      accumulator.twoTSold += Number(entry.totals?.sold?.twoT || 0);
      accumulator.revenue += Number(entry.revenue || 0);
      accumulator.paymentTotal += Number(entry.paymentTotal || 0);
      accumulator.profit += Number(entry.profit || 0);
      accumulator.creditTotal += Number(entry.creditTotal || 0);
      if (entry.flagged || entry.status === 'flagged') {
        accumulator.flaggedCount += 1;
      }
      return accumulator;
    },
    {
      petrolSold: 0,
      dieselSold: 0,
      twoTSold: 0,
      revenue: 0,
      paymentTotal: 0,
      profit: 0,
      creditTotal: 0,
      flaggedCount: 0,
    },
  );
}

function sumTransactionAmounts(transactions) {
  return roundNumber(
    transactions.reduce(
      (sum, transaction) => sum + Number(transaction.amount || 0),
      0,
    ),
  );
}

function emptyPaymentBreakdown() {
  return {cash: 0, check: 0, upi: 0, credit: 0};
}

function addPaymentAmount(target, mode, amount) {
  const key = ['cash', 'check', 'upi', 'credit'].includes(mode) ? mode : 'cash';
  target[key] += Number(amount || 0);
}

function addEntryPaymentBreakdown(target, entry) {
  for (const payment of Object.values(entry.pumpPayments || {})) {
    addPaymentAmount(target, 'cash', payment.cash);
    addPaymentAmount(target, 'check', payment.check);
    addPaymentAmount(target, 'upi', payment.upi);
    addPaymentAmount(target, 'credit', payment.credit);
  }

  addPaymentAmount(target, 'cash', entry.paymentBreakdown?.cash);
  addPaymentAmount(target, 'check', entry.paymentBreakdown?.check);
  addPaymentAmount(target, 'upi', entry.paymentBreakdown?.upi);

  for (const collection of entry.creditCollections || []) {
    addPaymentAmount(target, collection.paymentMode || 'cash', collection.amount);
  }
}

function roundPaymentBreakdown(breakdown) {
  return {
    cash: roundNumber(breakdown.cash),
    check: roundNumber(breakdown.check),
    upi: roundNumber(breakdown.upi),
    credit: roundNumber(breakdown.credit),
  };
}

function isoDateToUtcDate(date) {
  const [year = '0', month = '1', day = '1'] = String(date || '').split('-');
  return new Date(Date.UTC(Number(year), Number(month) - 1, Number(day)));
}

function utcDateToIsoDate(date) {
  return `${date.getUTCFullYear()}-${String(date.getUTCMonth() + 1).padStart(2, '0')}-${String(
    date.getUTCDate(),
  ).padStart(2, '0')}`;
}

function shiftIsoDate(date, offsetDays) {
  const shifted = isoDateToUtcDate(date);
  shifted.setUTCDate(shifted.getUTCDate() + offsetDays);
  return utcDateToIsoDate(shifted);
}

function startOfMonth(date) {
  const source = isoDateToUtcDate(date);
  source.setUTCDate(1);
  return utcDateToIsoDate(source);
}

function endOfMonth(date) {
  const source = isoDateToUtcDate(date);
  source.setUTCMonth(source.getUTCMonth() + 1, 0);
  return utcDateToIsoDate(source);
}

function formatRangeDate(date) {
  return new Intl.DateTimeFormat('en-US', {
    month: 'short',
    day: 'numeric',
    year: 'numeric',
    timeZone: 'UTC',
  }).format(isoDateToUtcDate(date));
}

function resolveDashboardRange({preset, fromDate, toDate} = {}) {
  const today = todayInStationTimeZone();
  const normalizedPreset = String(preset || '').trim() || 'today';

  if (fromDate || toDate) {
    const resolvedFrom = String(fromDate || toDate || today);
    const resolvedTo = String(toDate || fromDate || today);
    const start = resolvedFrom <= resolvedTo ? resolvedFrom : resolvedTo;
    const end = resolvedFrom <= resolvedTo ? resolvedTo : resolvedFrom;
    return {
      preset: 'custom',
      label: start === end ? formatRangeDate(start) : `${formatRangeDate(start)} - ${formatRangeDate(end)}`,
      fromDate: start,
      toDate: end,
    };
  }

  if (normalizedPreset === 'last7') {
    return {
      preset: 'last7',
      label: 'Last 7 Days',
      fromDate: shiftIsoDate(today, -6),
      toDate: today,
    };
  }

  if (normalizedPreset === 'thisMonth') {
    return {
      preset: 'thisMonth',
      label: 'This Month',
      fromDate: startOfMonth(today),
      toDate: today,
    };
  }

  if (normalizedPreset === 'lastMonth') {
    const previousMonthDate = shiftIsoDate(startOfMonth(today), -1);
    return {
      preset: 'lastMonth',
      label: 'Last Month',
      fromDate: startOfMonth(previousMonthDate),
      toDate: endOfMonth(previousMonthDate),
    };
  }

  return {
    preset: 'today',
    label: 'Today',
    fromDate: today,
    toDate: today,
  };
}

function resolveEntryFetchRange({month, fromDate, toDate} = {}) {
  if (fromDate || toDate) {
    return {
      fromDate: String(fromDate || toDate || ''),
      toDate: String(toDate || fromDate || ''),
    };
  }
  const normalizedMonth = String(month || currentMonthInStationTimeZone());
  const monthStart = `${normalizedMonth}-01`;
  return {
    fromDate: monthStart,
    toDate: endOfMonth(monthStart),
  };
}

function paymentTotalForPump(payment = {}) {
  return roundNumber(
    Number(payment.cash || 0) +
      Number(payment.check || 0) +
      Number(payment.upi || 0) +
      Number(payment.credit || 0),
  );
}

function computeSalesValue(readings = {}, priceMap = {}) {
  return roundNumber(
    Number(readings.petrol || 0) * Number(priceMap.petrol?.sellingPrice || 0) +
      Number(readings.diesel || 0) * Number(priceMap.diesel?.sellingPrice || 0) +
      Number(readings.twoT || 0) * Number(priceMap.two_t_oil?.sellingPrice || 0),
  );
}

function createFuelAccumulator() {
  return {petrol: 0, diesel: 0, twoT: 0};
}

function addReadings(target, source = {}) {
  target.petrol += Number(source.petrol || 0);
  target.diesel += Number(source.diesel || 0);
  target.twoT += Number(source.twoT || 0);
}

function totalLiters(readings = {}) {
  return roundNumber(
    Number(readings.petrol || 0) + Number(readings.diesel || 0) + Number(readings.twoT || 0),
  );
}

function roundedReadings(readings = {}) {
  return {
    petrol: roundNumber(readings.petrol || 0),
    diesel: roundNumber(readings.diesel || 0),
    twoT: roundNumber(readings.twoT || 0),
  };
}

function normalizeAttendantName(value) {
  const trimmed = String(value || '').trim();
  return trimmed || 'Unassigned';
}

function formatSalesmanDisplayLabel(value = {}) {
  const salesmanName = String(value?.salesmanName || value?.name || '').trim();
  const salesmanCode = String(value?.salesmanCode || value?.code || '').trim().toUpperCase();
  if (salesmanName && salesmanCode) {
    return `${salesmanName} (${salesmanCode})`;
  }
  if (salesmanName) {
    return salesmanName;
  }
  if (salesmanCode) {
    return salesmanCode;
  }
  return '';
}

function performanceAttendantLabel(entry, pumpId) {
  const structuredLabel = formatSalesmanDisplayLabel(entry?.pumpSalesmen?.[pumpId]);
  return normalizeAttendantName(structuredLabel || entry?.pumpAttendants?.[pumpId] || '');
}

function buildSalesDashboardStation(station) {
  return {
    id: station?.id || '',
    name: station?.name || '',
    pumps: station?.pumps || [],
    meterLimits: station?.meterLimits || {},
    flagThreshold: Number(station?.flagThreshold ?? 0.01),
    salesmen: station?.salesmen || [],
  };
}

function buildStationNamePayload(station) {
  return {
    id: station?.id || '',
    name: station?.name || '',
  };
}

function finalizedEntryForDate(entries = [], date = '') {
  return entries.find(
    (entry) => entry.date === date && ShiftEntry.isFinalized(entry),
  ) || null;
}

function standaloneCollectionsForDate(transactions = [], date = '') {
  return transactions.filter(
    (transaction) =>
      transaction.type === 'collection' &&
      !transaction.entryId &&
      transaction.date === date,
  );
}

function createEmptyDailySummary(date) {
  return {
    date,
    totals: {
      revenue: 0,
      paymentTotal: 0,
      profit: 0,
      petrolSold: 0,
      dieselSold: 0,
      twoTSold: 0,
      creditTotal: 0,
      flaggedCount: 0,
      entriesCompleted: 0,
      shiftsCompleted: 0,
    },
    paymentBreakdown: roundPaymentBreakdown(emptyPaymentBreakdown()),
    fuelBreakdown: {
      petrol: 0,
      diesel: 0,
      two_t_oil: 0,
    },
    distribution: [],
    entries: [],
    trend: {
      date,
      revenue: 0,
      paymentTotal: 0,
      profit: 0,
      petrolSold: 0,
      dieselSold: 0,
      twoTSold: 0,
      entries: 0,
      shifts: 0,
    },
  };
}

function buildDailySummaryPayload({
  date,
  entry = null,
  standaloneCollections = [],
} = {}) {
  const base = createEmptyDailySummary(date);
  const entries = entry ? [entry] : [];
  const totals = sumEntries(entries);
  const paymentBreakdown = emptyPaymentBreakdown();

  for (const item of entries) {
    addEntryPaymentBreakdown(paymentBreakdown, item);
  }

  const standaloneCollectionTotal = sumTransactionAmounts(standaloneCollections);
  for (const transaction of standaloneCollections) {
    addPaymentAmount(
      paymentBreakdown,
      transaction.paymentMode || 'cash',
      transaction.amount,
    );
  }

  return {
    date,
    totals: {
      revenue: roundNumber(totals.revenue),
      paymentTotal: roundNumber(totals.paymentTotal + standaloneCollectionTotal),
      profit: roundNumber(totals.profit),
      petrolSold: roundNumber(totals.petrolSold),
      dieselSold: roundNumber(totals.dieselSold),
      twoTSold: roundNumber(totals.twoTSold),
      creditTotal: roundNumber(totals.creditTotal),
      flaggedCount: totals.flaggedCount,
      entriesCompleted: entries.length,
      shiftsCompleted: entries.length,
    },
    paymentBreakdown: roundPaymentBreakdown(paymentBreakdown),
    fuelBreakdown: {
      petrol: roundNumber(totals.petrolSold),
      diesel: roundNumber(totals.dieselSold),
      two_t_oil: roundNumber(totals.twoTSold),
    },
    distribution: entries.map((item) => ({
      shift: 'daily',
      revenue: roundNumber(item.revenue || 0),
      petrolSold: roundNumber(item.totals?.sold?.petrol || 0),
      dieselSold: roundNumber(item.totals?.sold?.diesel || 0),
      twoTSold: roundNumber(item.totals?.sold?.twoT || 0),
      status: item.status,
    })),
    entries: entries.map((item) => item.toJson()),
    trend: {
      date,
      revenue: roundNumber(totals.revenue),
      paymentTotal: roundNumber(totals.paymentTotal + standaloneCollectionTotal),
      profit: roundNumber(totals.profit),
      petrolSold: roundNumber(totals.petrolSold),
      dieselSold: roundNumber(totals.dieselSold),
      twoTSold: roundNumber(totals.twoTSold),
      entries: entries.length,
      shifts: entries.length,
    },
    hasContent: entries.length > 0 || standaloneCollections.length > 0,
  };
}

async function buildDailySummaryForDate(stationId, date) {
  const [allEntries, creditTransactions] = await Promise.all([
    ShiftEntry.allForStationRange(stationId, {
      fromDate: date,
      toDate: date,
    }),
    CreditTransaction.allForStationRange(stationId, {
      fromDate: date,
      toDate: date,
    }),
  ]);
  const entry = finalizedEntryForDate(allEntries, date);
  const entries = entry ? [entry] : [];
  await ShiftEntry.attachSubmittedByNames(entries);
  return buildDailySummaryPayload({
    date,
    entry: entries[0] || null,
    standaloneCollections: standaloneCollectionsForDate(creditTransactions, date),
  });
}

async function syncDailySalesSummaryForDate(stationId, date) {
  if (!stationId || !date) {
    return null;
  }

  const payload = await buildDailySummaryForDate(stationId, date);
  const existingSummary = await DailySalesSummary.findByDate(stationId, date);

  if (!payload.hasContent) {
    if (existingSummary) {
      await existingSummary.deletePermanent();
    }
    return createEmptyDailySummary(date);
  }

  const summary = new DailySalesSummary({
    ...(existingSummary?.toJson() || {}),
    stationId,
    date,
    totals: payload.totals,
    paymentBreakdown: payload.paymentBreakdown,
    fuelBreakdown: payload.fuelBreakdown,
    distribution: payload.distribution,
    entries: payload.entries,
    trend: payload.trend,
    updatedAt: nowIso(),
  });
  await summary.save();
  return summary.toApiJson();
}

async function backfillDailySalesSummariesForStation(stationId) {
  const [entries, creditTransactions, existingSummaries] = await Promise.all([
    ShiftEntry.allForStation(stationId, {forceRefresh: true}),
    CreditTransaction.allForStation(stationId),
    DailySalesSummary.allForStationRange(stationId),
  ]);

  const finalizedEntriesByDate = new Map();
  for (const entry of entries) {
    if (!ShiftEntry.isFinalized(entry)) {
      continue;
    }
    finalizedEntriesByDate.set(entry.date, entry);
  }
  await ShiftEntry.attachSubmittedByNames([...finalizedEntriesByDate.values()]);

  const standaloneCollectionsByDate = new Map();
  for (const transaction of creditTransactions) {
    if (transaction.type !== 'collection' || transaction.entryId) {
      continue;
    }
    const current = standaloneCollectionsByDate.get(transaction.date) || [];
    current.push(transaction);
    standaloneCollectionsByDate.set(transaction.date, current);
  }

  const dates = [...new Set([
    ...finalizedEntriesByDate.keys(),
    ...standaloneCollectionsByDate.keys(),
  ])].sort((left, right) => left.localeCompare(right));
  const datesWithContent = new Set(dates);

  for (const date of dates) {
    const payload = buildDailySummaryPayload({
      date,
      entry: finalizedEntriesByDate.get(date) || null,
      standaloneCollections: standaloneCollectionsByDate.get(date) || [],
    });
    if (!payload.hasContent) {
      continue;
    }
    await new DailySalesSummary({
      stationId,
      date,
      totals: payload.totals,
      paymentBreakdown: payload.paymentBreakdown,
      fuelBreakdown: payload.fuelBreakdown,
      distribution: payload.distribution,
      entries: payload.entries,
      trend: payload.trend,
      updatedAt: nowIso(),
    }).save();
  }

  for (const summary of existingSummaries) {
    if (!datesWithContent.has(summary.date)) {
      await summary.deletePermanent();
    }
  }

  return {stationId, synced: dates.length};
}

async function ensureDailySalesSummariesBackfilled(stationId) {
  if (!stationId) {
    return;
  }

  const backfillRef = getFirestore()
    .collection(DAILY_SUMMARY_BACKFILL_COLLECTION_NAME)
    .doc(stationId);
  const backfillSnapshot = await backfillRef.get();
  const backfillStatus = backfillSnapshot.exists ? backfillSnapshot.data() || {} : {};
  if (backfillStatus.version === DAILY_SUMMARY_BACKFILL_VERSION) {
    return;
  }

  const existingPromise = stationSummaryBackfillPromises.get(stationId);
  if (existingPromise) {
    await existingPromise;
    return;
  }

  const nextPromise = (async () => {
    await backfillDailySalesSummariesForStation(stationId);
    await backfillRef.set({
      stationId,
      version: DAILY_SUMMARY_BACKFILL_VERSION,
      completedAt: nowIso(),
    }, {merge: true});
  })();
  stationSummaryBackfillPromises.set(stationId, nextPromise);

  try {
    await nextPromise;
  } finally {
    stationSummaryBackfillPromises.delete(stationId);
  }
}

function buildOwnerPerformance(station, entries, fallbackPriceMap) {
  const pumps = station?.pumps || [];
  const pumpPerformance = new Map(
    pumps.map((pump) => [
      pump.id,
      {
        pumpId: pump.id,
        pumpLabel: pump.label || pump.id,
        liters: createFuelAccumulator(),
        collectedAmount: 0,
        computedSalesValue: 0,
        variance: 0,
        attendantsSeen: new Set(),
      },
    ]),
  );
  const attendantPerformance = new Map();
  const trend = new Map();

  for (const entry of entries) {
    const priceMap =
      entry.priceSnapshot && Object.keys(entry.priceSnapshot).length > 0
        ? entry.priceSnapshot
        : fallbackPriceMap;

    for (const pump of pumps) {
      const sold = entry.soldByPump?.[pump.id] || createFuelAccumulator();
      const collectedAmount = paymentTotalForPump(entry.pumpPayments?.[pump.id]);
      const computedSalesValue = computeSalesValue(sold, priceMap);
      const variance = roundNumber(collectedAmount - computedSalesValue);
      const rawAttendant = performanceAttendantLabel(entry, pump.id);
      const attendantName = normalizeAttendantName(rawAttendant);
      const hasContribution =
        totalLiters(sold) > 0 || collectedAmount !== 0 || computedSalesValue !== 0;
      const hasAttendance = rawAttendant.length > 0 || hasContribution;

      const pumpItem = pumpPerformance.get(pump.id);
      addReadings(pumpItem.liters, sold);
      pumpItem.collectedAmount += collectedAmount;
      pumpItem.computedSalesValue += computedSalesValue;
      pumpItem.variance += variance;
      if (hasAttendance) {
        pumpItem.attendantsSeen.add(attendantName);
      }

      if (!hasAttendance) {
        continue;
      }

      const attendantItem = attendantPerformance.get(attendantName) || {
        attendantName,
        liters: createFuelAccumulator(),
        collectedAmount: 0,
        computedSalesValue: 0,
        variance: 0,
        activeDays: new Set(),
        pumpsWorked: new Set(),
      };
      addReadings(attendantItem.liters, sold);
      attendantItem.collectedAmount += collectedAmount;
      attendantItem.computedSalesValue += computedSalesValue;
      attendantItem.variance += variance;
      attendantItem.activeDays.add(entry.date);
      attendantItem.pumpsWorked.add(pump.label || pump.id);
      attendantPerformance.set(attendantName, attendantItem);
    }

    const dayItem = trend.get(entry.date) || {
      date: entry.date,
      totalLiters: 0,
      petrolSold: 0,
      dieselSold: 0,
      collectedAmount: 0,
      computedSalesValue: 0,
      approvedEntries: 0,
    };
    dayItem.totalLiters += totalLiters(entry.totals?.sold || {});
    dayItem.petrolSold  += Number(entry.totals?.sold?.petrol || 0);
    dayItem.dieselSold  += Number(entry.totals?.sold?.diesel || 0);
    dayItem.collectedAmount += Number(entry.paymentTotal || 0);
    dayItem.computedSalesValue += Number(entry.computedRevenue || entry.revenue || 0);
    dayItem.approvedEntries += 1;
    trend.set(entry.date, dayItem);
  }

  return {
    pumpPerformance: [...pumpPerformance.values()]
      .map((item) => ({
        pumpId: item.pumpId,
        pumpLabel: item.pumpLabel,
        liters: roundedReadings(item.liters),
        totalLiters: totalLiters(item.liters),
        collectedAmount: roundNumber(item.collectedAmount),
        computedSalesValue: roundNumber(item.computedSalesValue),
        variance: roundNumber(item.variance),
        attendantsSeen: [...item.attendantsSeen].sort((a, b) => a.localeCompare(b)),
      }))
      .sort((a, b) => b.collectedAmount - a.collectedAmount),
    attendantPerformance: [...attendantPerformance.values()]
      .map((item) => ({
        attendantName: item.attendantName,
        liters: roundedReadings(item.liters),
        totalLiters: totalLiters(item.liters),
        collectedAmount: roundNumber(item.collectedAmount),
        computedSalesValue: roundNumber(item.computedSalesValue),
        variance: roundNumber(item.variance),
        activeDays: item.activeDays.size,
        pumpsWorked: [...item.pumpsWorked].sort((a, b) => a.localeCompare(b)),
      }))
      .sort((a, b) => b.collectedAmount - a.collectedAmount),
    trend: [...trend.values()]
      .sort((a, b) => a.date.localeCompare(b.date))
      .map((item) => ({
        date: item.date,
        totalLiters: roundNumber(item.totalLiters),
        petrolSold: roundNumber(item.petrolSold || 0),
        dieselSold: roundNumber(item.dieselSold || 0),
        collectedAmount: roundNumber(item.collectedAmount),
        computedSalesValue: roundNumber(item.computedSalesValue),
        approvedEntries: item.approvedEntries,
      })),
  };
}

async function getManagementDashboard(stationId, {preset, fromDate, toDate} = {}) {
  const range = resolveDashboardRange({preset, fromDate, toDate});
  const [station, priceSnapshot, entries, users, creditTransactions, accessState] = await Promise.all([
    Station.findById(stationId),
    FuelPrice.getSnapshot(range.toDate, stationId),
    ShiftEntry.allForStationRange(stationId, {
      fromDate: range.fromDate,
      toDate: range.toDate,
    }),
    User.find(),
    CreditTransaction.allForStationRange(stationId, {
      fromDate: range.fromDate,
      toDate: range.toDate,
    }),
    ShiftEntry.getEntryAccessState(stationId),
  ]);
  const dailyFuelRecord = accessState.allowedEntryDate
    ? await getDailyFuelRecordForDate(stationId, accessState.allowedEntryDate)
    : null;

  const rangeEntries = submittedEntries(filterEntriesByRange(entries, {
    fromDate: range.fromDate,
    toDate: range.toDate,
  }));
  const approvedRangeEntries = approvedEntries(rangeEntries);
  const totals = sumEntries(approvedRangeEntries);
  const standaloneCollections = filterTransactionsByRange(
    creditTransactions.filter(
      (transaction) => transaction.type === 'collection' && !transaction.entryId,
    ),
    {
      fromDate: range.fromDate,
      toDate: range.toDate,
    },
  );
  const standaloneCollectionTotal = sumTransactionAmounts(standaloneCollections);
  const performance = buildOwnerPerformance(station, approvedRangeEntries, priceSnapshot);
  const pendingRequests = users.filter((user) => user.status === 'pending').length;
  const flaggedCount = rangeEntries.filter(
    (entry) => entry.flagged || entry.status === 'flagged',
  ).length;
  const varianceCount = approvedRangeEntries.filter(
    (entry) =>
      Math.abs(Number(entry.mismatchAmount || 0)) >= 0.01 ||
      String(entry.varianceNote || '').trim().length > 0,
  ).length;
  const standaloneCollectionByDate = new Map();
  for (const transaction of standaloneCollections) {
    standaloneCollectionByDate.set(
      transaction.date,
      roundNumber(
        Number(standaloneCollectionByDate.get(transaction.date) || 0) +
          Number(transaction.amount || 0),
      ),
    );
  }
  const trend = performance.trend.map((item) => ({
    ...item,
    collectedAmount: roundNumber(
      Number(item.collectedAmount || 0) +
        Number(standaloneCollectionByDate.get(item.date) || 0),
    ),
  }));
  for (const [date, amount] of standaloneCollectionByDate.entries()) {
    if (!trend.some((item) => item.date === date)) {
      trend.push({
        date,
        totalLiters: 0,
        collectedAmount: roundNumber(amount),
        computedSalesValue: 0,
        approvedEntries: 0,
      });
    }
  }
  trend.sort((a, b) => a.date.localeCompare(b.date));

  return {
    station: buildStationNamePayload(station),
    today: todayInStationTimeZone(),
    range,
    setupExists: accessState.setupExists,
    allowedEntryDate: accessState.allowedEntryDate,
    activeSetupDate: accessState.activeSetupDate,
    entryLockedReason: accessState.entryLockedReason,
    dailyFuelRecord,
    dailyFuelRecordComplete: isCompleteRecord(dailyFuelRecord),
    pendingRequests,
    varianceCount,
    totals: {
      petrolSold: roundNumber(totals.petrolSold),
      dieselSold: roundNumber(totals.dieselSold),
      twoTSold: roundNumber(totals.twoTSold),
      revenue: roundNumber(totals.revenue),
      paymentTotal: roundNumber(totals.paymentTotal + standaloneCollectionTotal),
      profit: roundNumber(totals.profit),
      flaggedCount,
      entriesCompleted: approvedRangeEntries.length,
      shiftsCompleted: approvedRangeEntries.length,
    },
    pumpPerformance: performance.pumpPerformance,
    attendantPerformance: performance.attendantPerformance,
    trend,
  };
}

async function getSalesDashboard(stationId, date = todayInStationTimeZone()) {
  const today = todayInStationTimeZone();
  const accessState = await ShiftEntry.getEntryAccessState(stationId);
  const targetDate = accessState.allowedEntryDate || String(date || today);
  const rangeStart = String(targetDate) < String(today) ? String(targetDate) : String(today);
  const rangeEnd = String(targetDate) > String(today) ? String(targetDate) : String(today);
  const [
    station,
    entries,
    creditTransactions,
    priceSnapshot,
    dailyFuelRecord,
    setupOpeningReadings,
  ] = await Promise.all([
    Station.findById(stationId),
    ShiftEntry.allForStationRange(stationId, {
      fromDate: rangeStart,
      toDate: rangeEnd,
      includePrevious: true,
    }),
    CreditTransaction.allForStationRange(stationId, {
      fromDate: today,
      toDate: today,
    }),
    FuelPrice.getSnapshot(targetDate, stationId),
    getDailyFuelRecordForDate(stationId, targetDate),
    ShiftEntry.openingReadingsFor(stationId, targetDate),
  ]);
  const orderedEntries = [...entries].sort((a, b) => String(a.date).localeCompare(String(b.date)));
  const previousEntry =
    orderedEntries.filter((entry) => String(entry.date) < String(targetDate)).at(-1) || null;
  const selectedEntry = orderedEntries.find((entry) => entry.date === targetDate) || null;
  const resolvedOpeningReadings =
    setupOpeningReadings ||
    selectedEntry?.openingReadings ||
    previousEntry?.closingReadings ||
    station?.baseReadings ||
    {};
  if (selectedEntry && !ShiftEntry.isFinalized(selectedEntry)) {
    selectedEntry.openingReadings = resolvedOpeningReadings;
  }

  const todaysApprovedEntries = approvedEntries(orderedEntries).filter(
    (entry) => entry.date === today,
  );
  const todaysEntries = orderedEntries.filter(
    (entry) => entry.date === today && String(entry.status || '').trim() !== 'draft',
  );
  const todaysTotals = sumEntries(todaysApprovedEntries);
  const todaysStandaloneCollections = creditTransactions.filter(
    (transaction) =>
      transaction.type === 'collection' &&
      !transaction.entryId &&
      transaction.date === today,
  );
  const standaloneCollectionTotal = sumTransactionAmounts(todaysStandaloneCollections);

  return {
    station: buildSalesDashboardStation(station),
    date: targetDate,
    allowedEntryDate: accessState.allowedEntryDate,
    activeSetupDate: accessState.activeSetupDate,
    setupExists: accessState.setupExists,
    entryLockedReason:
      accessState.entryLockedReason ||
      (String(date || '').trim() &&
      String(date || '').trim() !== targetDate
        ? `Sales entry is locked to ${targetDate}.`
        : ''),
    dailyFuelRecord,
    dailyFuelRecordComplete: isCompleteRecord(dailyFuelRecord),
    openingReadings: resolvedOpeningReadings,
    priceSnapshot,
    selectedEntry: selectedEntry ? selectedEntry.toJson() : null,
    entryExists: selectedEntry != null,
    totals: {
      petrolSold: roundNumber(todaysTotals.petrolSold),
      dieselSold: roundNumber(todaysTotals.dieselSold),
      twoTSold: roundNumber(todaysTotals.twoTSold),
      revenue: roundNumber(todaysTotals.revenue),
      paymentTotal: roundNumber(todaysTotals.paymentTotal + standaloneCollectionTotal),
      profit: roundNumber(todaysTotals.profit),
      entriesCompleted: todaysApprovedEntries.length,
      shiftsCompleted: todaysApprovedEntries.length,
    },
    todaysEntries: todaysEntries.map((entry) => entry.toSummaryJson()),
  };
}

async function getDailySummary(stationId, date = todayInStationTimeZone()) {
  const summary =
    await DailySalesSummary.findByDate(stationId, date) ||
    (await syncDailySalesSummaryForDate(stationId, date));
  if (!summary) {
    return createEmptyDailySummary(date);
  }
  return typeof summary.toApiJson === 'function' ? summary.toApiJson() : summary;
}

async function getMonthlyReport(
  stationId,
  {month = currentMonthInStationTimeZone(), fromDate, toDate} = {},
) {
  const fetchRange = resolveEntryFetchRange({month, fromDate, toDate});
  await ensureDailySalesSummariesBackfilled(stationId);
  const summaries = await DailySalesSummary.allForStationRange(stationId, fetchRange);
  const filteredSummaries = summaries.filter((summary) => {
    const date = String(summary.date || '');
    if (month && !date.startsWith(month)) {
      return false;
    }
    if (fromDate && date < fromDate) {
      return false;
    }
    if (toDate && date > toDate) {
      return false;
    }
    return true;
  });
  const totals = {
    revenue: 0,
    paymentTotal: 0,
    profit: 0,
    petrolSold: 0,
    dieselSold: 0,
    twoTSold: 0,
    creditTotal: 0,
    entriesCompleted: 0,
    shiftsCompleted: 0,
  };
  const paymentBreakdown = emptyPaymentBreakdown();
  const fuelBreakdown = {
    petrol: 0,
    diesel: 0,
    two_t_oil: 0,
  };
  const trend = [];

  for (const summary of filteredSummaries) {
    totals.revenue += Number(summary.totals?.revenue || 0);
    totals.paymentTotal += Number(summary.totals?.paymentTotal || 0);
    totals.profit += Number(summary.totals?.profit || 0);
    totals.petrolSold += Number(summary.totals?.petrolSold || 0);
    totals.dieselSold += Number(summary.totals?.dieselSold || 0);
    totals.twoTSold += Number(summary.totals?.twoTSold || 0);
    totals.creditTotal += Number(summary.totals?.creditTotal || 0);
    totals.entriesCompleted += Number(summary.totals?.entriesCompleted || 0);
    totals.shiftsCompleted += Number(summary.totals?.shiftsCompleted || 0);

    addPaymentAmount(paymentBreakdown, 'cash', summary.paymentBreakdown?.cash);
    addPaymentAmount(paymentBreakdown, 'check', summary.paymentBreakdown?.check);
    addPaymentAmount(paymentBreakdown, 'upi', summary.paymentBreakdown?.upi);
    addPaymentAmount(paymentBreakdown, 'credit', summary.paymentBreakdown?.credit);

    fuelBreakdown.petrol += Number(summary.fuelBreakdown?.petrol || 0);
    fuelBreakdown.diesel += Number(summary.fuelBreakdown?.diesel || 0);
    fuelBreakdown.two_t_oil += Number(summary.fuelBreakdown?.two_t_oil || 0);

    if (summary.trend?.date) {
      trend.push({
        date: summary.trend.date,
        revenue: roundNumber(summary.trend.revenue),
        paymentTotal: roundNumber(summary.trend.paymentTotal),
        profit: roundNumber(summary.trend.profit),
        petrolSold: roundNumber(summary.trend.petrolSold),
        dieselSold: roundNumber(summary.trend.dieselSold),
        twoTSold: roundNumber(summary.trend.twoTSold),
        entries: Math.max(0, Number(summary.trend.entries || 0)),
        shifts: Math.max(0, Number(summary.trend.shifts || 0)),
      });
    }
  }

  return {
    month,
    fromDate: fromDate || '',
    toDate: toDate || '',
    totals: {
      revenue: roundNumber(totals.revenue),
      paymentTotal: roundNumber(totals.paymentTotal),
      profit: roundNumber(totals.profit),
      petrolSold: roundNumber(totals.petrolSold),
      dieselSold: roundNumber(totals.dieselSold),
      twoTSold: roundNumber(totals.twoTSold),
      creditTotal: roundNumber(totals.creditTotal),
      entriesCompleted: Math.max(0, Number(totals.entriesCompleted || 0)),
      shiftsCompleted: Math.max(0, Number(totals.shiftsCompleted || 0)),
    },
    paymentBreakdown: roundPaymentBreakdown(paymentBreakdown),
    fuelBreakdown: {
      petrol: roundNumber(fuelBreakdown.petrol),
      diesel: roundNumber(fuelBreakdown.diesel),
      two_t_oil: roundNumber(fuelBreakdown.two_t_oil),
    },
    trend: trend.sort((a, b) => a.date.localeCompare(b.date)),
  };
}

module.exports = {
  getDailySummary,
  getManagementDashboard,
  getMonthlyReport,
  getSalesDashboard,
  syncDailySalesSummaryForDate,
};
