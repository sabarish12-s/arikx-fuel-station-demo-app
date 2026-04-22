const {PumpOpeningReadingLog, normalizeReadings} = require('../models/PumpOpeningReadingLog');
const ShiftEntry = require('../models/ShiftEntry');
const Station = require('../models/Station');
const {nowIso, todayInStationTimeZone} = require('../utils/time');

const DELETED_HISTORY_RETENTION_DAYS = 30;

function deletedCutoffIso() {
  return new Date(
    Date.now() - DELETED_HISTORY_RETENTION_DAYS * 24 * 60 * 60 * 1000,
  ).toISOString();
}

function isDeleted(log) {
  return String(log?.deletedAt || '').trim().length > 0;
}

function isExpiredDeleted(log, cutoffIso = deletedCutoffIso()) {
  const deletedAt = String(log?.deletedAt || '').trim();
  return deletedAt.length > 0 && deletedAt.localeCompare(cutoffIso) < 0;
}

async function loadRetainedLogsForStation(stationId) {
  const logs = await PumpOpeningReadingLog.allForStation(stationId);
  const cutoffIso = deletedCutoffIso();
  const retained = [];
  for (const log of logs) {
    if (isExpiredDeleted(log, cutoffIso)) {
      await PumpOpeningReadingLog.deleteById(log.id);
      continue;
    }
    retained.push(log);
  }
  return retained;
}

async function seedInitialOpeningReadingsForStation(station) {
  if (!station?.id) {
    return null;
  }
  const createdAt = nowIso();
  const log = new PumpOpeningReadingLog({
    id: `${station.id}:${createdAt}:seed-opening-readings`,
    stationId: station.id,
    effectiveDate: createdAt.slice(0, 10) || todayInStationTimeZone(),
    readings: station.baseReadings || {},
    note: '',
    createdAt,
    createdBy: 'system',
    createdByName: 'System',
  });
  await log.save();
  return log;
}

async function ensureOpeningReadingLogsForStation(stationId, existingStation = null) {
  const station = existingStation || (await Station.findById(stationId));
  if (!station?.id) {
    return [];
  }
  const existing = (await loadRetainedLogsForStation(station.id)).filter(
    (log) => !isDeleted(log),
  );
  if (existing.length > 0) {
    return existing;
  }
  const seeded = await seedInitialOpeningReadingsForStation(station);
  return seeded ? [seeded] : [];
}

async function listOpeningReadingLogsForStation(
  stationId,
  {fromDate = '', toDate = '', deletedOnly = false} = {},
) {
  const logs = deletedOnly
    ? (await loadRetainedLogsForStation(stationId)).filter(isDeleted)
    : await ensureOpeningReadingLogsForStation(stationId);
  return logs.filter((log) => {
    if (fromDate && String(log.effectiveDate || '') < String(fromDate || '')) {
      return false;
    }
    if (toDate && String(log.effectiveDate || '') > String(toDate || '')) {
      return false;
    }
    return true;
  });
}

async function createOpeningReadingLog({
  stationId,
  effectiveDate,
  readings,
  note = '',
  createdBy = '',
  createdByName = '',
}) {
  const station = await Station.findById(stationId);
  if (!station?.id) {
    throw new Error('Station not found.');
  }
  await ensureOpeningReadingLogsForStation(stationId, station);
  const normalizedReadings = normalizeReadings(readings, station.pumps || []);
  const createdAt = nowIso();
  const log = new PumpOpeningReadingLog({
    id: `${stationId}:${effectiveDate}:${createdAt}:${Math.random().toString(36).slice(2, 8)}`,
    stationId,
    effectiveDate,
    readings: normalizedReadings,
    note,
    createdAt,
    createdBy,
    createdByName,
  });
  await log.save();

  station.baseReadings = normalizedReadings;
  await station.save();
  await ShiftEntry.recomputeFrom(station.id, '0000-00-00');

  return log;
}

async function deleteOpeningReadingLog({
  stationId,
  logId,
  deletedBy = '',
  deletedByName = '',
}) {
  const log = await PumpOpeningReadingLog.findById(logId);
  if (!log || log.stationId !== stationId) {
    return null;
  }
  if (!isDeleted(log)) {
    log.deletedAt = nowIso();
    log.deletedBy = String(deletedBy || '').trim();
    log.deletedByName = String(deletedByName || '').trim();
    await log.save();
  }

  const station = await Station.findById(stationId);
  if (station?.id) {
    const activeLogs = (await loadRetainedLogsForStation(stationId)).filter(
      (item) => !isDeleted(item),
    );
    const latestActive = activeLogs.at(-1) || null;
    station.baseReadings = latestActive?.readings || {};
    await station.save();
    await ShiftEntry.recomputeFrom(station.id, '0000-00-00');
  }

  return log;
}

module.exports = {
  createOpeningReadingLog,
  deleteOpeningReadingLog,
  ensureOpeningReadingLogsForStation,
  listOpeningReadingLogsForStation,
};
