const {deleteDataRecord, listDataRecords} = require('../utils/authStore');
const CreditCustomer = require('../models/CreditCustomer');
const CreditTransaction = require('../models/CreditTransaction');
const DeliveryReceipt = require('../models/DeliveryReceipt');
const ShiftEntry = require('../models/ShiftEntry');
const Station = require('../models/Station');
const StationDaySetup = require('../models/StationDaySetup');
const {nowIso} = require('../utils/time');

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

function roundNumber(value) {
  return Math.round((Number(value || 0) + Number.EPSILON) * 100) / 100;
}

function normalizeDateKey(value) {
  const raw = String(value || '').trim();
  if (!raw) {
    return '';
  }
  const matchedDate = raw.match(/^\d{4}-\d{2}-\d{2}/);
  if (matchedDate) {
    return matchedDate[0];
  }
  const parsed = new Date(raw);
  if (Number.isNaN(parsed.getTime())) {
    return '';
  }
  return parsed.toISOString().slice(0, 10);
}

function normalizeReadingsForStation(readings = {}, station) {
  return (station?.pumps || []).reduce((result, pump) => {
    const source = readings?.[pump.id] || {};
    result[pump.id] = {
      petrol: roundNumber(source.petrol),
      diesel: roundNumber(source.diesel),
      twoT: roundNumber(source.twoT),
    };
    return result;
  }, {});
}

function normalizeStock(stock = {}) {
  return {
    petrol: roundNumber(stock.petrol),
    diesel: roundNumber(stock.diesel),
    two_t_oil: roundNumber(stock.two_t_oil),
  };
}

function normalizeFuelPrices(prices = {}) {
  return ['petrol', 'diesel', 'two_t_oil'].reduce((result, fuelTypeId) => {
    const source = prices?.[fuelTypeId] || {};
    result[fuelTypeId] = {
      costPrice: roundNumber(source.costPrice),
      sellingPrice: roundNumber(source.sellingPrice),
    };
    return result;
  }, {});
}

async function approvedEntryDatesForStation(stationId) {
  const entries = await ShiftEntry.allForStation(stationId, {forceRefresh: true});
  return entries
    .filter((entry) => ShiftEntry.isFinalized(entry))
    .map((entry) => String(entry.date || ''))
    .sort((left, right) => left.localeCompare(right));
}

async function getDaySetupState(stationId) {
  const [firstSetup, approvedDates, setups] = await Promise.all([
    StationDaySetup.earliestActiveForStation(stationId),
    approvedEntryDatesForStation(stationId),
    StationDaySetup.listForStation(stationId),
  ]);

  if (!firstSetup) {
    return {
      setupExists: false,
      allowedEntryDate: '',
      nextAllowedSetupDate: '',
      activeSetupDate: '',
      entryLockedReason: 'Create a day setup before sales entry can start.',
      setups,
    };
  }

  const latestApprovedDate = approvedDates.at(-1) || '';
  const allowedEntryDate = latestApprovedDate
    ? shiftIsoDate(latestApprovedDate, 1)
    : firstSetup.effectiveDate;
  const activeSetup = await StationDaySetup.latestActiveOnOrBefore(
    stationId,
    allowedEntryDate,
  );

  return {
    setupExists: true,
    allowedEntryDate,
    nextAllowedSetupDate: allowedEntryDate,
    activeSetupDate: activeSetup?.effectiveDate || '',
    entryLockedReason: '',
    setups,
  };
}

async function assertAllowedEntryDate(stationId, effectiveDate) {
  const normalizedDate = normalizeDateKey(effectiveDate);
  const state = await getDaySetupState(stationId);
  if (!state.setupExists || !state.allowedEntryDate) {
    throw new Error(state.entryLockedReason || 'Create a day setup before sales entry can start.');
  }
  if (normalizedDate !== state.allowedEntryDate) {
    throw new Error(`Sales entry is locked to ${state.allowedEntryDate}.`);
  }
  return state;
}

async function isLockedByApprovedEntry(stationId, effectiveDate) {
  const normalizedDate = normalizeDateKey(effectiveDate);
  if (!normalizedDate) {
    return false;
  }
  const approvedDates = await approvedEntryDatesForStation(stationId);
  return approvedDates.some((date) => String(date).localeCompare(normalizedDate) >= 0);
}

async function lockSetupsThroughDate(stationId, uptoDate, actor = {}) {
  const normalizedDate = normalizeDateKey(uptoDate);
  if (!normalizedDate) {
    return [];
  }
  const timestamp = nowIso();
  const setups = await StationDaySetup.listForStation(stationId);
  const locked = [];
  for (const setup of setups) {
    if (String(setup.effectiveDate).localeCompare(normalizedDate) > 0) {
      continue;
    }
    if (setup.isLocked) {
      locked.push(setup);
      continue;
    }
    setup.lockedAt = timestamp;
    setup.lockedBy = String(actor.lockedBy || '').trim();
    setup.lockedByName = String(actor.lockedByName || '').trim();
    await setup.save();
    locked.push(setup);
  }
  return locked;
}

async function createOrUpdateDaySetup({
  stationId,
  effectiveDate,
  openingReadings,
  startingStock,
  fuelPrices,
  note = '',
  actorId = '',
  actorName = '',
}) {
  const normalizedDate = normalizeDateKey(effectiveDate);
  if (!normalizedDate) {
    throw new Error('Valid effective date is required.');
  }

  const station = await Station.findById(stationId);
  if (!station) {
    throw new Error('Station not found.');
  }

  const existing = await StationDaySetup.findByDate(stationId, normalizedDate);
  const hasApprovedLock = await isLockedByApprovedEntry(stationId, normalizedDate);
  if (existing && (existing.isLocked || hasApprovedLock)) {
    throw new Error('This day setup is locked because sales have already been approved for that date.');
  }

  if (!existing) {
    const state = await getDaySetupState(stationId);
    if (state.setupExists && normalizedDate !== state.nextAllowedSetupDate) {
      throw new Error(`The next allowed day setup date is ${state.nextAllowedSetupDate}.`);
    }
  }

  const setup = existing || new StationDaySetup({
    id: StationDaySetup.idFor(stationId, normalizedDate),
    stationId,
    effectiveDate: normalizedDate,
    createdBy: actorId,
    createdByName: actorName,
  });

  setup.effectiveDate = normalizedDate;
  setup.openingReadings = normalizeReadingsForStation(openingReadings, station);
  setup.startingStock = normalizeStock(startingStock);
  setup.fuelPrices = normalizeFuelPrices(fuelPrices);
  setup.note = String(note || '').trim();
  setup.updatedBy = String(actorId || '').trim();
  setup.updatedByName = String(actorName || '').trim();

  await setup.save();
  ShiftEntry.invalidateStationCache(stationId);
  return setup;
}

async function deleteDaySetup({
  stationId,
  effectiveDate,
  deletedBy = '',
  deletedByName = '',
}) {
  const normalizedDate = normalizeDateKey(effectiveDate);
  const setup = await StationDaySetup.findByDate(stationId, normalizedDate);
  if (!setup || setup.isDeleted) {
    return null;
  }
  const hasApprovedLock = await isLockedByApprovedEntry(stationId, normalizedDate);
  if (setup.isLocked || hasApprovedLock) {
    throw new Error('This day setup is locked because sales have already been approved for that date.');
  }
  const entries = await ShiftEntry.allForStationRange(stationId, {
    fromDate: normalizedDate,
    toDate: normalizedDate,
    includePrevious: false,
  });
  if (entries.length > 0) {
    throw new Error('Delete the sales entry on this date before deleting the day setup.');
  }
  setup.deletedAt = nowIso();
  setup.deletedBy = String(deletedBy || '').trim();
  setup.deletedByName = String(deletedByName || '').trim();
  setup.updatedBy = String(deletedBy || '').trim();
  setup.updatedByName = String(deletedByName || '').trim();
  await setup.save();
  ShiftEntry.invalidateStationCache(stationId);
  return setup;
}

async function listDaySetupHistory(stationId, options = {}) {
  await StationDaySetup.purgeExpiredDeletedHistory();
  return StationDaySetup.listForStation(stationId, options);
}

async function resetOperationalDataForStation(stationId) {
  const deleted = {
    shiftEntries: await ShiftEntry.clearAllForStation(stationId),
    daySetups: 0,
    deliveries: 0,
    creditTransactions: 0,
    creditCustomers: 0,
    inventoryAlerts: 0,
    inventoryLedgerEntries: 0,
    inventoryStockSnapshots: 0,
    pumpOpeningReadingLogs: 0,
    fuelPriceHistory: 0,
    dailyFuelRecords: 0,
  };

  const recordsByEntityType = {
    stationDaySetup: await listDataRecords('stationDaySetup'),
    deliveryReceipt: await listDataRecords('deliveryReceipt'),
    creditTransaction: await listDataRecords('creditTransaction'),
    creditCustomer: await listDataRecords('creditCustomer'),
    inventoryAlertLog: await listDataRecords('inventoryAlertLog'),
    inventoryLedgerEntry: await listDataRecords('inventoryLedgerEntry'),
    inventoryStockSnapshot: await listDataRecords('inventoryStockSnapshot'),
    pumpOpeningReadingLog: await listDataRecords('pumpOpeningReadingLog'),
    fuelPrice: await listDataRecords('fuelPrice'),
    dailyFuelRecord: await listDataRecords('dailyFuelRecord'),
  };

  for (const record of recordsByEntityType.stationDaySetup) {
    if (record?.customClaims?.sid === stationId) {
      await deleteDataRecord('stationDaySetup', record.customClaims.ek || record.uid);
      deleted.daySetups += 1;
    }
  }
  for (const record of recordsByEntityType.deliveryReceipt) {
    if (record?.customClaims?.sid === stationId) {
      await deleteDataRecord('deliveryReceipt', record.customClaims.ek || record.uid);
      deleted.deliveries += 1;
    }
  }
  for (const record of recordsByEntityType.creditTransaction) {
    if (record?.customClaims?.sid === stationId) {
      await deleteDataRecord('creditTransaction', record.customClaims.ek || record.uid);
      deleted.creditTransactions += 1;
    }
  }
  for (const record of recordsByEntityType.creditCustomer) {
    if (record?.customClaims?.sid === stationId) {
      await deleteDataRecord('creditCustomer', record.customClaims.ek || record.uid);
      deleted.creditCustomers += 1;
    }
  }
  for (const record of recordsByEntityType.inventoryAlertLog) {
    if (record?.customClaims?.sid === stationId) {
      await deleteDataRecord('inventoryAlertLog', record.customClaims.ek || record.uid);
      deleted.inventoryAlerts += 1;
    }
  }
  for (const record of recordsByEntityType.inventoryLedgerEntry) {
    if (record?.customClaims?.sid === stationId) {
      await deleteDataRecord('inventoryLedgerEntry', record.customClaims.ek || record.uid);
      deleted.inventoryLedgerEntries += 1;
    }
  }
  for (const record of recordsByEntityType.inventoryStockSnapshot) {
    if (record?.customClaims?.sid === stationId) {
      await deleteDataRecord('inventoryStockSnapshot', record.customClaims.ek || record.uid);
      deleted.inventoryStockSnapshots += 1;
    }
  }
  for (const record of recordsByEntityType.pumpOpeningReadingLog) {
    if (record?.customClaims?.sid === stationId) {
      await deleteDataRecord('pumpOpeningReadingLog', record.customClaims.ek || record.uid);
      deleted.pumpOpeningReadingLogs += 1;
    }
  }
  for (const record of recordsByEntityType.fuelPrice) {
    await deleteDataRecord('fuelPrice', record.customClaims.ek || record.uid);
    deleted.fuelPriceHistory += 1;
  }
  for (const record of recordsByEntityType.dailyFuelRecord) {
    if (record?.customClaims?.sid === stationId) {
      await deleteDataRecord('dailyFuelRecord', record.customClaims.ek || record.uid);
      deleted.dailyFuelRecords += 1;
    }
  }

  StationDaySetup.invalidateStationCache(stationId);
  ShiftEntry.invalidateStationCache(stationId);
  CreditCustomer.invalidateStationCache(stationId);
  CreditTransaction.invalidateStationCache(stationId);
  DeliveryReceipt.invalidateStationCache(stationId);

  return deleted;
}

module.exports = {
  assertAllowedEntryDate,
  createOrUpdateDaySetup,
  deleteDaySetup,
  getDaySetupState,
  listDaySetupHistory,
  lockSetupsThroughDate,
  resetOperationalDataForStation,
  shiftIsoDate,
};
