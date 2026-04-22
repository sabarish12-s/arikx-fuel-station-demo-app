const {
  claimsFor,
  getDataRecord,
  listDataRecords,
  upsertDataRecord,
} = require('../utils/authStore');
const {getFirestore} = require('../config/firebase');
const {nowIso} = require('../utils/time');

const ENTITY_TYPE = 'deliveryReceipt';
const COLLECTION_NAME = 'deliveryReceipts';
const STATION_CACHE_TTL_MS = 15000;
const stationReceiptsCache = new Map();

function roundNumber(value) {
  return Math.round((Number(value || 0) + Number.EPSILON) * 100) / 100;
}

function normalizeFuelTypeId(value) {
  const normalized = String(value || '').trim().toLowerCase();
  if (['petrol', 'diesel', 'two_t_oil'].includes(normalized)) {
    return normalized;
  }
  throw new Error('Valid fuel type is required.');
}

function normalizeQuantities(value = {}) {
  return {
    petrol: roundNumber(value.petrol),
    diesel: roundNumber(value.diesel),
    two_t_oil: roundNumber(value.two_t_oil),
  };
}

function quantitiesFromLegacy({fuelTypeId, quantity}) {
  const normalizedFuelTypeId = normalizeFuelTypeId(fuelTypeId);
  return normalizeQuantities({
    [normalizedFuelTypeId]: quantity,
  });
}

function primaryFuelTypeFromQuantities(quantities) {
  for (const fuelTypeId of ['petrol', 'diesel', 'two_t_oil']) {
    if (Number(quantities?.[fuelTypeId] || 0) > 0) {
      return fuelTypeId;
    }
  }
  return 'petrol';
}

function totalQuantityFromQuantities(quantities) {
  return roundNumber(
    Number(quantities?.petrol || 0) +
      Number(quantities?.diesel || 0) +
      Number(quantities?.two_t_oil || 0),
  );
}

function cloneReceipts(receipts = []) {
  return receipts.map((receipt) => new DeliveryReceipt(receipt.toJson()));
}

function stationRangeCacheKey(stationId, fromDate = '', toDate = '') {
  return `${stationId}:${fromDate || ''}:${toDate || ''}`;
}

class DeliveryReceipt {
  constructor({
    id,
    stationId,
    fuelTypeId,
    date,
    quantity,
    quantities,
    note = '',
    purchasedByName = '',
    createdBy = '',
    createdAt = null,
  }) {
    const normalizedQuantities =
      quantities && typeof quantities === 'object'
        ? normalizeQuantities(quantities)
        : quantitiesFromLegacy({fuelTypeId, quantity});
    this.id = id;
    this.stationId = stationId;
    this.quantities = normalizedQuantities;
    this.fuelTypeId = primaryFuelTypeFromQuantities(normalizedQuantities);
    this.date = String(date || '').trim();
    this.quantity = totalQuantityFromQuantities(normalizedQuantities);
    this.note = String(note || '').trim();
    this.purchasedByName = String(purchasedByName || '').trim();
    this.createdBy = String(createdBy || '').trim();
    this.createdAt = createdAt || nowIso();
  }

  static fromRecord(record) {
    if (!record) {
      return null;
    }
    const claims = claimsFor(record);
    return new DeliveryReceipt({
      id: claims.id || claims.ek || '',
      stationId: claims.sid || '',
      fuelTypeId: claims.ft || '',
      date: claims.dt || '',
      quantity: claims.qty || 0,
      quantities: claims.qs || null,
      note: claims.nt || '',
      purchasedByName: claims.pbn || '',
      createdBy: claims.cb || '',
      createdAt: claims.ca || '',
    });
  }

  static fromStoredDocument(snapshot) {
    if (!snapshot?.exists) {
      return null;
    }
    const data = snapshot.data() || {};
    return new DeliveryReceipt({
      id: data.id || data.ek || snapshot.id || '',
      stationId: data.sid || '',
      fuelTypeId: data.ft || '',
      date: data.dt || '',
      quantity: data.qty || 0,
      quantities: data.qs || null,
      note: data.nt || '',
      purchasedByName: data.pbn || '',
      createdBy: data.cb || '',
      createdAt: data.ca || '',
    });
  }

  toRecordPayload() {
    return {
      id: this.id,
      sid: this.stationId,
      ft: this.fuelTypeId,
      dt: this.date,
      qty: this.quantity,
      qs: this.quantities,
      nt: this.note,
      pbn: this.purchasedByName,
      cb: this.createdBy,
      ca: this.createdAt,
    };
  }

  async save() {
    await upsertDataRecord({
      entityType: ENTITY_TYPE,
      entityKey: this.id,
      displayName: `${this.date} ${this.fuelTypeId} delivery`,
      payload: this.toRecordPayload(),
    });
    DeliveryReceipt.invalidateStationCache(this.stationId);
    return this;
  }

  static async create({
    stationId,
    fuelTypeId,
    date,
    quantity,
    quantities,
    note,
    purchasedByName,
    createdBy,
  }) {
    if (!stationId) {
      throw new Error('Station is required.');
    }
    if (!date) {
      throw new Error('Delivery date is required.');
    }
    const normalizedQuantities =
      quantities && typeof quantities === 'object'
        ? normalizeQuantities(quantities)
        : quantitiesFromLegacy({fuelTypeId, quantity});
    if (totalQuantityFromQuantities(normalizedQuantities) <= 0) {
      throw new Error('At least one delivery quantity must be greater than zero.');
    }
    if (!String(purchasedByName || '').trim()) {
      throw new Error('Purchased by name is required.');
    }
    const receipt = new DeliveryReceipt({
      id: `${stationId}:${Date.now()}:${Math.random().toString(36).slice(2, 8)}`,
      stationId,
      fuelTypeId,
      date,
      quantity,
      quantities: normalizedQuantities,
      note,
      purchasedByName,
      createdBy,
      createdAt: nowIso(),
    });
    await receipt.save();
    return receipt;
  }

  static async findById(id) {
    return DeliveryReceipt.fromRecord(await getDataRecord(ENTITY_TYPE, id));
  }

  static async allForStation(stationId) {
    if (!stationId) {
      return [];
    }

    const cacheKey = stationRangeCacheKey(stationId);
    const cached = stationReceiptsCache.get(cacheKey);
    if (cached && cached.expiresAt > Date.now()) {
      return cloneReceipts(cached.receipts);
    }

    try {
      const snapshot = await getFirestore()
        .collection(COLLECTION_NAME)
        .where('sid', '==', stationId)
        .get();
      const directReceipts = snapshot.docs
        .map((doc) => DeliveryReceipt.fromStoredDocument(doc))
        .filter(Boolean)
        .sort((a, b) => String(b.createdAt).localeCompare(String(a.createdAt)));
      stationReceiptsCache.set(cacheKey, {
        expiresAt: Date.now() + STATION_CACHE_TTL_MS,
        receipts: cloneReceipts(directReceipts),
      });
      return cloneReceipts(directReceipts);
    } catch (error) {
      console.warn('DeliveryReceipt station query fallback:', error.message);
    }

    const fallbackReceipts = (await listDataRecords(ENTITY_TYPE))
      .map((record) => DeliveryReceipt.fromRecord(record))
      .filter(Boolean)
      .filter((receipt) => receipt.stationId === stationId)
      .sort((a, b) => String(b.createdAt).localeCompare(String(a.createdAt)));
    stationReceiptsCache.set(cacheKey, {
      expiresAt: Date.now() + STATION_CACHE_TTL_MS,
      receipts: cloneReceipts(fallbackReceipts),
    });
    return cloneReceipts(fallbackReceipts);
  }

  static async allForStationRange(stationId, {fromDate = '', toDate = ''} = {}) {
    if (!stationId) {
      return [];
    }

    const normalizedFromDate = String(fromDate || '').trim();
    const normalizedToDate = String(toDate || '').trim();
    const cacheKey = stationRangeCacheKey(stationId, normalizedFromDate, normalizedToDate);
    const cached = stationReceiptsCache.get(cacheKey);
    if (cached && cached.expiresAt > Date.now()) {
      return cloneReceipts(cached.receipts);
    }

    try {
      let query = getFirestore().collection(COLLECTION_NAME).where('sid', '==', stationId);
      if (normalizedFromDate) {
        query = query.where('dt', '>=', normalizedFromDate);
      }
      if (normalizedToDate) {
        query = query.where('dt', '<=', normalizedToDate);
      }
      const snapshot = await query.get();
      const directReceipts = snapshot.docs
        .map((doc) => DeliveryReceipt.fromStoredDocument(doc))
        .filter(Boolean)
        .filter((receipt) => {
          if (normalizedFromDate && String(receipt.date || '') < normalizedFromDate) {
            return false;
          }
          if (normalizedToDate && String(receipt.date || '') > normalizedToDate) {
            return false;
          }
          return true;
        })
        .sort((a, b) => String(b.createdAt).localeCompare(String(a.createdAt)));
      stationReceiptsCache.set(cacheKey, {
        expiresAt: Date.now() + STATION_CACHE_TTL_MS,
        receipts: cloneReceipts(directReceipts),
      });
      return cloneReceipts(directReceipts);
    } catch (error) {
      console.warn('DeliveryReceipt range query fallback:', error.message);
    }

    const fallbackReceipts = (await listDataRecords(ENTITY_TYPE))
      .map((record) => DeliveryReceipt.fromRecord(record))
      .filter(Boolean)
      .filter((receipt) => {
        if (receipt.stationId !== stationId) {
          return false;
        }
        if (normalizedFromDate && String(receipt.date || '') < normalizedFromDate) {
          return false;
        }
        if (normalizedToDate && String(receipt.date || '') > normalizedToDate) {
          return false;
        }
        return true;
      })
      .sort((a, b) => String(b.createdAt).localeCompare(String(a.createdAt)));
    stationReceiptsCache.set(cacheKey, {
      expiresAt: Date.now() + STATION_CACHE_TTL_MS,
      receipts: cloneReceipts(fallbackReceipts),
    });
    return cloneReceipts(fallbackReceipts);
  }

  static invalidateStationCache(stationId) {
    if (!stationId) {
      return;
    }
    for (const key of stationReceiptsCache.keys()) {
      if (key.startsWith(`${stationId}:`)) {
        stationReceiptsCache.delete(key);
      }
    }
  }

  toJson() {
    return {
      id: this.id,
      stationId: this.stationId,
      fuelTypeId: this.fuelTypeId,
      date: this.date,
      quantity: this.quantity,
      quantities: this.quantities,
      note: this.note,
      purchasedByName: this.purchasedByName,
      createdBy: this.createdBy,
      createdAt: this.createdAt,
    };
  }

  toSummaryJson() {
    return {
      date: this.date,
      quantity: this.quantity,
      quantities: this.quantities,
      note: this.note,
      purchasedByName: this.purchasedByName,
    };
  }
}

module.exports = DeliveryReceipt;
