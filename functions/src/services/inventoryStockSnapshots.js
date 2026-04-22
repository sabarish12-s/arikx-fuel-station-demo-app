const Station = require('../models/Station');
const {
  InventoryStockSnapshot,
  compareSnapshots,
  normalizeStock,
} = require('../models/InventoryStockSnapshot');
const {nowIso, todayInStationTimeZone} = require('../utils/time');

const DELETED_HISTORY_RETENTION_DAYS = 30;

function deletedCutoffIso() {
  return new Date(
    Date.now() - DELETED_HISTORY_RETENTION_DAYS * 24 * 60 * 60 * 1000,
  ).toISOString();
}

function isDeleted(snapshot) {
  return String(snapshot?.deletedAt || '').trim().length > 0;
}

function isExpiredDeleted(snapshot, cutoffIso = deletedCutoffIso()) {
  const deletedAt = String(snapshot?.deletedAt || '').trim();
  return deletedAt.length > 0 && deletedAt.localeCompare(cutoffIso) < 0;
}

async function loadRetainedSnapshotsForStation(stationId) {
  const snapshots = await InventoryStockSnapshot.allForStation(stationId);
  const cutoffIso = deletedCutoffIso();
  const retained = [];
  for (const snapshot of snapshots) {
    if (isExpiredDeleted(snapshot, cutoffIso)) {
      await InventoryStockSnapshot.deleteById(snapshot.id);
      continue;
    }
    retained.push(snapshot);
  }
  return retained;
}

function latestSnapshotForDate(snapshots = [], targetDate = todayInStationTimeZone()) {
  const applicable = snapshots.filter(
    (snapshot) =>
      !isDeleted(snapshot) &&
      String(snapshot.effectiveDate || '').localeCompare(String(targetDate || '')) <= 0,
  );
  if (applicable.length === 0) {
    return null;
  }
  return [...applicable].sort(compareSnapshots).at(-1) || null;
}

function latestSnapshotBeforeDate(snapshots = [], targetDate = todayInStationTimeZone()) {
  const applicable = snapshots.filter(
    (snapshot) =>
      !isDeleted(snapshot) &&
      String(snapshot.effectiveDate || '').localeCompare(String(targetDate || '')) < 0,
  );
  if (applicable.length === 0) {
    return null;
  }
  return [...applicable].sort(compareSnapshots).at(-1) || null;
}

function snapshotStock(snapshot) {
  return normalizeStock(snapshot?.stock || {});
}

async function seedInitialSnapshotForStation(station) {
  if (!station?.id) {
    return null;
  }
  const inventoryPlanning = station.inventoryPlanning || {};
  const createdAt = String(inventoryPlanning.updatedAt || '').trim() || nowIso();
  const snapshot = new InventoryStockSnapshot({
    id: `${station.id}:${createdAt}:seed`,
    stationId: station.id,
    effectiveDate: createdAt.slice(0, 10) || todayInStationTimeZone(),
    stock: inventoryPlanning.openingStock || inventoryPlanning.currentStock || {},
    note: '',
    createdAt,
    createdBy: 'system',
    createdByName: 'System',
  });
  await snapshot.save();
  return snapshot;
}

async function ensureStockSnapshotsForStation(stationId, existingStation = null) {
  const station = existingStation || (await Station.findById(stationId));
  if (!station?.id) {
    return [];
  }
  const existing = (await loadRetainedSnapshotsForStation(station.id)).filter(
    (snapshot) => !isDeleted(snapshot),
  );
  if (existing.length > 0) {
    return existing;
  }
  const seeded = await seedInitialSnapshotForStation(station);
  return seeded ? [seeded] : [];
}

async function listStockSnapshotsForStation(
  stationId,
  {fromDate = '', toDate = '', deletedOnly = false} = {},
) {
  const snapshots = deletedOnly
    ? (await loadRetainedSnapshotsForStation(stationId)).filter(isDeleted)
    : await ensureStockSnapshotsForStation(stationId);
  return snapshots.filter((snapshot) => {
    if (fromDate && String(snapshot.effectiveDate || '') < String(fromDate || '')) {
      return false;
    }
    if (toDate && String(snapshot.effectiveDate || '') > String(toDate || '')) {
      return false;
    }
    return true;
  });
}

async function createStockSnapshot({
  stationId,
  effectiveDate,
  stock,
  note = '',
  createdBy = '',
  createdByName = '',
}) {
  await ensureStockSnapshotsForStation(stationId);
  const createdAt = nowIso();
  const snapshot = new InventoryStockSnapshot({
    id: `${stationId}:${effectiveDate}:${createdAt}:${Math.random().toString(36).slice(2, 8)}`,
    stationId,
    effectiveDate,
    stock,
    note,
    createdAt,
    createdBy,
    createdByName,
  });
  await snapshot.save();
  return snapshot;
}

async function deleteStockSnapshot({
  stationId,
  snapshotId,
  deletedBy = '',
  deletedByName = '',
}) {
  const snapshot = await InventoryStockSnapshot.findById(snapshotId);
  if (!snapshot || snapshot.stationId !== stationId) {
    return null;
  }
  if (!isDeleted(snapshot)) {
    snapshot.deletedAt = nowIso();
    snapshot.deletedBy = String(deletedBy || '').trim();
    snapshot.deletedByName = String(deletedByName || '').trim();
    await snapshot.save();
  }
  return snapshot;
}

module.exports = {
  createStockSnapshot,
  deleteStockSnapshot,
  ensureStockSnapshotsForStation,
  latestSnapshotBeforeDate,
  latestSnapshotForDate,
  listStockSnapshotsForStation,
  snapshotStock,
};
