const {
  claimsFor,
  getDataRecord,
  listDataRecords,
  upsertDataRecord,
} = require('../utils/authStore');
const {getFirestore} = require('../config/firebase');

const ENTITY_TYPE = 'inventoryLedgerEntry';
const COLLECTION_NAME = 'inventoryLedgerEntries';
const STATION_CACHE_TTL_MS = 60000;
const stationLedgerCache = new Map();
const stationLedgerRangeCache = new Map();

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

function normalizeType(value) {
  const normalized = String(value || '').trim().toLowerCase();
  if (['baseline', 'snapshot', 'delivery', 'sale', 'adjustment'].includes(normalized)) {
    return normalized;
  }
  throw new Error('Valid ledger type is required.');
}

function compareLedgerEntries(left, right) {
  return (
    String(left.date || '').localeCompare(String(right.date || '')) ||
    String(left.eventAt || '').localeCompare(String(right.eventAt || '')) ||
    String(left.type || '').localeCompare(String(right.type || '')) ||
    String(left.id || '').localeCompare(String(right.id || ''))
  );
}

function cloneEntries(entries = []) {
  return entries.map((entry) => new InventoryLedgerEntry(entry.toJson()));
}

function stationRangeCacheKey(stationId, fromDate = '', toDate = '') {
  return `${stationId}:${fromDate || ''}:${toDate || ''}`;
}

class InventoryLedgerEntry {
  constructor({
    id,
    stationId,
    date,
    type,
    sourceId = '',
    sourceType = '',
    eventAt = '',
    delta = {},
    balanceAfter = {},
    note = '',
    meta = {},
  }) {
    this.id = String(id || '').trim();
    this.stationId = String(stationId || '').trim();
    this.date = String(date || '').trim();
    this.type = normalizeType(type);
    this.sourceId = String(sourceId || '').trim();
    this.sourceType = String(sourceType || '').trim();
    this.eventAt = String(eventAt || '').trim();
    this.delta = normalizeQuantities(delta);
    this.balanceAfter = normalizeQuantities(balanceAfter);
    this.note = String(note || '').trim();
    this.meta = meta && typeof meta === 'object' && !Array.isArray(meta) ? meta : {};
  }

  static buildId({stationId, type, sourceId, date}) {
    return `${stationId}:${type}:${sourceId || date}`;
  }

  static fromRecord(record) {
    if (!record) {
      return null;
    }
    const claims = claimsFor(record);
    return new InventoryLedgerEntry({
      id: claims.id || claims.ek || '',
      stationId: claims.sid || '',
      date: claims.dt || '',
      type: claims.tp || 'adjustment',
      sourceId: claims.si || '',
      sourceType: claims.stp || '',
      eventAt: claims.ea || '',
      delta: claims.dg || {},
      balanceAfter: claims.ba || {},
      note: claims.nt || '',
      meta: claims.mt || {},
    });
  }

  static fromStoredDocument(snapshot) {
    if (!snapshot?.exists) {
      return null;
    }
    const data = snapshot.data() || {};
    return new InventoryLedgerEntry({
      id: data.id || data.ek || snapshot.id || '',
      stationId: data.sid || '',
      date: data.dt || '',
      type: data.tp || 'adjustment',
      sourceId: data.si || '',
      sourceType: data.stp || '',
      eventAt: data.ea || '',
      delta: data.dg || {},
      balanceAfter: data.ba || {},
      note: data.nt || '',
      meta: data.mt || {},
    });
  }

  toRecordPayload() {
    return {
      id: this.id,
      sid: this.stationId,
      dt: this.date,
      tp: this.type,
      si: this.sourceId,
      stp: this.sourceType,
      ea: this.eventAt,
      dg: this.delta,
      ba: this.balanceAfter,
      nt: this.note,
      mt: this.meta,
    };
  }

  async save() {
    await upsertDataRecord({
      entityType: ENTITY_TYPE,
      entityKey: this.id,
      displayName: `${this.date} ${this.type} inventory ledger`,
      payload: this.toRecordPayload(),
    });
    InventoryLedgerEntry.invalidateStationCache(this.stationId);
    return this;
  }

  static async findById(id) {
    return InventoryLedgerEntry.fromRecord(await getDataRecord(ENTITY_TYPE, id));
  }

  static async allForStation(stationId) {
    const normalizedStationId = String(stationId || '').trim();
    if (!normalizedStationId) {
      return [];
    }

    const cacheKey = stationRangeCacheKey(normalizedStationId);
    const cached = stationLedgerCache.get(cacheKey);
    if (cached && cached.expiresAt > Date.now()) {
      return cloneEntries(cached.entries);
    }

    try {
      const snapshot = await getFirestore()
        .collection(COLLECTION_NAME)
        .where('sid', '==', normalizedStationId)
        .get();
      const directEntries = snapshot.docs
        .map((doc) => InventoryLedgerEntry.fromStoredDocument(doc))
        .filter(Boolean)
        .sort(compareLedgerEntries);
      stationLedgerCache.set(cacheKey, {
        expiresAt: Date.now() + STATION_CACHE_TTL_MS,
        entries: cloneEntries(directEntries),
      });
      return cloneEntries(directEntries);
    } catch (error) {
      console.warn('InventoryLedgerEntry station query fallback:', error.message);
    }

    const fallbackEntries = (await listDataRecords(ENTITY_TYPE))
      .map((record) => InventoryLedgerEntry.fromRecord(record))
      .filter(Boolean)
      .filter((entry) => entry.stationId === normalizedStationId)
      .sort(compareLedgerEntries);
    stationLedgerCache.set(cacheKey, {
      expiresAt: Date.now() + STATION_CACHE_TTL_MS,
      entries: cloneEntries(fallbackEntries),
    });
    return cloneEntries(fallbackEntries);
  }

  static async allForStationRange(stationId, {fromDate = '', toDate = ''} = {}) {
    const normalizedStationId = String(stationId || '').trim();
    if (!normalizedStationId) {
      return [];
    }

    const normalizedFromDate = String(fromDate || '').trim();
    const normalizedToDate = String(toDate || '').trim();
    const cacheKey = stationRangeCacheKey(
      normalizedStationId,
      normalizedFromDate,
      normalizedToDate,
    );
    const cached = stationLedgerRangeCache.get(cacheKey);
    if (cached && cached.expiresAt > Date.now()) {
      return cloneEntries(cached.entries);
    }

    try {
      let query = getFirestore()
        .collection(COLLECTION_NAME)
        .where('sid', '==', normalizedStationId);
      if (normalizedFromDate) {
        query = query.where('dt', '>=', normalizedFromDate);
      }
      if (normalizedToDate) {
        query = query.where('dt', '<=', normalizedToDate);
      }
      const snapshot = await query.get();
      const directEntries = snapshot.docs
        .map((doc) => InventoryLedgerEntry.fromStoredDocument(doc))
        .filter(Boolean)
        .filter((entry) => {
          if (normalizedFromDate && String(entry.date || '') < normalizedFromDate) {
            return false;
          }
          if (normalizedToDate && String(entry.date || '') > normalizedToDate) {
            return false;
          }
          return true;
        })
        .sort(compareLedgerEntries);
      stationLedgerRangeCache.set(cacheKey, {
        expiresAt: Date.now() + STATION_CACHE_TTL_MS,
        entries: cloneEntries(directEntries),
      });
      return cloneEntries(directEntries);
    } catch (error) {
      console.warn('InventoryLedgerEntry range query fallback:', error.message);
    }

    const fallbackEntries = (await listDataRecords(ENTITY_TYPE))
      .map((record) => InventoryLedgerEntry.fromRecord(record))
      .filter(Boolean)
      .filter((entry) => {
        if (entry.stationId !== normalizedStationId) {
          return false;
        }
        if (normalizedFromDate && String(entry.date || '') < normalizedFromDate) {
          return false;
        }
        if (normalizedToDate && String(entry.date || '') > normalizedToDate) {
          return false;
        }
        return true;
      })
      .sort(compareLedgerEntries);
    stationLedgerRangeCache.set(cacheKey, {
      expiresAt: Date.now() + STATION_CACHE_TTL_MS,
      entries: cloneEntries(fallbackEntries),
    });
    return cloneEntries(fallbackEntries);
  }

  static invalidateStationCache(stationId) {
    const normalizedStationId = String(stationId || '').trim();
    if (!normalizedStationId) {
      return;
    }
    for (const key of stationLedgerCache.keys()) {
      if (key.startsWith(`${normalizedStationId}:`)) {
        stationLedgerCache.delete(key);
      }
    }
    for (const key of stationLedgerRangeCache.keys()) {
      if (key.startsWith(`${normalizedStationId}:`)) {
        stationLedgerRangeCache.delete(key);
      }
    }
  }

  toJson() {
    return {
      id: this.id,
      stationId: this.stationId,
      date: this.date,
      type: this.type,
      sourceId: this.sourceId,
      sourceType: this.sourceType,
      eventAt: this.eventAt,
      delta: this.delta,
      balanceAfter: this.balanceAfter,
      note: this.note,
      meta: this.meta,
    };
  }
}

module.exports = InventoryLedgerEntry;
