const InventoryLedgerEntry = require('../models/InventoryLedgerEntry');
const DeliveryReceipt = require('../models/DeliveryReceipt');
const ShiftEntry = require('../models/ShiftEntry');
const Station = require('../models/Station');
const StationDaySetup = require('../models/StationDaySetup');
const {getFirestore} = require('../config/firebase');

const COLLECTION_NAME = 'inventoryLedgerEntries';

function roundNumber(value) {
  return Math.round((Number(value || 0) + Number.EPSILON) * 100) / 100;
}

function normalizeQuantities(value = {}) {
  return {
    petrol: roundNumber(value.petrol),
    diesel: roundNumber(value.diesel),
    two_t_oil: roundNumber(value.two_t_oil),
  };
}

function hasAnyQuantity(value = {}) {
  return ['petrol', 'diesel', 'two_t_oil'].some((fuelKey) => Number(value?.[fuelKey] || 0) !== 0);
}

function normalizeInventoryEntries(entries = []) {
  const latestByDate = new Map();
  for (const entry of entries) {
    if (!ShiftEntry.isFinalized(entry)) {
      continue;
    }
    const existing = latestByDate.get(entry.date);
    if (!existing) {
      latestByDate.set(entry.date, entry);
      continue;
    }
    const nextTimestamp = ShiftEntry.latestActivityTimestamp(entry);
    const existingTimestamp = ShiftEntry.latestActivityTimestamp(existing);
    if (
      nextTimestamp > existingTimestamp ||
      (nextTimestamp === existingTimestamp && String(entry.id || '') > String(existing.id || ''))
    ) {
      latestByDate.set(entry.date, entry);
    }
  }
  return [...latestByDate.values()].sort((left, right) =>
    String(left.date || '').localeCompare(String(right.date || '')),
  );
}

function signedSaleDelta(entry) {
  const inventoryTotals = entry?.inventoryTotals || {};
  return normalizeQuantities({
    petrol: -Number(inventoryTotals.petrol || 0),
    diesel: -Number(inventoryTotals.diesel || 0),
    two_t_oil: -Number(inventoryTotals.twoT || 0),
  });
}

function receiptDelta(receipt) {
  return normalizeQuantities(receipt?.quantities || {});
}

function applyDelta(balance, delta) {
  return normalizeQuantities({
    petrol: Number(balance.petrol || 0) + Number(delta.petrol || 0),
    diesel: Number(balance.diesel || 0) + Number(delta.diesel || 0),
    two_t_oil: Number(balance.two_t_oil || 0) + Number(delta.two_t_oil || 0),
  });
}

function resetDelta(balance, nextBalance) {
  return normalizeQuantities({
    petrol: Number(nextBalance.petrol || 0) - Number(balance.petrol || 0),
    diesel: Number(nextBalance.diesel || 0) - Number(balance.diesel || 0),
    two_t_oil: Number(nextBalance.two_t_oil || 0) - Number(balance.two_t_oil || 0),
  });
}

function eventTypeOrder(type) {
  switch (type) {
    case 'snapshot':
      return 0;
    case 'delivery':
      return 1;
    case 'sale':
      return 2;
    default:
      return 3;
  }
}

function compareEvents(left, right) {
  return (
    String(left.date || '').localeCompare(String(right.date || '')) ||
    eventTypeOrder(left.type) - eventTypeOrder(right.type) ||
    String(left.eventAt || '').localeCompare(String(right.eventAt || '')) ||
    String(left.sourceId || '').localeCompare(String(right.sourceId || ''))
  );
}

async function buildInventoryLedgerEntries(stationId) {
  const station = await Station.findById(stationId);
  if (!station) {
    return [];
  }

  const [setups, entries, receipts] = await Promise.all([
    StationDaySetup.listForStation(stationId),
    ShiftEntry.allForStation(stationId),
    DeliveryReceipt.allForStation(stationId),
  ]);

  const normalizedEntries = normalizeInventoryEntries(entries);

  const events = [];
  for (const snapshot of setups) {
    events.push({
      id: InventoryLedgerEntry.buildId({
        stationId,
        type: 'snapshot',
        sourceId: snapshot.id,
        date: snapshot.effectiveDate,
      }),
      stationId,
      date: snapshot.effectiveDate,
      type: 'snapshot',
      sourceId: snapshot.id,
      sourceType: 'station-day-setup',
      eventAt: snapshot.createdAt || '',
      nextBalance: normalizeQuantities(snapshot.startingStock),
      note: snapshot.note || 'Day setup stock baseline',
      meta: {
        effectiveDate: snapshot.effectiveDate || '',
        createdBy: snapshot.createdBy || '',
        createdByName: snapshot.createdByName || '',
      },
    });
  }

  for (const receipt of receipts) {
    events.push({
      id: InventoryLedgerEntry.buildId({
        stationId,
        type: 'delivery',
        sourceId: receipt.id,
        date: receipt.date,
      }),
      stationId,
      date: receipt.date,
      type: 'delivery',
      sourceId: receipt.id,
      sourceType: 'delivery-receipt',
      eventAt: receipt.createdAt || '',
      delta: receiptDelta(receipt),
      note: receipt.note || '',
      meta: {
        purchasedByName: receipt.purchasedByName || '',
      },
    });
  }

  for (const entry of normalizedEntries) {
    events.push({
      id: InventoryLedgerEntry.buildId({
        stationId,
        type: 'sale',
        sourceId: entry.id,
        date: entry.date,
      }),
      stationId,
      date: entry.date,
      type: 'sale',
      sourceId: entry.id,
      sourceType: 'shift-entry',
      eventAt: ShiftEntry.latestActivityTimestamp(entry),
      delta: signedSaleDelta(entry),
      note: entry.varianceNote || '',
      meta: {
        approvedAt: entry.approvedAt || '',
        status: entry.status || '',
      },
    });
  }

  events.sort(compareEvents);

  let runningBalance = {petrol: 0, diesel: 0, two_t_oil: 0};
  const finalizedEntries = [];

  for (const event of events) {
    if (event.type === 'snapshot') {
      const nextBalance = normalizeQuantities(event.nextBalance);
      const delta = resetDelta(runningBalance, nextBalance);
      runningBalance = nextBalance;
      finalizedEntries.push(
        new InventoryLedgerEntry({
          ...event,
          delta,
          balanceAfter: runningBalance,
        }),
      );
      continue;
    }
    runningBalance = applyDelta(runningBalance, event.delta);
    finalizedEntries.push(
      new InventoryLedgerEntry({
        ...event,
        balanceAfter: runningBalance,
      }),
    );
  }

  return finalizedEntries;
}

async function syncInventoryLedgerForStation(stationId) {
  if (!stationId) {
    return {stationId: '', synced: 0, deleted: 0};
  }

  const entries = await buildInventoryLedgerEntries(stationId);
  const collection = getFirestore().collection(COLLECTION_NAME);
  const existingSnapshot = await collection.where('sid', '==', stationId).get();
  const existingIds = new Set(existingSnapshot.docs.map((doc) => String(doc.data()?.id || doc.id || '')));
  const nextIds = new Set(entries.map((entry) => entry.id));

  const writes = [];
  for (const doc of existingSnapshot.docs) {
    const storedId = String(doc.data()?.id || doc.id || '');
    if (!nextIds.has(storedId)) {
      writes.push({type: 'delete', ref: doc.ref});
    }
  }

  for (const entry of entries) {
    writes.push({
      type: 'set',
      ref: collection.doc(entry.id),
      data: {
        ...entry.toRecordPayload(),
        displayName: `${entry.date} ${entry.type} inventory ledger`,
      },
    });
  }

  while (writes.length > 0) {
    const batch = getFirestore().batch();
    const chunk = writes.splice(0, 400);
    for (const item of chunk) {
      if (item.type === 'delete') {
        batch.delete(item.ref);
      } else {
        batch.set(item.ref, item.data, {merge: true});
      }
    }
    await batch.commit();
  }

  InventoryLedgerEntry.invalidateStationCache(stationId);

  return {
    stationId,
    synced: entries.length,
    deleted: [...existingIds].filter((id) => !nextIds.has(id)).length,
  };
}

async function listInventoryLedger(stationId, {fromDate = '', toDate = ''} = {}) {
  return InventoryLedgerEntry.allForStationRange(stationId, {fromDate, toDate});
}

module.exports = {
  buildInventoryLedgerEntries,
  listInventoryLedger,
  syncInventoryLedgerForStation,
};
