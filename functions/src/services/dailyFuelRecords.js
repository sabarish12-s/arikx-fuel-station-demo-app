const DailyFuelRecord = require('../models/DailyFuelRecord');
const FuelPrice = require('../models/FuelPrice');
const InventoryLedgerEntry = require('../models/InventoryLedgerEntry');
const Station = require('../models/Station');
const StationDaySetup = require('../models/StationDaySetup');
const {todayInStationTimeZone} = require('../utils/time');

function roundNumber(value) {
  return Math.round((Number(value || 0) + Number.EPSILON) * 1000) / 1000;
}

function normalizeDateKey(value) {
  const raw = String(value || '').trim();
  if (!raw) {
    throw new Error('Valid effective date is required.');
  }
  const matched = raw.match(/^\d{4}-\d{2}-\d{2}/);
  if (matched) {
    return matched[0];
  }
  const parsed = new Date(raw);
  if (Number.isNaN(parsed.getTime())) {
    throw new Error('Valid effective date is required.');
  }
  return parsed.toISOString().slice(0, 10);
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

function twoFuelMap(source = {}) {
  return {
    petrol: roundNumber(source?.petrol),
    diesel: roundNumber(source?.diesel),
  };
}

function sellingPriceMap(source = {}) {
  return {
    petrol: roundNumber(source?.petrol?.sellingPrice),
    diesel: roundNumber(source?.diesel?.sellingPrice),
  };
}

function isCompleteRecord(record) {
  return Number(record?.density?.petrol || 0) > 0 && Number(record?.density?.diesel || 0) > 0;
}

async function resolveOpeningStock(stationId, date) {
  const targetDate = normalizeDateKey(date);
  const previousDate = shiftIsoDate(targetDate, -1);
  const [ledgerEntries, activeSetup, station] = await Promise.all([
    InventoryLedgerEntry.allForStationRange(stationId, {toDate: previousDate}),
    StationDaySetup.latestActiveOnOrBefore(stationId, targetDate),
    Station.findById(stationId),
  ]);

  const latestBalanceEntry = ledgerEntries.at(-1) || null;
  if (latestBalanceEntry) {
    return {
      sourceClosingDate: previousDate,
      openingStock: {
        petrol: roundNumber(latestBalanceEntry.balanceAfter?.petrol),
        diesel: roundNumber(latestBalanceEntry.balanceAfter?.diesel),
      },
    };
  }

  const fallbackStock =
    activeSetup?.startingStock ||
    station?.inventoryPlanning?.openingStock ||
    {};
  return {
    sourceClosingDate: String(activeSetup?.effectiveDate || '').trim(),
    openingStock: twoFuelMap(fallbackStock),
  };
}

async function resolvePrice(stationId, date) {
  return sellingPriceMap(await FuelPrice.getSnapshot(normalizeDateKey(date), stationId));
}

async function buildResolvedDailyFuelRecord(record, stationId, date) {
  const targetDate = normalizeDateKey(date);
  const [{openingStock, sourceClosingDate}, price] = await Promise.all([
    resolveOpeningStock(stationId, targetDate),
    resolvePrice(stationId, targetDate),
  ]);

  return {
    id: record?.id || DailyFuelRecord.idFor(stationId, targetDate),
    stationId,
    date: targetDate,
    openingStock,
    density: {
      petrol: roundNumber(record?.density?.petrol),
      diesel: roundNumber(record?.density?.diesel),
    },
    price,
    sourceClosingDate,
    createdBy: record?.createdBy || '',
    createdByName: record?.createdByName || '',
    updatedBy: record?.updatedBy || '',
    updatedByName: record?.updatedByName || '',
    createdAt: record?.createdAt || '',
    updatedAt: record?.updatedAt || '',
    exists: !!record,
    complete: isCompleteRecord(record),
  };
}

async function getDailyFuelRecordForDate(stationId, date) {
  const targetDate = normalizeDateKey(date);
  const record = await DailyFuelRecord.findByDate(stationId, targetDate);
  return buildResolvedDailyFuelRecord(record, stationId, targetDate);
}

async function listDailyFuelRecordsForStation(
  stationId,
  {fromDate = '', toDate = '', forceRefresh = false} = {},
) {
  const records = await DailyFuelRecord.allForStationRange(stationId, {
    fromDate,
    toDate,
    forceRefresh,
  });
  const resolved = await Promise.all(
    records.map((record) => buildResolvedDailyFuelRecord(record, stationId, record.date)),
  );
  return resolved.sort((left, right) => String(left.date || '').localeCompare(String(right.date || '')));
}

async function saveDailyFuelRecord({
  stationId,
  date,
  density,
  updatedBy = '',
  updatedByName = '',
}) {
  const targetDate = normalizeDateKey(date);
  if (targetDate.localeCompare(todayInStationTimeZone()) > 0) {
    throw new Error('Future dates are not allowed for the daily fuel register.');
  }

  const activeSetup = await StationDaySetup.latestActiveOnOrBefore(stationId, targetDate);
  if (!activeSetup) {
    throw new Error('Create a day setup before saving the daily fuel register.');
  }

  const existing = await DailyFuelRecord.findByDate(stationId, targetDate);
  const record = existing || new DailyFuelRecord({
    id: DailyFuelRecord.idFor(stationId, targetDate),
    stationId,
    date: targetDate,
    density,
    createdBy: updatedBy,
    createdByName: updatedByName,
  });

  record.density = {
    petrol: roundNumber(density?.petrol),
    diesel: roundNumber(density?.diesel),
  };
  if (!(record.density.petrol > 0) || !(record.density.diesel > 0)) {
    throw new Error('Petrol and diesel density must be greater than zero.');
  }
  record.updatedBy = String(updatedBy || '').trim();
  record.updatedByName = String(updatedByName || '').trim();
  await record.save();

  return {
    created: !existing,
    record,
    resolved: await buildResolvedDailyFuelRecord(record, stationId, targetDate),
  };
}

module.exports = {
  buildResolvedDailyFuelRecord,
  getDailyFuelRecordForDate,
  isCompleteRecord,
  listDailyFuelRecordsForStation,
  saveDailyFuelRecord,
  shiftIsoDate,
};
