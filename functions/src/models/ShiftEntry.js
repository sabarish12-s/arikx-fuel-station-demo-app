const {
  claimsFor,
  deleteDataRecord,
  getDataRecord,
  listDataRecords,
  upsertDataRecord,
} = require('../utils/authStore');
const {admin, getFirestore} = require('../config/firebase');
const {nowIso, todayInStationTimeZone} = require('../utils/time');
const CreditCustomer = require('./CreditCustomer');
const CreditTransaction = require('./CreditTransaction');
const FuelPrice = require('./FuelPrice');
const Station = require('./Station');
const StationDaySetup = require('./StationDaySetup');
const User = require('./User');

const ENTITY_TYPE = 'shiftEntry';
const COLLECTION_NAME = 'shiftEntries';
const DAILY_SHIFT = 'daily';
const DEFAULT_TESTING_QUANTITY = 5;
const READING_COMPARISON_TOLERANCE = 0.005;
const STATION_CACHE_TTL_MS = 60000;
const stationEntriesCache = new Map();
const stationRawEntriesCache = new Map();
const stationRangeEntriesCache = new Map();

function entryId(stationId, date) {
  return `${stationId}:${date}`;
}

function parseEntryId(id = '') {
  const [stationId = '', date = ''] = String(id).split(':');
  return {stationId, date};
}

function cloneJson(value) {
  return JSON.parse(JSON.stringify(value));
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

function cloneShiftEntry(entry) {
  return new ShiftEntry(entry.toJson());
}

function cloneShiftEntries(entries = []) {
  return entries.map((entry) => cloneShiftEntry(entry));
}

function stationRangeCacheKey(
  stationId,
  {fromDate = '', toDate = '', includePrevious = true} = {},
) {
  return `${stationId}:${fromDate || ''}:${toDate || ''}:${includePrevious ? '1' : '0'}`;
}

function matchesFilters(entry, filters = {}) {
  return Object.entries(filters).every(([field, expected]) => entry[field] === expected);
}

function roundNumber(value) {
  return Math.round((Number(value || 0) + Number.EPSILON) * 100) / 100;
}

function sumFuelTotals(pumpValues, fuelKey) {
  return Object.values(pumpValues || {}).reduce(
    (sum, pump) => sum + Number(pump?.[fuelKey] || 0),
    0,
  );
}

function normalizePumpReadings(readings = {}, station) {
  const result = {};
  for (const pump of station?.pumps || []) {
    const source = readings?.[pump.id] || {};
    result[pump.id] = {
      petrol: roundNumber(source.petrol),
      diesel: roundNumber(source.diesel),
      twoT: roundNumber(source.twoT),
    };
  }
  return result;
}

function normalizePartialPumpReadings(readings = {}, station) {
  const result = {};
  for (const pump of station?.pumps || []) {
    if (!Object.prototype.hasOwnProperty.call(readings || {}, pump.id)) {
      continue;
    }
    const source = readings?.[pump.id] || {};
    result[pump.id] = {
      petrol: roundNumber(source.petrol),
      diesel: roundNumber(source.diesel),
      twoT: roundNumber(source.twoT),
    };
  }
  return result;
}

function normalizePumpAttendants(pumpAttendants = {}, station) {
  const result = {};
  for (const pump of station?.pumps || []) {
    result[pump.id] = String(pumpAttendants?.[pump.id] || '').trim();
  }
  return result;
}

function normalizePartialPumpAttendants(pumpAttendants = {}, station) {
  const result = {};
  for (const pump of station?.pumps || []) {
    if (!Object.prototype.hasOwnProperty.call(pumpAttendants || {}, pump.id)) {
      continue;
    }
    result[pump.id] = String(pumpAttendants?.[pump.id] || '').trim();
  }
  return result;
}

function normalizeSalesmanSelection(value = {}) {
  return {
    salesmanId: String(value?.salesmanId || value?.id || '').trim(),
    salesmanName: String(value?.salesmanName || value?.name || '').trim(),
    salesmanCode: String(value?.salesmanCode || value?.code || '').trim().toUpperCase(),
  };
}

function hasSalesmanSelection(value = {}) {
  return Boolean(
    String(value?.salesmanId || '').trim() ||
      String(value?.salesmanName || '').trim() ||
      String(value?.salesmanCode || '').trim(),
  );
}

function salesmanDisplayLabel(value = {}) {
  const normalized = normalizeSalesmanSelection(value);
  if (normalized.salesmanName && normalized.salesmanCode) {
    return `${normalized.salesmanName} (${normalized.salesmanCode})`;
  }
  if (normalized.salesmanName) {
    return normalized.salesmanName;
  }
  if (normalized.salesmanCode) {
    return normalized.salesmanCode;
  }
  return '';
}

function normalizePumpSalesmen(pumpSalesmen = {}, station) {
  const result = {};
  for (const pump of station?.pumps || []) {
    result[pump.id] = normalizeSalesmanSelection(pumpSalesmen?.[pump.id] || {});
  }
  return result;
}

function normalizePartialPumpSalesmen(pumpSalesmen = {}, station) {
  const result = {};
  for (const pump of station?.pumps || []) {
    if (!Object.prototype.hasOwnProperty.call(pumpSalesmen || {}, pump.id)) {
      continue;
    }
    result[pump.id] = normalizeSalesmanSelection(pumpSalesmen?.[pump.id] || {});
  }
  return result;
}

function normalizeLoosePumpSalesmen(pumpSalesmen = {}) {
  return Object.entries(pumpSalesmen || {}).reduce((result, [pumpId, value]) => {
    result[pumpId] = normalizeSalesmanSelection(value);
    return result;
  }, {});
}

function buildPumpAttendantsFromSalesmen({
  pumpSalesmen = {},
  pumpAttendants = {},
  station,
  partial = false,
} = {}) {
  const result = {};
  for (const pump of station?.pumps || []) {
    if (partial) {
      const hasSalesman = Object.prototype.hasOwnProperty.call(pumpSalesmen || {}, pump.id);
      const hasAttendant = Object.prototype.hasOwnProperty.call(pumpAttendants || {}, pump.id);
      if (!hasSalesman && !hasAttendant) {
        continue;
      }
    }

    const normalizedSalesman = normalizeSalesmanSelection(pumpSalesmen?.[pump.id] || {});
    const label = salesmanDisplayLabel(normalizedSalesman);
    result[pump.id] = label || String(pumpAttendants?.[pump.id] || '').trim();
  }
  return result;
}

function normalizeTestingQuantity(value) {
  if (value === true) {
    return DEFAULT_TESTING_QUANTITY;
  }
  if (value === false || value === null || value === undefined) {
    return 0;
  }
  const numeric = Number(value);
  if (!Number.isFinite(numeric) || numeric <= 0) {
    return 0;
  }
  return roundNumber(numeric);
}

function normalizePumpTestingValue(value) {
  if (value && typeof value === 'object' && !Array.isArray(value)) {
    return {
      petrol: normalizeTestingQuantity(value.petrol),
      diesel: normalizeTestingQuantity(value.diesel),
      addToInventory: value.addToInventory === true,
    };
  }
  const quantity = normalizeTestingQuantity(value);
  return {petrol: quantity, diesel: quantity, addToInventory: false};
}

function normalizeLoosePumpTesting(pumpTesting = {}) {
  return Object.entries(pumpTesting || {}).reduce((result, [pumpId, value]) => {
    result[pumpId] = normalizePumpTestingValue(value);
    return result;
  }, {});
}

function normalizePumpTesting(pumpTesting = {}, station) {
  const result = {};
  for (const pump of station?.pumps || []) {
    result[pump.id] = normalizePumpTestingValue(pumpTesting?.[pump.id]);
  }
  return result;
}

function normalizePartialPumpTesting(pumpTesting = {}, station) {
  const result = {};
  for (const pump of station?.pumps || []) {
    if (!Object.prototype.hasOwnProperty.call(pumpTesting || {}, pump.id)) {
      continue;
    }
    result[pump.id] = normalizePumpTestingValue(pumpTesting?.[pump.id]);
  }
  return result;
}

function normalizePumpCollections(pumpCollections = {}, station) {
  const result = {};
  for (const pump of station?.pumps || []) {
    result[pump.id] = roundNumber(pumpCollections?.[pump.id]);
  }
  return result;
}

function normalizePartialPumpCollections(pumpCollections = {}, station) {
  const result = {};
  for (const pump of station?.pumps || []) {
    if (!Object.prototype.hasOwnProperty.call(pumpCollections || {}, pump.id)) {
      continue;
    }
    result[pump.id] = roundNumber(pumpCollections?.[pump.id]);
  }
  return result;
}

function normalizePumpPayments(pumpPayments = {}, station) {
  const result = {};
  for (const pump of station?.pumps || []) {
    const source = pumpPayments?.[pump.id] || {};
    result[pump.id] = {
      cash: roundNumber(source.cash),
      check: roundNumber(source.check),
      upi: roundNumber(source.upi),
      credit: roundNumber(source.credit),
    };
  }
  return result;
}

function normalizePartialPumpPayments(pumpPayments = {}, station) {
  const result = {};
  for (const pump of station?.pumps || []) {
    if (!Object.prototype.hasOwnProperty.call(pumpPayments || {}, pump.id)) {
      continue;
    }
    const source = pumpPayments?.[pump.id] || {};
    result[pump.id] = {
      cash: roundNumber(source.cash),
      check: roundNumber(source.check),
      upi: roundNumber(source.upi),
      credit: roundNumber(source.credit),
    };
  }
  return result;
}

function normalizePaymentBreakdown(paymentBreakdown = {}) {
  return {
    cash: roundNumber(paymentBreakdown.cash),
    check: roundNumber(paymentBreakdown.check),
    upi: roundNumber(paymentBreakdown.upi),
  };
}

function normalizeCreditEntries(creditEntries = []) {
  return (Array.isArray(creditEntries) ? creditEntries : [])
    .map((item) => ({
      pumpId: String(item?.pumpId || '').trim(),
      customerId: String(item?.customerId || '').trim(),
      name: String(item?.name || '').trim(),
      amount: roundNumber(item?.amount),
    }));
}

function validateCreditEntries({
  creditEntries = [],
  pumpPayments = {},
  station,
  pumpLabels = {},
}) {
  const totalsByPump = {};
  const pumpIds = new Set((station?.pumps || []).map((pump) => pump.id));

  for (const pump of station?.pumps || []) {
    totalsByPump[pump.id] = 0;
  }

  for (let index = 0; index < creditEntries.length; index += 1) {
    const item = creditEntries[index];
    const label = `Credit entry ${index + 1}`;
    if (!item.pumpId || !pumpIds.has(item.pumpId)) {
      throw new Error(`${label} must be linked to a valid pump.`);
    }
    if (!item.customerId && !item.name) {
      throw new Error(`${label} must have an existing customer or a new customer name.`);
    }
    if (Number(item.amount || 0) <= 0) {
      throw new Error(`${label} must have an amount greater than zero.`);
    }
    totalsByPump[item.pumpId] = roundNumber(
      Number(totalsByPump[item.pumpId] || 0) + Number(item.amount || 0),
    );
  }

  for (const pump of station?.pumps || []) {
    const paymentCredit = roundNumber(pumpPayments?.[pump.id]?.credit);
    const rowCredit = roundNumber(totalsByPump[pump.id] || 0);
    if (Math.abs(paymentCredit - rowCredit) > 0.01) {
      throw new Error(
        `Pump credit total for ${formattedPumpLabel(pump.id, pumpLabels)} must match added credit rows.`,
      );
    }
  }
}

function normalizeCreditCollections(creditCollections = []) {
  return (Array.isArray(creditCollections) ? creditCollections : [])
    .map((item) => ({
      customerId: String(item?.customerId || '').trim(),
      name: String(item?.name || '').trim(),
      amount: roundNumber(item?.amount),
      date: String(item?.date || '').trim(),
      paymentMode: ['cash', 'check', 'upi'].includes(
        String(item?.paymentMode || '').trim().toLowerCase(),
      )
        ? String(item?.paymentMode || '').trim().toLowerCase()
        : null,
      note: String(item?.note || '').trim(),
    }))
    .filter(
      (item) =>
        (item.customerId || item.name) &&
        item.amount > 0 &&
        item.date &&
        item.paymentMode,
    );
}

function buildVarianceNote({
  invalidPumpIds,
  mismatchAmount,
  mismatchReason,
  limitBreaches = [],
  flagThreshold = 0.01,
}) {
  const notes = [];
  if (invalidPumpIds.length > 0) {
    notes.push(`Closing meter readings are below opening readings for ${invalidPumpIds.join(', ')}.`);
  }
  if (limitBreaches.length > 0) {
    notes.push(`Meter sales exceed configured limit for ${limitBreaches.join(', ')}.`);
  }
  if (Math.abs(mismatchAmount) >= (flagThreshold ?? 0.01)) {
    const prefix = mismatchAmount > 0 ? 'Payment exceeds computed revenue' : 'Payment is short against computed revenue';
    const reason = String(mismatchReason || '').trim();
    notes.push(
      `${prefix} by ${Math.abs(mismatchAmount).toFixed(2)}.${reason ? ` Reason: ${reason}` : ''}`,
    );
  }
  return notes.join(' ');
}

function totalFuelCost(totals, priceSnapshot) {
  const petrolPrice = priceSnapshot.petrol || {costPrice: 0};
  const dieselPrice = priceSnapshot.diesel || {costPrice: 0};
  const twoTPrice = priceSnapshot.two_t_oil || {costPrice: 0};
  return roundNumber(
    Number(totals?.sold?.petrol || 0) * Number(petrolPrice.costPrice || 0) +
      Number(totals?.sold?.diesel || 0) * Number(dieselPrice.costPrice || 0) +
      Number(totals?.sold?.twoT || 0) * Number(twoTPrice.costPrice || 0),
  );
}

function formattedPumpLabel(pumpId, pumpLabels = {}) {
  if (pumpLabels[pumpId]) {
    return pumpLabels[pumpId];
  }
  switch (String(pumpId || '').toLowerCase()) {
    case 'pump1':
      return 'Pump 1';
    case 'pump2':
      return 'Pump 2';
    case 'pump3':
      return 'Pump 3';
    default:
      return String(pumpId || '');
  }
}

function soldFromReading({openingValue, closingValue, readingMode}) {
  const opening = Number(openingValue || 0);
  const closing = Number(closingValue || 0);
  const difference = readingMode === 'meter' ? closing - opening : opening - closing;
  const normalizedDifference =
    Math.abs(difference) <= READING_COMPARISON_TOLERANCE ? 0 : difference;
  return roundNumber(
    normalizedDifference,
  );
}

function calculateMetrics({
  openingReadings,
  closingReadings,
  priceSnapshot,
  pumpTesting,
  pumpPayments,
  pumpCollections,
  paymentBreakdown,
  creditEntries,
  creditCollections,
  mismatchReason,
  meterLimits = {},
  readingMode = 'meter',
  pumpLabels = {},
  flagThreshold = 0.01,
}) {
  const soldByPump = {};
  const testingDeductionsByPump = {};

  for (const [pumpId, values] of Object.entries(closingReadings || {})) {
    const openingPump = openingReadings?.[pumpId] || {};
    soldByPump[pumpId] = {
      petrol: soldFromReading({
        openingValue: openingPump.petrol,
        closingValue: values.petrol,
        readingMode,
      }),
      diesel: soldFromReading({
        openingValue: openingPump.diesel,
        closingValue: values.diesel,
        readingMode,
      }),
      twoT: soldFromReading({
        openingValue: openingPump.twoT,
        closingValue: values.twoT,
        readingMode,
      }),
    };
  }

  for (const [pumpId, value] of Object.entries(pumpTesting || {})) {
    const testing = normalizePumpTestingValue(value);
    if ((testing.petrol <= 0 && testing.diesel <= 0) || !soldByPump[pumpId]) {
      continue;
    }
    const adjusted = {...soldByPump[pumpId]};
    const deductions = {petrol: 0, diesel: 0};
    for (const fuelKey of ['petrol', 'diesel']) {
      const currentValue = Number(adjusted[fuelKey] || 0);
      if (currentValue <= 0) {
        continue;
      }
      const deduction = Math.min(currentValue, Number(testing[fuelKey] || 0));
      adjusted[fuelKey] = roundNumber(currentValue - deduction);
      deductions[fuelKey] = roundNumber(deduction);
    }
    soldByPump[pumpId] = adjusted;
    testingDeductionsByPump[pumpId] = deductions;
  }

  const inventoryByPump = Object.entries(soldByPump).reduce(
    (result, [pumpId, values]) => {
      result[pumpId] = {...values};
      return result;
    },
    {},
  );

  for (const [pumpId, deductions] of Object.entries(testingDeductionsByPump)) {
    const testing = normalizePumpTestingValue(pumpTesting?.[pumpId]);
    if (!testing.addToInventory || !inventoryByPump[pumpId]) {
      continue;
    }
    inventoryByPump[pumpId] = {
      ...inventoryByPump[pumpId],
      petrol: roundNumber(
        Number(inventoryByPump[pumpId].petrol || 0) + Number(deductions.petrol || 0),
      ),
      diesel: roundNumber(
        Number(inventoryByPump[pumpId].diesel || 0) + Number(deductions.diesel || 0),
      ),
    };
  }

  const totals = {
    opening: {
      petrol: roundNumber(sumFuelTotals(openingReadings, 'petrol')),
      diesel: roundNumber(sumFuelTotals(openingReadings, 'diesel')),
      twoT: roundNumber(sumFuelTotals(openingReadings, 'twoT')),
    },
    closing: {
      petrol: roundNumber(sumFuelTotals(closingReadings, 'petrol')),
      diesel: roundNumber(sumFuelTotals(closingReadings, 'diesel')),
      twoT: roundNumber(sumFuelTotals(closingReadings, 'twoT')),
    },
    sold: {
      petrol: roundNumber(sumFuelTotals(soldByPump, 'petrol')),
      diesel: roundNumber(sumFuelTotals(soldByPump, 'diesel')),
      twoT: roundNumber(sumFuelTotals(soldByPump, 'twoT')),
    },
  };

  const inventoryTotals = {
    petrol: roundNumber(sumFuelTotals(inventoryByPump, 'petrol')),
    diesel: roundNumber(sumFuelTotals(inventoryByPump, 'diesel')),
    twoT: roundNumber(sumFuelTotals(inventoryByPump, 'twoT')),
  };

  const petrolPrice = priceSnapshot.petrol || {costPrice: 0, sellingPrice: 0};
  const dieselPrice = priceSnapshot.diesel || {costPrice: 0, sellingPrice: 0};
  const twoTPrice = priceSnapshot.two_t_oil || {costPrice: 0, sellingPrice: 0};

  const computedRevenue = roundNumber(
    totals.sold.petrol * Number(petrolPrice.sellingPrice || 0) +
      totals.sold.diesel * Number(dieselPrice.sellingPrice || 0) +
      totals.sold.twoT * Number(twoTPrice.sellingPrice || 0),
  );

  const pumpPaymentTotals = Object.values(pumpPayments || {}).reduce(
    (sum, item) => ({
      cash: sum.cash + Number(item.cash || 0),
      check: sum.check + Number(item.check || 0),
      upi: sum.upi + Number(item.upi || 0),
      credit: sum.credit + Number(item.credit || 0),
    }),
    {cash: 0, check: 0, upi: 0, credit: 0},
  );
  const hasStructuredPumpPayments = Object.values(pumpPayments || {}).some(
    (item) =>
      Number(item.cash || 0) > 0 ||
      Number(item.check || 0) > 0 ||
      Number(item.upi || 0) > 0 ||
      Number(item.credit || 0) > 0,
  );
  const legacyPumpCollectionTotal = Object.values(pumpCollections || {}).reduce(
    (sum, value) => sum + Number(value || 0),
    0,
  );
  const creditTotal = roundNumber(
    hasStructuredPumpPayments
      ? pumpPaymentTotals.credit
      : creditEntries.reduce((sum, item) => sum + Number(item.amount || 0), 0),
  );
  const creditCollectionTotal = roundNumber(
    creditCollections.reduce((sum, item) => sum + Number(item.amount || 0), 0),
  );
  const pumpCollectionTotal = roundNumber(
    hasStructuredPumpPayments
      ? Object.values(pumpPayments || {}).reduce(
          (sum, value) =>
            sum +
            Number(value.cash || 0) +
            Number(value.check || 0) +
            Number(value.upi || 0) +
            Number(value.credit || 0),
          0,
        )
      : legacyPumpCollectionTotal,
  );
  const salesSettlementTotal = roundNumber(
    (hasStructuredPumpPayments
      ? pumpPaymentTotals.cash +
        pumpPaymentTotals.check +
        pumpPaymentTotals.upi +
        pumpPaymentTotals.credit
      : legacyPumpCollectionTotal) +
      Number(paymentBreakdown.cash || 0) +
      Number(paymentBreakdown.check || 0) +
      Number(paymentBreakdown.upi || 0),
  );
  const paymentTotal = roundNumber(salesSettlementTotal + creditCollectionTotal);
  const mismatchAmount = roundNumber(salesSettlementTotal - computedRevenue);
  const profit = roundNumber(
    salesSettlementTotal - totalFuelCost(totals, priceSnapshot),
  );

  const invalidPumpIds = Object.entries(soldByPump)
    .filter(([, values]) => values.petrol < 0 || values.diesel < 0 || values.twoT < 0)
    .map(([pumpId]) => formattedPumpLabel(pumpId, pumpLabels));
  const limitBreaches = [];
  if (readingMode === 'meter') {
    for (const [pumpId, values] of Object.entries(soldByPump)) {
      const limits = meterLimits?.[pumpId] || {};
      for (const fuelKey of ['petrol', 'diesel', 'twoT']) {
        const limit = Number(limits?.[fuelKey] || 0);
        if (limit > 0 && Number(values?.[fuelKey] || 0) > limit) {
          const fuelLabel = fuelKey === 'twoT' ? '2T oil' : fuelKey;
          limitBreaches.push(
            `${formattedPumpLabel(pumpId, pumpLabels)} ${fuelLabel}`,
          );
        }
      }
    }
  }

  const threshold = typeof flagThreshold === 'number' && flagThreshold >= 0 ? flagThreshold : 0.01;
  const flagged =
    invalidPumpIds.length > 0 ||
    limitBreaches.length > 0 ||
    Math.abs(mismatchAmount) >= threshold;

  return {
    soldByPump,
    totals,
    inventoryTotals,
    computedRevenue,
    paymentTotal,
    salesSettlementTotal,
    pumpCollectionTotal,
    mismatchAmount,
    creditTotal,
    creditCollectionTotal,
    profit,
    flagged,
    varianceNote: buildVarianceNote({
      invalidPumpIds,
      mismatchAmount,
      mismatchReason,
      limitBreaches,
      flagThreshold,
    }),
  };
}

function validateDate(date) {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(String(date || ''))) {
    throw new Error('Valid date is required.');
  }
  if (String(date) > todayInStationTimeZone()) {
    throw new Error('Future dates are not allowed.');
  }
}

class ShiftEntry {
  constructor({
    id,
    stationId,
    date,
    shift = DAILY_SHIFT,
    status = 'submitted',
    submittedBy,
    submittedByName = '',
    reviewedBy = null,
    approvedAt = null,
    submittedAt = null,
    updatedAt = null,
    flagged = false,
    varianceNote = '',
    mismatchReason = '',
    readingMode = 'meter',
    openingReadings = {},
    closingReadings = {},
    soldByPump = {},
    pumpSalesmen = {},
    pumpAttendants = {},
    pumpTesting = {},
    pumpPayments = {},
    pumpCollections = {},
    paymentBreakdown = {cash: 0, check: 0, upi: 0},
    creditEntries = [],
    creditCollections = [],
    totals = {
      opening: {petrol: 0, diesel: 0, twoT: 0},
      closing: {petrol: 0, diesel: 0, twoT: 0},
      sold: {petrol: 0, diesel: 0, twoT: 0},
    },
    inventoryTotals = {petrol: 0, diesel: 0, twoT: 0},
    revenue = 0,
    computedRevenue = 0,
    paymentTotal = 0,
    salesSettlementTotal = 0,
    creditCollectionTotal = 0,
    creditTotal = 0,
    mismatchAmount = 0,
    profit = 0,
    priceSnapshot = {},
  }) {
    this.id = id || entryId(stationId, date);
    this.stationId = stationId;
    this.date = date;
    this.shift = shift || DAILY_SHIFT;
    this.status = status;
    this.submittedBy = submittedBy;
    this.submittedByName = submittedByName || '';
    this.reviewedBy = reviewedBy;
    this.approvedAt = approvedAt;
    this.submittedAt = submittedAt;
    this.updatedAt = updatedAt;
    this.flagged = flagged;
    this.varianceNote = varianceNote || '';
    this.mismatchReason = mismatchReason || '';
    this.readingMode = readingMode || 'meter';
    this.openingReadings = openingReadings;
    this.closingReadings = closingReadings;
    this.soldByPump = soldByPump;
    this.pumpSalesmen = pumpSalesmen;
    this.pumpAttendants = pumpAttendants;
    this.pumpTesting = pumpTesting;
    this.pumpPayments = pumpPayments;
    this.pumpCollections = pumpCollections;
    this.paymentBreakdown = paymentBreakdown;
    this.creditEntries = creditEntries;
    this.creditCollections = creditCollections;
    this.totals = totals;
    this.inventoryTotals = {
      petrol: roundNumber(inventoryTotals?.petrol),
      diesel: roundNumber(inventoryTotals?.diesel),
      twoT: roundNumber(inventoryTotals?.twoT),
    };
    this.revenue = roundNumber(revenue || computedRevenue);
    this.computedRevenue = roundNumber(computedRevenue || revenue);
    this.paymentTotal = roundNumber(paymentTotal);
    this.salesSettlementTotal = roundNumber(salesSettlementTotal);
    this.creditCollectionTotal = roundNumber(creditCollectionTotal);
    this.creditTotal = roundNumber(creditTotal);
    this.mismatchAmount = roundNumber(mismatchAmount);
    this.profit = roundNumber(profit);
    this.priceSnapshot = priceSnapshot;
  }

  static fromRecord(record) {
    if (!record) {
      return null;
    }
    const claims = claimsFor(record);
    const id = claims.id || claims.ek || '';
    const parsed = parseEntryId(id);
    return new ShiftEntry({
      id,
      stationId: claims.sid || parsed.stationId,
      date: claims.dt || parsed.date,
      shift: DAILY_SHIFT,
      status: claims.st,
      submittedBy: claims.sb,
      submittedByName: '',
      reviewedBy: claims.rb || null,
      approvedAt: claims.ap || null,
      submittedAt: claims.ca || null,
      updatedAt: claims.ua || null,
      flagged: false,
      varianceNote: '',
      mismatchReason: claims.mr || '',
      readingMode: claims.rm || 'stock',
      openingReadings: {},
      closingReadings: claims.cr || {},
      soldByPump: {},
      pumpSalesmen: normalizeLoosePumpSalesmen(claims.ps || {}),
      pumpAttendants: claims.pa || {},
      pumpTesting: normalizeLoosePumpTesting(claims.pt || {}),
      pumpPayments: claims.pp || {},
      pumpCollections: claims.pc || {},
      paymentBreakdown: claims.pb || {cash: 0, check: 0, upi: 0},
      creditEntries: normalizeCreditEntries(claims.ce || []),
      creditCollections: normalizeCreditCollections(claims.cc || []),
      totals: {
        opening: {petrol: 0, diesel: 0, twoT: 0},
        closing: {petrol: 0, diesel: 0, twoT: 0},
        sold: {petrol: 0, diesel: 0, twoT: 0},
      },
      inventoryTotals: {petrol: 0, diesel: 0, twoT: 0},
      revenue: 0,
      computedRevenue: 0,
      paymentTotal: 0,
      salesSettlementTotal: 0,
      creditCollectionTotal: 0,
      mismatchAmount: 0,
      profit: 0,
      priceSnapshot: {},
    });
  }

  static fromStoredDocument(snapshot) {
    if (!snapshot?.exists) {
      return null;
    }
    const data = snapshot.data() || {};
    const id = data.id || data.ek || snapshot.id || '';
    const parsed = parseEntryId(id);
    return new ShiftEntry({
      id,
      stationId: data.sid || parsed.stationId,
      date: data.dt || parsed.date,
      shift: DAILY_SHIFT,
      status: data.st,
      submittedBy: data.sb,
      submittedByName: '',
      reviewedBy: data.rb || null,
      approvedAt: data.ap || null,
      submittedAt: data.ca || null,
      updatedAt: data.ua || null,
      flagged: false,
      varianceNote: '',
      mismatchReason: data.mr || '',
      readingMode: data.rm || 'stock',
      openingReadings: {},
      closingReadings: data.cr || {},
      soldByPump: {},
      pumpSalesmen: normalizeLoosePumpSalesmen(data.ps || {}),
      pumpAttendants: data.pa || {},
      pumpTesting: normalizeLoosePumpTesting(data.pt || {}),
      pumpPayments: data.pp || {},
      pumpCollections: data.pc || {},
      paymentBreakdown: data.pb || {cash: 0, check: 0, upi: 0},
      creditEntries: normalizeCreditEntries(data.ce || []),
      creditCollections: normalizeCreditCollections(data.cc || []),
      totals: {
        opening: {petrol: 0, diesel: 0, twoT: 0},
        closing: {petrol: 0, diesel: 0, twoT: 0},
        sold: {petrol: 0, diesel: 0, twoT: 0},
      },
      inventoryTotals: {petrol: 0, diesel: 0, twoT: 0},
      revenue: 0,
      computedRevenue: 0,
      paymentTotal: 0,
      salesSettlementTotal: 0,
      creditCollectionTotal: 0,
      mismatchAmount: 0,
      profit: 0,
      priceSnapshot: {},
    });
  }

  toRecordPayload() {
    return {
      st: this.status,
      sb: this.submittedBy,
      rb: this.reviewedBy || null,
      ap: this.approvedAt || null,
      ca: this.submittedAt || null,
      ua: this.updatedAt || null,
      mr: this.mismatchReason || '',
      rm: this.readingMode || 'meter',
      cr: this.closingReadings,
      ps: this.pumpSalesmen,
      pa: this.pumpAttendants,
      pt: this.pumpTesting,
      pp: this.pumpPayments,
      pc: this.pumpCollections,
      pb: this.paymentBreakdown,
      ce: this.creditEntries,
      cc: this.creditCollections,
    };
  }

  async save() {
    await upsertDataRecord({
      entityType: ENTITY_TYPE,
      entityKey: this.id,
      displayName: `${this.date} Daily Entry`,
      payload: this.toRecordPayload(),
    });
    ShiftEntry.invalidateStationCache(this.stationId);
    return this;
  }

  static async findRaw(filters = {}) {
    const stationId = String(filters.stationId || '').trim();
    const date = String(filters.date || '').trim();
    if (stationId && date) {
      const directEntry = ShiftEntry.fromStoredDocument(
        await getFirestore().collection(COLLECTION_NAME).doc(entryId(stationId, date)).get(),
      );
      if (directEntry && matchesFilters(directEntry, filters)) {
        return [directEntry];
      }
    } else if (stationId) {
      const cached = stationRawEntriesCache.get(stationId);
      if (cached && cached.expiresAt > Date.now()) {
        return cloneShiftEntries(cached.entries).filter((entry) => matchesFilters(entry, filters));
      }
      try {
        const snapshot = await getFirestore()
          .collection(COLLECTION_NAME)
          .where(admin.firestore.FieldPath.documentId(), '>=', `${stationId}:`)
          .where(admin.firestore.FieldPath.documentId(), '<=', `${stationId}:\uf8ff`)
          .get();
        const directEntries = snapshot.docs
          .map((doc) => ShiftEntry.fromStoredDocument(doc))
          .filter(Boolean);
        stationRawEntriesCache.set(stationId, {
          expiresAt: Date.now() + STATION_CACHE_TTL_MS,
          entries: cloneShiftEntries(directEntries),
        });
        return directEntries.filter((entry) => matchesFilters(entry, filters));
      } catch (error) {
        console.warn('ShiftEntry station query fallback:', error.message);
      }
    }

    return (await listDataRecords(ENTITY_TYPE))
      .map((record) => ShiftEntry.fromRecord(record))
      .filter(Boolean)
      .filter((entry) => matchesFilters(entry, filters));
  }

  static async findRawForStationRange(stationId, {fromDate = '', toDate = ''} = {}) {
    if (!stationId) {
      return [];
    }

    try {
      const documentId = admin.firestore.FieldPath.documentId();
      const startId = `${stationId}:${fromDate || ''}`;
      const endId = `${stationId}:${toDate || '\uf8ff'}`;
      const snapshot = await getFirestore()
        .collection(COLLECTION_NAME)
        .where(documentId, '>=', startId)
        .where(documentId, '<=', endId)
        .get();
      const directEntries = snapshot.docs
        .map((doc) => ShiftEntry.fromStoredDocument(doc))
        .filter(Boolean)
        .filter((entry) => {
          if (entry.stationId !== stationId) {
            return false;
          }
          if (fromDate && String(entry.date) < String(fromDate)) {
            return false;
          }
          if (toDate && String(entry.date) > String(toDate)) {
            return false;
          }
          return true;
        });
      return directEntries;
    } catch (error) {
      console.warn('ShiftEntry range query fallback:', error.message);
    }

    return (await listDataRecords(ENTITY_TYPE))
      .map((record) => ShiftEntry.fromRecord(record))
      .filter(Boolean)
      .filter((entry) => {
        if (entry.stationId !== stationId) {
          return false;
        }
        if (fromDate && String(entry.date) < String(fromDate)) {
          return false;
        }
        if (toDate && String(entry.date) > String(toDate)) {
          return false;
        }
        return true;
      });
  }

  static async latestRawBefore(stationId, date) {
    if (!stationId || !date) {
      return null;
    }

    try {
      const documentId = admin.firestore.FieldPath.documentId();
      const snapshot = await getFirestore()
        .collection(COLLECTION_NAME)
        .where(documentId, '>=', `${stationId}:`)
        .where(documentId, '<', `${stationId}:${date}`)
        .orderBy(documentId, 'desc')
        .limit(1)
        .get();
      const directEntry = ShiftEntry.fromStoredDocument(snapshot.docs[0]);
      return directEntry || null;
    } catch (error) {
      console.warn('ShiftEntry previous-entry query fallback:', error.message);
    }

    return (await listDataRecords(ENTITY_TYPE))
      .map((record) => ShiftEntry.fromRecord(record))
      .filter(Boolean)
      .filter((entry) => entry.stationId === stationId && String(entry.date) < String(date))
      .sort((a, b) => String(b.date).localeCompare(String(a.date)))[0] || null;
  }

  static async latestRawForStation(stationId) {
    if (!stationId) {
      return null;
    }

    try {
      const documentId = admin.firestore.FieldPath.documentId();
      const snapshot = await getFirestore()
        .collection(COLLECTION_NAME)
        .where(documentId, '>=', `${stationId}:`)
        .where(documentId, '<=', `${stationId}:\uf8ff`)
        .orderBy(documentId, 'desc')
        .limit(1)
        .get();
      const directEntry = ShiftEntry.fromStoredDocument(snapshot.docs[0]);
      return directEntry || null;
    } catch (error) {
      console.warn('ShiftEntry latest-entry query fallback:', error.message);
    }

    return (await listDataRecords(ENTITY_TYPE))
      .map((record) => ShiftEntry.fromRecord(record))
      .filter(Boolean)
      .filter((entry) => entry.stationId === stationId)
      .sort((a, b) => String(b.date).localeCompare(String(a.date)))[0] || null;
  }

  static async allForStationRange(
    stationId,
    {fromDate = '', toDate = '', includePrevious = true} = {},
  ) {
    if (!stationId) {
      return [];
    }

    const cacheKey = stationRangeCacheKey(stationId, {
      fromDate,
      toDate,
      includePrevious,
    });
    const cached = stationRangeEntriesCache.get(cacheKey);
    if (cached && cached.expiresAt > Date.now()) {
      return cloneShiftEntries(cached.entries);
    }

    const rawEntries = await ShiftEntry.findRawForStationRange(stationId, {
      fromDate,
      toDate,
    });
    if (includePrevious && fromDate) {
      const previousEntry = await ShiftEntry.latestRawBefore(stationId, fromDate);
      if (previousEntry && !rawEntries.some((entry) => entry.id === previousEntry.id)) {
        rawEntries.push(previousEntry);
      }
    }

    const hydratedEntries = await ShiftEntry.hydrateEntries(stationId, rawEntries);
    const filteredEntries = hydratedEntries.filter((entry) => {
      if (fromDate && String(entry.date) < String(fromDate)) {
        return false;
      }
      if (toDate && String(entry.date) > String(toDate)) {
        return false;
      }
      return true;
    });
    stationRangeEntriesCache.set(cacheKey, {
      expiresAt: Date.now() + STATION_CACHE_TTL_MS,
      entries: cloneShiftEntries(filteredEntries),
    });
    return cloneShiftEntries(filteredEntries);
  }

  static async hydrateEntries(
    stationId,
    rawEntries,
    {
      station: existingStation = null,
      setups: existingSetups = null,
      fallbackPriceSnapshot: existingFallbackPriceSnapshot = null,
    } = {},
  ) {
    const [station, setups, fallbackPriceSnapshot] = await Promise.all([
      existingStation || Station.findById(stationId),
      existingSetups || StationDaySetup.listForStation(stationId),
      existingFallbackPriceSnapshot || FuelPrice.getSnapshot(),
    ]);
    const pumpLabels = Object.fromEntries(
      (station?.pumps || []).map((pump) => [pump.id, pump.label]),
    );
    const sorted = [...rawEntries].sort((a, b) => String(a.date).localeCompare(String(b.date)));
    const activeSetups = setups.filter((setup) => !setup.isDeleted);
    let previousClosingReadings = null;
    let setupIndex = 0;
    let currentSetup = null;

    for (const entry of sorted) {
      while (
        setupIndex < activeSetups.length &&
        String(activeSetups[setupIndex].effectiveDate).localeCompare(String(entry.date)) <= 0
      ) {
        currentSetup = activeSetups[setupIndex];
        setupIndex += 1;
      }

      const exactSetup =
        currentSetup && String(currentSetup.effectiveDate) === String(entry.date)
          ? currentSetup
          : null;
      entry.openingReadings = cloneJson(
        exactSetup?.openingReadings ||
          previousClosingReadings ||
          currentSetup?.openingReadings ||
          station?.baseReadings ||
          {},
      );
      entry.priceSnapshot = cloneJson(
        currentSetup?.fuelPrices && Object.keys(currentSetup.fuelPrices).length > 0
          ? currentSetup.fuelPrices
          : fallbackPriceSnapshot,
      );
      const metrics = calculateMetrics({
        openingReadings: entry.openingReadings,
        closingReadings: entry.closingReadings,
        priceSnapshot: entry.priceSnapshot,
        pumpTesting: entry.pumpTesting,
        pumpPayments: entry.pumpPayments,
        pumpCollections: entry.pumpCollections,
        paymentBreakdown: entry.paymentBreakdown,
        creditEntries: entry.creditEntries,
        creditCollections: entry.creditCollections,
        mismatchReason: entry.mismatchReason,
        meterLimits: station?.meterLimits || {},
        readingMode: entry.readingMode || 'stock',
        pumpLabels,
        flagThreshold: station?.flagThreshold ?? 0.01,
      });
      entry.soldByPump = metrics.soldByPump;
      entry.totals = metrics.totals;
      entry.inventoryTotals = metrics.inventoryTotals;
      entry.revenue = metrics.computedRevenue;
      entry.computedRevenue = metrics.computedRevenue;
      entry.paymentTotal = metrics.paymentTotal;
      entry.salesSettlementTotal = metrics.salesSettlementTotal;
      entry.creditCollectionTotal = metrics.creditCollectionTotal;
      entry.creditTotal = metrics.creditTotal;
      entry.mismatchAmount = metrics.mismatchAmount;
      entry.profit = metrics.profit;
      if (String(entry.status || '').trim() === 'draft') {
        entry.flagged = false;
        entry.varianceNote = '';
      } else {
        entry.flagged = metrics.flagged;
        entry.varianceNote = metrics.varianceNote;
        previousClosingReadings = cloneJson(entry.closingReadings);
      }
    }

    return sorted;
  }

  static async hydrateEntry(
    rawEntry,
    {
      previousRawEntry,
      station: existingStation = null,
      setups: existingSetups = null,
      fallbackPriceSnapshot: existingFallbackPriceSnapshot = null,
    } = {},
  ) {
    if (!rawEntry?.stationId || !rawEntry?.date) {
      return null;
    }

    let resolvedPreviousRawEntry = previousRawEntry;
    if (resolvedPreviousRawEntry === undefined) {
      resolvedPreviousRawEntry = await ShiftEntry.latestRawBefore(
        rawEntry.stationId,
        rawEntry.date,
      );
    }

    const hydratedEntries = await ShiftEntry.hydrateEntries(
      rawEntry.stationId,
      resolvedPreviousRawEntry
        ? [resolvedPreviousRawEntry, rawEntry]
        : [rawEntry],
      {
        station: existingStation,
        setups: existingSetups,
        fallbackPriceSnapshot: existingFallbackPriceSnapshot,
      },
    );
    return hydratedEntries.find((entry) => entry.id === rawEntry.id) || null;
  }

  static invalidateStationCache(stationId) {
    if (!stationId) {
      return;
    }
    stationEntriesCache.delete(stationId);
    stationRawEntriesCache.delete(stationId);
    for (const key of stationRangeEntriesCache.keys()) {
      if (key.startsWith(`${stationId}:`)) {
        stationRangeEntriesCache.delete(key);
      }
    }
  }

  static latestActivityTimestamp(entry) {
    const timestamps = [
      String(entry?.approvedAt || '').trim(),
      String(entry?.updatedAt || '').trim(),
      String(entry?.submittedAt || '').trim(),
    ].filter(Boolean);
    return timestamps.sort((left, right) => left.localeCompare(right)).at(-1) || '';
  }

  static isFinalized(entry) {
    if (!entry) {
      return false;
    }
    if (['draft', 'preview'].includes(String(entry.status || '').trim())) {
      return false;
    }
    return (
      String(entry.approvedAt || '').trim().length > 0 ||
      String(entry.status || '').trim() === 'approved'
    );
  }

  static async allForStation(stationId, {forceRefresh = false} = {}) {
    if (!stationId) {
      return [];
    }

    const cached = stationEntriesCache.get(stationId);
    if (
      !forceRefresh &&
      cached &&
      cached.expiresAt > Date.now()
    ) {
      return cloneShiftEntries(cached.entries);
    }

    const hydratedEntries = await ShiftEntry.hydrateEntries(
      stationId,
      await ShiftEntry.findRaw({stationId}),
    );
    stationEntriesCache.set(stationId, {
      expiresAt: Date.now() + STATION_CACHE_TTL_MS,
      entries: cloneShiftEntries(hydratedEntries),
    });
    return cloneShiftEntries(hydratedEntries);
  }

  static async findById(id) {
    const {stationId, date} = parseEntryId(id);
    if (!stationId || !date) {
      return null;
    }
    const raw = (await ShiftEntry.findRaw({stationId, date}))[0] || null;
    if (!raw) {
      return null;
    }
    return ShiftEntry.hydrateEntry(raw);
  }

  static async findByDate(stationId, date) {
    return ShiftEntry.findById(entryId(stationId, date));
  }

  static async latestBefore(stationId, date) {
    const rawEntry = await ShiftEntry.latestRawBefore(stationId, date);
    if (!rawEntry) {
      return null;
    }
    return ShiftEntry.hydrateEntry(rawEntry);
  }

  static async getEntryAccessState(stationId) {
    const [firstSetup, rawEntries] = await Promise.all([
      StationDaySetup.earliestActiveForStation(stationId),
      ShiftEntry.findRaw({stationId}),
    ]);

    if (!firstSetup) {
      return {
        setupExists: false,
        allowedEntryDate: '',
        activeSetupDate: '',
        entryLockedReason: 'Create a day setup before sales entry can start.',
      };
    }

    const latestApprovedEntry = rawEntries
      .filter((entry) => ShiftEntry.isFinalized(entry))
      .sort((left, right) => String(left.date).localeCompare(String(right.date)))
      .at(-1) || null;
    const latestApprovedDate = latestApprovedEntry?.date || '';

    const allowedEntryDate = latestApprovedDate
      ? shiftIsoDate(latestApprovedEntry.date, 1)
      : firstSetup.effectiveDate;
    const activeSetup = await StationDaySetup.latestActiveOnOrBefore(
      stationId,
      allowedEntryDate,
    );

      return {
        setupExists: true,
        allowedEntryDate,
        latestApprovedDate,
        activeSetupDate: activeSetup?.effectiveDate || '',
        entryLockedReason: '',
      };
  }

  static async getMutationWindow(stationId) {
    const accessState = await ShiftEntry.getEntryAccessState(stationId);
    return {
      ...accessState,
      latestApprovedDate: String(accessState.latestApprovedDate || '').trim(),
      allowedEntryDate: String(accessState.allowedEntryDate || '').trim(),
    };
  }

  static async getMutationAccess(entry, {role = 'admin'} = {}) {
    const entryDate = String(entry?.date || '').trim();
    const normalizedRole = String(role || '').trim().toLowerCase();
    const window = await ShiftEntry.getMutationWindow(entry?.stationId);
    const latestApprovedDate = String(window.latestApprovedDate || '').trim();
    const allowedEntryDate = String(window.allowedEntryDate || '').trim();
    const isFinalized = ShiftEntry.isFinalized(entry);
    const isLatestApproved = Boolean(
      isFinalized && latestApprovedDate && entryDate === latestApprovedDate,
    );
    const isCurrentOpenDay = Boolean(
      !isFinalized && allowedEntryDate && entryDate === allowedEntryDate,
    );
    const isSuperAdmin = normalizedRole === 'superadmin';

    const updateReason = isSuperAdmin
      ? ''
      : 'Only superadmin can edit entries from the entries page.';
    const deleteReason = isSuperAdmin
      ? ''
      : 'Only superadmin can delete entries from the entries page.';
    const approveReason = allowedEntryDate
      ? `Only the current open day (${allowedEntryDate}) can be approved.`
      : 'There is no open day available for approval.';

    return {
      latestApprovedDate,
      allowedEntryDate,
      isLatestApproved,
      isCurrentOpenDay,
      canEdit: isSuperAdmin,
      canDelete: isSuperAdmin && !isFinalized,
      canOverrideDelete: isSuperAdmin && isFinalized,
      canApprove: isCurrentOpenDay,
      updateReason,
      deleteReason,
      approveReason,
    };
  }

  static async assertAllowedEntryDate(stationId, date) {
    const accessState = await ShiftEntry.getEntryAccessState(stationId);
    if (!accessState.setupExists || !accessState.allowedEntryDate) {
      throw new Error(
        accessState.entryLockedReason || 'Create a day setup before sales entry can start.',
      );
    }
    if (String(date || '').trim() !== accessState.allowedEntryDate) {
      throw new Error(`Sales entry is locked to ${accessState.allowedEntryDate}.`);
    }
    return accessState;
  }

  static async lockDaySetupsThroughDate(stationId, date, {lockedBy = '', lockedByName = ''} = {}) {
    const setups = await StationDaySetup.listForStation(stationId);
    const timestamp = nowIso();
    for (const setup of setups) {
      if (String(setup.effectiveDate).localeCompare(String(date)) > 0 || setup.isLocked) {
        continue;
      }
      setup.lockedAt = timestamp;
      setup.lockedBy = String(lockedBy || '').trim();
      setup.lockedByName = String(lockedByName || '').trim();
      await setup.save();
    }
  }

  static async openingReadingsFor(stationId, date) {
    validateDate(date);
    const [previousEntry, activeSetup, station] = await Promise.all([
      ShiftEntry.latestRawBefore(stationId, date),
      StationDaySetup.latestActiveOnOrBefore(stationId, date),
      Station.findById(stationId),
    ]);
    if (activeSetup?.effectiveDate === date) {
      return cloneJson(activeSetup.openingReadings || {});
    }
    if (previousEntry) {
      return cloneJson(previousEntry.closingReadings);
    }
    if (activeSetup) {
      return cloneJson(activeSetup.openingReadings || {});
    }
    return cloneJson(station?.baseReadings || {});
  }

  static async preview({
    stationId,
    date,
    closingReadings,
    pumpSalesmen,
    pumpAttendants,
    pumpTesting,
    pumpPayments,
    pumpCollections,
    paymentBreakdown,
    creditEntries,
    creditCollections,
    mismatchReason,
  }) {
    validateDate(date);
    const accessState = await ShiftEntry.assertAllowedEntryDate(stationId, date);
    const station = await Station.findById(stationId);
    const normalizedClosingReadings = normalizePumpReadings(closingReadings, station);
    const normalizedPumpSalesmen = normalizePumpSalesmen(pumpSalesmen, station);
    const normalizedPumpAttendants = buildPumpAttendantsFromSalesmen({
      pumpSalesmen: normalizedPumpSalesmen,
      pumpAttendants,
      station,
    });
    const normalizedPumpTesting = normalizePumpTesting(pumpTesting, station);
    const normalizedPumpPayments = normalizePumpPayments(pumpPayments, station);
    const normalizedPumpCollections = normalizePumpCollections(pumpCollections, station);
    const normalizedPaymentBreakdown = normalizePaymentBreakdown(paymentBreakdown);
    const normalizedCreditEntries = normalizeCreditEntries(creditEntries);
    const normalizedCreditCollections = normalizeCreditCollections(creditCollections);
    const openingReadings = await ShiftEntry.openingReadingsFor(stationId, date);
    const priceSnapshot = await FuelPrice.getSnapshot(
      accessState.allowedEntryDate || date,
      stationId,
    );
    const pumpLabels = Object.fromEntries(
      (station?.pumps || []).map((pump) => [pump.id, pump.label]),
    );
    validateCreditEntries({
      creditEntries: normalizedCreditEntries,
      pumpPayments: normalizedPumpPayments,
      station,
      pumpLabels,
    });
    const metrics = calculateMetrics({
      openingReadings,
      closingReadings: normalizedClosingReadings,
      priceSnapshot,
      pumpTesting: normalizedPumpTesting,
      pumpPayments: normalizedPumpPayments,
      pumpCollections: normalizedPumpCollections,
      paymentBreakdown: normalizedPaymentBreakdown,
      creditEntries: normalizedCreditEntries,
      creditCollections: normalizedCreditCollections,
      mismatchReason,
      meterLimits: station?.meterLimits || {},
      readingMode: 'meter',
      pumpLabels,
      flagThreshold: station?.flagThreshold ?? 0.01,
    });

    return new ShiftEntry({
      stationId,
      date,
      status: metrics.flagged ? 'flagged' : 'preview',
      submittedBy: 'preview',
      readingMode: 'meter',
      openingReadings,
      closingReadings: normalizedClosingReadings,
      soldByPump: metrics.soldByPump,
      pumpSalesmen: normalizedPumpSalesmen,
      pumpAttendants: normalizedPumpAttendants,
      pumpTesting: normalizedPumpTesting,
      pumpPayments: normalizedPumpPayments,
      pumpCollections: normalizedPumpCollections,
      paymentBreakdown: normalizedPaymentBreakdown,
      creditEntries: normalizedCreditEntries,
      creditCollections: normalizedCreditCollections,
      totals: metrics.totals,
      inventoryTotals: metrics.inventoryTotals,
      revenue: metrics.computedRevenue,
      computedRevenue: metrics.computedRevenue,
      paymentTotal: metrics.paymentTotal,
      salesSettlementTotal: metrics.salesSettlementTotal,
      creditCollectionTotal: metrics.creditCollectionTotal,
      mismatchAmount: metrics.mismatchAmount,
      mismatchReason: String(mismatchReason || '').trim(),
      profit: metrics.profit,
      flagged: metrics.flagged,
      varianceNote: metrics.varianceNote,
      priceSnapshot,
    });
  }

  static async saveDraft({
    stationId,
    date,
    submittedBy,
    closingReadings,
    pumpSalesmen,
    pumpAttendants,
    pumpTesting,
    pumpPayments,
    pumpCollections,
    paymentBreakdown,
    creditEntries,
    creditCollections,
    mismatchReason,
  }) {
    validateDate(date);
    await ShiftEntry.assertAllowedEntryDate(stationId, date);

    const existing = await ShiftEntry.findByDate(stationId, date);
    if (existing && String(existing.status || '').trim() !== 'draft') {
      throw new Error('An entry is already submitted for this station and date.');
    }

    const [station, openingReadings, priceSnapshot] = await Promise.all([
      Station.findById(stationId),
      ShiftEntry.openingReadingsFor(stationId, date),
      FuelPrice.getSnapshot(date, stationId),
    ]);
    const normalizedClosingReadings = normalizePartialPumpReadings(closingReadings, station);
    const normalizedPumpSalesmen = normalizePartialPumpSalesmen(pumpSalesmen, station);
    const normalizedPumpAttendants = buildPumpAttendantsFromSalesmen({
      pumpSalesmen: normalizedPumpSalesmen,
      pumpAttendants,
      station,
      partial: true,
    });
    const normalizedPumpTesting = normalizePartialPumpTesting(pumpTesting, station);
    const normalizedPumpPayments = normalizePartialPumpPayments(pumpPayments, station);
    const normalizedPumpCollections = normalizePartialPumpCollections(pumpCollections, station);
    const normalizedPaymentBreakdown = normalizePaymentBreakdown(paymentBreakdown);
    const normalizedCreditEntries = normalizeCreditEntries(creditEntries);
    const normalizedCreditCollections = normalizeCreditCollections(creditCollections);
    const pumpLabels = Object.fromEntries(
      (station?.pumps || []).map((pump) => [pump.id, pump.label]),
    );
    const metrics = calculateMetrics({
      openingReadings,
      closingReadings: normalizedClosingReadings,
      priceSnapshot,
      pumpTesting: normalizedPumpTesting,
      pumpPayments: normalizedPumpPayments,
      pumpCollections: normalizedPumpCollections,
      paymentBreakdown: normalizedPaymentBreakdown,
      creditEntries: normalizedCreditEntries,
      creditCollections: normalizedCreditCollections,
      mismatchReason,
      meterLimits: station?.meterLimits || {},
      readingMode: 'meter',
      pumpLabels,
      flagThreshold: station?.flagThreshold ?? 0.01,
    });

    const timestamp = nowIso();
    const entry = existing || new ShiftEntry({
      id: entryId(stationId, date),
      stationId,
      date,
      status: 'draft',
      submittedBy,
      readingMode: 'meter',
    });

    entry.status = 'draft';
    entry.submittedBy = entry.submittedBy || submittedBy;
    entry.submittedAt = null;
    entry.updatedAt = timestamp;
    entry.flagged = false;
    entry.varianceNote = '';
    entry.mismatchReason = String(mismatchReason || '').trim();
    entry.readingMode = 'meter';
    entry.openingReadings = openingReadings;
    entry.closingReadings = normalizedClosingReadings;
    entry.soldByPump = metrics.soldByPump;
    entry.pumpSalesmen = normalizedPumpSalesmen;
    entry.pumpAttendants = normalizedPumpAttendants;
    entry.pumpTesting = normalizedPumpTesting;
    entry.pumpPayments = normalizedPumpPayments;
    entry.pumpCollections = normalizedPumpCollections;
    entry.paymentBreakdown = normalizedPaymentBreakdown;
    entry.creditEntries = normalizedCreditEntries;
    entry.creditCollections = normalizedCreditCollections;
    entry.totals = metrics.totals;
    entry.inventoryTotals = metrics.inventoryTotals;
    entry.revenue = metrics.computedRevenue;
    entry.computedRevenue = metrics.computedRevenue;
    entry.paymentTotal = metrics.paymentTotal;
    entry.salesSettlementTotal = metrics.salesSettlementTotal;
    entry.creditCollectionTotal = metrics.creditCollectionTotal;
    entry.creditTotal = metrics.creditTotal;
    entry.mismatchAmount = metrics.mismatchAmount;
    entry.profit = metrics.profit;
    entry.priceSnapshot = priceSnapshot;

    await entry.save();
    return ShiftEntry.findById(entry.id);
  }

  static async create({
    stationId,
    date,
    submittedBy,
    closingReadings,
    pumpSalesmen,
    pumpAttendants,
    pumpTesting,
    pumpPayments,
    pumpCollections,
    paymentBreakdown,
    creditEntries,
    creditCollections,
    mismatchReason,
  }) {
    validateDate(date);
    await ShiftEntry.assertAllowedEntryDate(stationId, date);
    const existing = await ShiftEntry.findByDate(stationId, date);
    if (existing) {
      if (String(existing.status || '').trim() === 'draft') {
        return existing.updateBySales({
          closingReadings,
          pumpSalesmen,
          pumpAttendants,
          pumpTesting,
          pumpPayments,
          pumpCollections,
          paymentBreakdown,
          creditEntries,
          creditCollections,
          mismatchReason,
          submittedBy,
        });
      }
      throw new Error('An entry already exists for this station and date.');
    }

    const station = await Station.findById(stationId);
    const preview = await ShiftEntry.preview({
      stationId,
      date,
      closingReadings,
      pumpSalesmen,
      pumpAttendants,
      pumpTesting,
      pumpPayments,
      pumpCollections,
      paymentBreakdown,
      creditEntries,
      creditCollections,
      mismatchReason,
    });

    if (Math.abs(preview.mismatchAmount) >= (station?.flagThreshold ?? 0.01) && !String(mismatchReason || '').trim()) {
      throw new Error('Mismatch reason is required when payment does not match computed revenue.');
    }

    const timestamp = nowIso();
    const entry = new ShiftEntry({
      ...preview.toJson(),
      id: entryId(stationId, date),
      stationId,
      date,
      status: preview.flagged ? 'flagged' : 'submitted',
      submittedBy,
      submittedAt: timestamp,
      updatedAt: timestamp,
      readingMode: 'meter',
    });

    await entry.save();
    await ShiftEntry.resolveCreditCustomers(entry);
    await CreditTransaction.syncForEntry(entry, {createdBy: submittedBy});
    return entry;
  }

  static async resolveCreditCustomers(entry) {
    if (!entry?.stationId) {
      return entry;
    }
    const usageTimestamp = entry.updatedAt || entry.submittedAt || nowIso();
    entry.creditEntries = await Promise.all(
      (entry.creditEntries || []).map(async (item) => {
        const resolved = await CreditCustomer.resolveReference({
          stationId: entry.stationId,
          customerId: item.customerId,
          name: item.name,
          usedAt: usageTimestamp,
        });
        if (!resolved) {
          return item;
        }
        return {
          ...item,
          customerId: resolved.customerId,
          name: resolved.name,
        };
      }),
    );
    entry.creditCollections = await Promise.all(
      (entry.creditCollections || []).map(async (item) => {
        const resolved = await CreditCustomer.resolveReference({
          stationId: entry.stationId,
          customerId: item.customerId,
          name: item.name,
          usedAt: usageTimestamp,
        });
        if (!resolved) {
          return item;
        }
        return {
          ...item,
          customerId: resolved.customerId,
          name: resolved.name,
        };
      }),
    );
    await entry.save();
    return entry;
  }

  static async recomputeFrom(stationId, date) {
    const station = await Station.findById(stationId);
    const hydratedEntries = await ShiftEntry.allForStation(stationId, {
      forceRefresh: true,
    });
    const targetEntries = hydratedEntries.filter(
      (entry) => String(entry.date) >= String(date),
    );

    for (const entry of targetEntries) {
      const pumpLabels = Object.fromEntries(
        (station?.pumps || []).map((pump) => [pump.id, pump.label]),
      );
      const metrics = calculateMetrics({
        openingReadings: entry.openingReadings,
        closingReadings: entry.closingReadings,
        priceSnapshot: entry.priceSnapshot,
        pumpTesting: entry.pumpTesting,
        pumpPayments: entry.pumpPayments,
        pumpCollections: entry.pumpCollections,
        paymentBreakdown: entry.paymentBreakdown,
        creditEntries: entry.creditEntries,
        creditCollections: entry.creditCollections,
        mismatchReason: entry.mismatchReason,
        meterLimits: station?.meterLimits || {},
        readingMode: entry.readingMode || 'stock',
        pumpLabels,
        flagThreshold: station?.flagThreshold ?? 0.01,
      });

      entry.soldByPump = metrics.soldByPump;
      entry.totals = metrics.totals;
      entry.inventoryTotals = metrics.inventoryTotals;
      entry.revenue = metrics.computedRevenue;
      entry.computedRevenue = metrics.computedRevenue;
      entry.paymentTotal = metrics.paymentTotal;
      entry.salesSettlementTotal = metrics.salesSettlementTotal;
      entry.creditCollectionTotal = metrics.creditCollectionTotal;
      entry.creditTotal = metrics.creditTotal;
      entry.mismatchAmount = metrics.mismatchAmount;
      entry.profit = metrics.profit;
      entry.varianceNote = metrics.varianceNote;
      if (entry.approvedAt) {
        entry.flagged = false;
        entry.status = 'approved';
      } else {
        entry.flagged = metrics.flagged;
        entry.status = metrics.flagged
          ? 'flagged'
          : entry.reviewedBy
            ? 'adjusted'
            : 'submitted';
      }
      await entry.save();
    }
  }

  async updateByAdmin({
    closingReadings,
    pumpSalesmen,
    pumpAttendants,
    pumpTesting,
    pumpPayments,
    pumpCollections,
    paymentBreakdown,
    creditEntries,
    creditCollections,
    mismatchReason,
    reviewedBy,
  }) {
    const station = await Station.findById(this.stationId);
    const pumpLabels = Object.fromEntries(
      (station?.pumps || []).map((pump) => [pump.id, pump.label]),
    );
    const nextClosingReadings = normalizePumpReadings(closingReadings, station);
    const nextPumpSalesmen = normalizePumpSalesmen(pumpSalesmen, station);
    const nextPumpAttendants = buildPumpAttendantsFromSalesmen({
      pumpSalesmen: nextPumpSalesmen,
      pumpAttendants,
      station,
    });
    const nextPumpTesting = normalizePumpTesting(pumpTesting, station);
    const nextPumpPayments = normalizePumpPayments(pumpPayments, station);
    const nextPumpCollections = normalizePumpCollections(pumpCollections, station);
    const nextPaymentBreakdown = normalizePaymentBreakdown(paymentBreakdown);
    const nextCreditEntries = normalizeCreditEntries(creditEntries);
    const nextCreditCollections = normalizeCreditCollections(creditCollections);
    const nextMismatchReason = String(mismatchReason || '').trim();
    validateCreditEntries({
      creditEntries: nextCreditEntries,
      pumpPayments: nextPumpPayments,
      station,
      pumpLabels,
    });
    const previewMetrics = calculateMetrics({
      openingReadings: this.openingReadings,
      closingReadings: nextClosingReadings,
      priceSnapshot: this.priceSnapshot,
      pumpTesting: nextPumpTesting,
      pumpPayments: nextPumpPayments,
      pumpCollections: nextPumpCollections,
      paymentBreakdown: nextPaymentBreakdown,
      creditEntries: nextCreditEntries,
      creditCollections: nextCreditCollections,
      mismatchReason: nextMismatchReason,
      meterLimits: station?.meterLimits || {},
      readingMode: 'meter',
      pumpLabels,
      flagThreshold: station?.flagThreshold ?? 0.01,
    });
    if (Math.abs(previewMetrics.mismatchAmount) >= (station?.flagThreshold ?? 0.01) && !nextMismatchReason) {
      throw new Error('Mismatch reason is required when payment does not match computed revenue.');
    }
    this.closingReadings = nextClosingReadings;
    this.pumpSalesmen = nextPumpSalesmen;
    this.pumpAttendants = nextPumpAttendants;
    this.pumpTesting = nextPumpTesting;
    this.pumpPayments = nextPumpPayments;
    this.pumpCollections = nextPumpCollections;
    this.paymentBreakdown = nextPaymentBreakdown;
    this.creditEntries = nextCreditEntries;
    this.creditCollections = nextCreditCollections;
    this.mismatchReason = nextMismatchReason;
    this.inventoryTotals = previewMetrics.inventoryTotals;
    this.readingMode = 'meter';
    this.reviewedBy = reviewedBy;
    this.status = 'adjusted';
    this.updatedAt = nowIso();
    await this.save();
    await ShiftEntry.resolveCreditCustomers(this);
    await CreditTransaction.syncForEntry(this, {createdBy: reviewedBy || this.submittedBy});
    await ShiftEntry.recomputeFrom(this.stationId, this.date);
    return ShiftEntry.findById(this.id);
  }

  async updateBySales({
    closingReadings,
    pumpSalesmen,
    pumpAttendants,
    pumpTesting,
    pumpPayments,
    pumpCollections,
    paymentBreakdown,
    creditEntries,
    creditCollections,
    mismatchReason,
    submittedBy,
  }) {
    if (this.approvedAt || this.status === 'approved') {
      throw new Error('Approved entries cannot be edited from sales.');
    }

    const station = await Station.findById(this.stationId);
    const pumpLabels = Object.fromEntries(
      (station?.pumps || []).map((pump) => [pump.id, pump.label]),
    );
    const nextClosingReadings = normalizePumpReadings(closingReadings, station);
    const nextPumpSalesmen = normalizePumpSalesmen(pumpSalesmen, station);
    const nextPumpAttendants = buildPumpAttendantsFromSalesmen({
      pumpSalesmen: nextPumpSalesmen,
      pumpAttendants,
      station,
    });
    const nextPumpTesting = normalizePumpTesting(pumpTesting, station);
    const nextPumpPayments = normalizePumpPayments(pumpPayments, station);
    const nextPumpCollections = normalizePumpCollections(pumpCollections, station);
    const nextPaymentBreakdown = normalizePaymentBreakdown(paymentBreakdown);
    const nextCreditEntries = normalizeCreditEntries(creditEntries);
    const nextCreditCollections = normalizeCreditCollections(creditCollections);
    const nextMismatchReason = String(mismatchReason || '').trim();
    validateCreditEntries({
      creditEntries: nextCreditEntries,
      pumpPayments: nextPumpPayments,
      station,
      pumpLabels,
    });
    const previewMetrics = calculateMetrics({
      openingReadings: this.openingReadings,
      closingReadings: nextClosingReadings,
      priceSnapshot: this.priceSnapshot,
      pumpTesting: nextPumpTesting,
      pumpPayments: nextPumpPayments,
      pumpCollections: nextPumpCollections,
      paymentBreakdown: nextPaymentBreakdown,
      creditEntries: nextCreditEntries,
      creditCollections: nextCreditCollections,
      mismatchReason: nextMismatchReason,
      meterLimits: station?.meterLimits || {},
      readingMode: 'meter',
      pumpLabels,
      flagThreshold: station?.flagThreshold ?? 0.01,
    });
    if (Math.abs(previewMetrics.mismatchAmount) >= (station?.flagThreshold ?? 0.01) && !nextMismatchReason) {
      throw new Error('Mismatch reason is required when payment does not match computed revenue.');
    }

    this.closingReadings = nextClosingReadings;
    this.pumpSalesmen = nextPumpSalesmen;
    this.pumpAttendants = nextPumpAttendants;
    this.pumpTesting = nextPumpTesting;
    this.pumpPayments = nextPumpPayments;
    this.pumpCollections = nextPumpCollections;
    this.paymentBreakdown = nextPaymentBreakdown;
    this.creditEntries = nextCreditEntries;
    this.creditCollections = nextCreditCollections;
    this.mismatchReason = nextMismatchReason;
    this.inventoryTotals = previewMetrics.inventoryTotals;
    this.readingMode = 'meter';
    this.reviewedBy = '';
    this.approvedAt = null;
    const timestamp = nowIso();
    if (String(this.status || '').trim() === 'draft') {
      this.submittedBy = submittedBy || this.submittedBy;
      this.submittedAt = timestamp;
      this.status = previewMetrics.flagged ? 'flagged' : 'submitted';
    }
    this.updatedAt = timestamp;
    await this.save();
    await ShiftEntry.resolveCreditCustomers(this);
    await CreditTransaction.syncForEntry(this, {createdBy: this.submittedBy});
    await ShiftEntry.recomputeFrom(this.stationId, this.date);
    return ShiftEntry.findById(this.id);
  }

  async approve(reviewedBy) {
    this.reviewedBy = reviewedBy;
    this.approvedAt = nowIso();
    this.status = 'approved';
    this.flagged = false;
    this.updatedAt = nowIso();
    await this.save();
    await ShiftEntry.lockDaySetupsThroughDate(this.stationId, this.date, {
      lockedBy: reviewedBy,
    });
    await ShiftEntry.resolveCreditCustomers(this);
    await CreditTransaction.syncForEntry(this, {
      createdBy: reviewedBy || this.submittedBy,
    });
    return ShiftEntry.findById(this.id);
  }

  static async deleteOne(id) {
    const entry = ShiftEntry.fromRecord(await getDataRecord(ENTITY_TYPE, id));
    if (!entry) {
      return null;
    }
    await CreditTransaction.deleteByEntryId(entry.id);
    await deleteDataRecord(ENTITY_TYPE, id);
    ShiftEntry.invalidateStationCache(entry.stationId);
    await ShiftEntry.recomputeFrom(entry.stationId, entry.date);
    return entry;
  }

  static async changeDate(entryId_, newDate, {changedBy} = {}) {
    throw new Error('Entry date changes are disabled when sequential day setup is enforced.');
  }

  static async clearAllForStation(stationId) {
    const entries = await ShiftEntry.findRaw({stationId});
    await Promise.all(
      entries.map(async (entry) => {
        await CreditTransaction.deleteByEntryId(entry.id);
        await deleteDataRecord(ENTITY_TYPE, entry.id);
      }),
    );
    ShiftEntry.invalidateStationCache(stationId);
    return entries.length;
  }

  toJson() {
    return {
      id: this.id,
      stationId: this.stationId,
      date: this.date,
      shift: DAILY_SHIFT,
      status: this.status,
      submittedBy: this.submittedBy,
      submittedByName: this.submittedByName || '',
      reviewedBy: this.reviewedBy,
      approvedAt: this.approvedAt,
      submittedAt: this.submittedAt,
      updatedAt: this.updatedAt,
      flagged: this.flagged,
      varianceNote: this.varianceNote,
      mismatchReason: this.mismatchReason,
      readingMode: this.readingMode,
      openingReadings: this.openingReadings,
      closingReadings: this.closingReadings,
      soldByPump: this.soldByPump,
      pumpSalesmen: this.pumpSalesmen,
      pumpAttendants: this.pumpAttendants,
      pumpTesting: this.pumpTesting,
      pumpPayments: this.pumpPayments,
      pumpCollections: this.pumpCollections,
      paymentBreakdown: this.paymentBreakdown,
      creditEntries: this.creditEntries,
      creditCollections: this.creditCollections,
      totals: this.totals,
      inventoryTotals: this.inventoryTotals,
      revenue: this.revenue,
      computedRevenue: this.computedRevenue,
      paymentTotal: this.paymentTotal,
      salesSettlementTotal: this.salesSettlementTotal,
      creditCollectionTotal: this.creditCollectionTotal,
      creditTotal: this.creditTotal,
      mismatchAmount: this.mismatchAmount,
      profit: this.profit,
      priceSnapshot: this.priceSnapshot,
    };
  }

  toSummaryJson() {
    return {
      id: this.id,
      stationId: this.stationId,
      date: this.date,
      shift: DAILY_SHIFT,
      status: this.status,
      submittedBy: this.submittedBy,
      submittedByName: this.submittedByName || '',
      reviewedBy: this.reviewedBy,
      approvedAt: this.approvedAt,
      submittedAt: this.submittedAt,
      updatedAt: this.updatedAt,
      flagged: this.flagged,
      varianceNote: this.varianceNote,
      mismatchReason: this.mismatchReason,
      pumpSalesmen: this.pumpSalesmen,
      pumpAttendants: this.pumpAttendants,
      totals: this.totals,
      inventoryTotals: this.inventoryTotals,
      revenue: this.revenue,
      computedRevenue: this.computedRevenue,
      paymentTotal: this.paymentTotal,
      salesSettlementTotal: this.salesSettlementTotal,
      creditCollectionTotal: this.creditCollectionTotal,
      mismatchAmount: this.mismatchAmount,
      profit: this.profit,
    };
  }

  static async attachSubmittedByNames(entries) {
    const resolvedEntries = (entries || []).filter(Boolean);
    const submitterIds = [...new Set(
      resolvedEntries
        .map((entry) => String(entry.submittedBy || '').trim())
        .filter((value) => value && value !== 'preview'),
    )];

    const users = await Promise.all(
      submitterIds.map((submitterId) => User.findById(submitterId)),
    );
    const nameById = new Map();
    users.forEach((user, index) => {
      if (user?.name) {
        nameById.set(submitterIds[index], user.name);
      }
    });

    resolvedEntries.forEach((entry) => {
      const submittedBy = String(entry.submittedBy || '').trim();
      entry.submittedByName = submittedBy === 'preview'
        ? 'Preview'
        : (nameById.get(submittedBy) || '');
    });

    return resolvedEntries;
  }

  static async toResolvedJson(entry, {summary = false} = {}) {
    if (!entry) {
      return null;
    }
    await ShiftEntry.attachSubmittedByNames([entry]);
    return summary ? entry.toSummaryJson() : entry.toJson();
  }

  static async toResolvedJsonList(entries, {summary = false} = {}) {
    await ShiftEntry.attachSubmittedByNames(entries);
    return (entries || []).map((entry) => (summary ? entry.toSummaryJson() : entry.toJson()));
  }
}

module.exports = ShiftEntry;
