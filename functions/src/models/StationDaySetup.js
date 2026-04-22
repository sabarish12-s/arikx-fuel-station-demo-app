const {
  claimsFor,
  deleteDataRecord,
  getDataRecord,
  listDataRecords,
  upsertDataRecord,
} = require('../utils/authStore');
const {admin, getFirestore} = require('../config/firebase');
const {nowIso} = require('../utils/time');

const ENTITY_TYPE = 'stationDaySetup';
const COLLECTION_NAME = 'stationDaySetups';
const STATION_CACHE_TTL_MS = 15000;
const DELETED_HISTORY_RETENTION_DAYS = 30;
const stationSetupsCache = new Map();

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

function normalizeReadings(value = {}) {
  return Object.entries(value || {}).reduce((result, [pumpId, readings]) => {
    const normalizedPumpId = String(pumpId || '').trim();
    if (!normalizedPumpId) {
      return result;
    }
    result[normalizedPumpId] = {
      petrol: roundNumber(readings?.petrol),
      diesel: roundNumber(readings?.diesel),
      twoT: roundNumber(readings?.twoT),
    };
    return result;
  }, {});
}

function normalizeStock(value = {}) {
  return {
    petrol: roundNumber(value?.petrol),
    diesel: roundNumber(value?.diesel),
    two_t_oil: roundNumber(value?.two_t_oil),
  };
}

function normalizeFuelPrices(value = {}) {
  return Object.entries(value || {}).reduce((result, [fuelTypeId, prices]) => {
    const normalizedFuelTypeId = String(fuelTypeId || '').trim().toLowerCase();
    if (!normalizedFuelTypeId) {
      return result;
    }
    result[normalizedFuelTypeId] = {
      costPrice: roundNumber(prices?.costPrice),
      sellingPrice: roundNumber(prices?.sellingPrice),
    };
    return result;
  }, {});
}

function cloneSetups(setups = []) {
  return setups.map((setup) => new StationDaySetup(setup.toJson()));
}

class StationDaySetup {
  constructor({
    id,
    stationId,
    effectiveDate,
    openingReadings = {},
    startingStock = {},
    fuelPrices = {},
    note = '',
    createdAt = null,
    createdBy = '',
    createdByName = '',
    updatedAt = null,
    updatedBy = '',
    updatedByName = '',
    deletedAt = '',
    deletedBy = '',
    deletedByName = '',
    lockedAt = '',
    lockedBy = '',
    lockedByName = '',
  }) {
    this.id = String(id || '').trim() || '';
    this.stationId = String(stationId || '').trim();
    this.effectiveDate = normalizeDateKey(effectiveDate);
    this.openingReadings = normalizeReadings(openingReadings);
    this.startingStock = normalizeStock(startingStock);
    this.fuelPrices = normalizeFuelPrices(fuelPrices);
    this.note = String(note || '').trim();
    this.createdAt = String(createdAt || '').trim() || null;
    this.createdBy = String(createdBy || '').trim();
    this.createdByName = String(createdByName || '').trim();
    this.updatedAt = String(updatedAt || '').trim() || null;
    this.updatedBy = String(updatedBy || '').trim();
    this.updatedByName = String(updatedByName || '').trim();
    this.deletedAt = String(deletedAt || '').trim();
    this.deletedBy = String(deletedBy || '').trim();
    this.deletedByName = String(deletedByName || '').trim();
    this.lockedAt = String(lockedAt || '').trim();
    this.lockedBy = String(lockedBy || '').trim();
    this.lockedByName = String(lockedByName || '').trim();
  }

  get isDeleted() {
    return this.deletedAt.length > 0;
  }

  get isLocked() {
    return this.lockedAt.length > 0;
  }

  static idFor(stationId, effectiveDate) {
    return `${String(stationId || '').trim()}:${normalizeDateKey(effectiveDate)}`;
  }

  static fromRecord(record) {
    if (!record) {
      return null;
    }
    const claims = claimsFor(record);
    return new StationDaySetup({
      id: claims.id || claims.ek || '',
      stationId: claims.sid || '',
      effectiveDate: claims.dt || '',
      openingReadings: claims.or || {},
      startingStock: claims.ss || {},
      fuelPrices: claims.fp || {},
      note: claims.nt || '',
      createdAt: claims.ca || null,
      createdBy: claims.cb || '',
      createdByName: claims.cbn || '',
      updatedAt: claims.ua || null,
      updatedBy: claims.ub || '',
      updatedByName: claims.ubn || '',
      deletedAt: claims.da || '',
      deletedBy: claims.db || '',
      deletedByName: claims.dbn || '',
      lockedAt: claims.la || '',
      lockedBy: claims.lb || '',
      lockedByName: claims.lbn || '',
    });
  }

  static fromStoredDocument(snapshot) {
    if (!snapshot?.exists) {
      return null;
    }
    const data = snapshot.data() || {};
    return new StationDaySetup({
      id: data.id || data.ek || snapshot.id || '',
      stationId: data.sid || '',
      effectiveDate: data.dt || '',
      openingReadings: data.or || {},
      startingStock: data.ss || {},
      fuelPrices: data.fp || {},
      note: data.nt || '',
      createdAt: data.ca || data.createdAt || null,
      createdBy: data.cb || '',
      createdByName: data.cbn || '',
      updatedAt: data.ua || data.updatedAt || null,
      updatedBy: data.ub || '',
      updatedByName: data.ubn || '',
      deletedAt: data.da || '',
      deletedBy: data.db || '',
      deletedByName: data.dbn || '',
      lockedAt: data.la || '',
      lockedBy: data.lb || '',
      lockedByName: data.lbn || '',
    });
  }

  toRecordPayload() {
    return {
      id: this.id,
      sid: this.stationId,
      dt: this.effectiveDate,
      or: this.openingReadings,
      ss: this.startingStock,
      fp: this.fuelPrices,
      nt: this.note,
      ca: this.createdAt,
      cb: this.createdBy,
      cbn: this.createdByName,
      ua: this.updatedAt,
      ub: this.updatedBy,
      ubn: this.updatedByName,
      da: this.deletedAt,
      db: this.deletedBy,
      dbn: this.deletedByName,
      la: this.lockedAt,
      lb: this.lockedBy,
      lbn: this.lockedByName,
    };
  }

  toJson() {
    return {
      id: this.id,
      stationId: this.stationId,
      effectiveDate: this.effectiveDate,
      openingReadings: this.openingReadings,
      startingStock: this.startingStock,
      fuelPrices: this.fuelPrices,
      note: this.note,
      createdAt: this.createdAt,
      createdBy: this.createdBy,
      createdByName: this.createdByName,
      updatedAt: this.updatedAt,
      updatedBy: this.updatedBy,
      updatedByName: this.updatedByName,
      deletedAt: this.deletedAt,
      deletedBy: this.deletedBy,
      deletedByName: this.deletedByName,
      lockedAt: this.lockedAt,
      lockedBy: this.lockedBy,
      lockedByName: this.lockedByName,
    };
  }

  async save() {
    const timestamp = nowIso();
    if (!this.id) {
      this.id = StationDaySetup.idFor(this.stationId, this.effectiveDate);
    }
    if (!this.createdAt) {
      this.createdAt = timestamp;
    }
    this.updatedAt = timestamp;
    await upsertDataRecord({
      entityType: ENTITY_TYPE,
      entityKey: this.id,
      displayName: `${this.effectiveDate} Day Setup`,
      payload: this.toRecordPayload(),
    });
    StationDaySetup.invalidateStationCache(this.stationId);
    return this;
  }

  async deletePermanent() {
    await deleteDataRecord(ENTITY_TYPE, this.id);
    StationDaySetup.invalidateStationCache(this.stationId);
  }

  static async findById(id) {
    return StationDaySetup.fromRecord(await getDataRecord(ENTITY_TYPE, id));
  }

  static async findByDate(stationId, effectiveDate) {
    const normalizedDate = normalizeDateKey(effectiveDate);
    if (!stationId || !normalizedDate) {
      return null;
    }
    return StationDaySetup.findById(StationDaySetup.idFor(stationId, normalizedDate));
  }

  static invalidateStationCache(stationId) {
    if (!stationId) {
      return;
    }
    stationSetupsCache.delete(String(stationId));
  }

  static async allForStation(stationId, {forceRefresh = false} = {}) {
    const normalizedStationId = String(stationId || '').trim();
    if (!normalizedStationId) {
      return [];
    }

    const cached = stationSetupsCache.get(normalizedStationId);
    if (!forceRefresh && cached && cached.expiresAt > Date.now()) {
      return cloneSetups(cached.setups);
    }

    let setups = [];

    try {
      const documentId = admin.firestore.FieldPath.documentId();
      const snapshot = await getFirestore()
        .collection(COLLECTION_NAME)
        .where(documentId, '>=', `${normalizedStationId}:`)
        .where(documentId, '<=', `${normalizedStationId}:\uf8ff`)
        .get();
      setups = snapshot.docs
        .map((doc) => StationDaySetup.fromStoredDocument(doc))
        .filter(Boolean);
    } catch (error) {
      console.warn('StationDaySetup station query fallback:', error.message);
    }

    if (setups.length === 0) {
      setups = (await listDataRecords(ENTITY_TYPE))
        .map((record) => StationDaySetup.fromRecord(record))
        .filter(Boolean)
        .filter((setup) => setup.stationId === normalizedStationId);
    }

    setups.sort((left, right) => String(left.effectiveDate).localeCompare(String(right.effectiveDate)));
    stationSetupsCache.set(normalizedStationId, {
      expiresAt: Date.now() + STATION_CACHE_TTL_MS,
      setups: cloneSetups(setups),
    });
    return cloneSetups(setups);
  }

  static async listForStation(
    stationId,
    {fromDate = '', toDate = '', deletedOnly = false, forceRefresh = false} = {},
  ) {
    const setups = await StationDaySetup.allForStation(stationId, {forceRefresh});
    return setups.filter((setup) => {
      if (deletedOnly && !setup.isDeleted) {
        return false;
      }
      if (!deletedOnly && setup.isDeleted) {
        return false;
      }
      if (fromDate && String(setup.effectiveDate) < String(fromDate)) {
        return false;
      }
      if (toDate && String(setup.effectiveDate) > String(toDate)) {
        return false;
      }
      return true;
    });
  }

  static async earliestActiveForStation(stationId) {
    const setups = await StationDaySetup.listForStation(stationId);
    return setups[0] || null;
  }

  static async latestActiveOnOrBefore(stationId, effectiveDate) {
    const normalizedDate = normalizeDateKey(effectiveDate);
    if (!normalizedDate) {
      return null;
    }
    const setups = await StationDaySetup.listForStation(stationId);
    return setups
      .filter((setup) => String(setup.effectiveDate).localeCompare(normalizedDate) <= 0)
      .at(-1) || null;
  }

  static async purgeExpiredDeletedHistory() {
    const cutoffIso = new Date(
      Date.now() - DELETED_HISTORY_RETENTION_DAYS * 24 * 60 * 60 * 1000,
    ).toISOString();
    const setups = (await listDataRecords(ENTITY_TYPE))
      .map((record) => StationDaySetup.fromRecord(record))
      .filter(Boolean);
    let purged = 0;
    for (const setup of setups) {
      if (String(setup.deletedAt || '').trim() && String(setup.deletedAt).localeCompare(cutoffIso) < 0) {
        await deleteDataRecord(ENTITY_TYPE, setup.id);
        StationDaySetup.invalidateStationCache(setup.stationId);
        purged += 1;
      }
    }
    return purged;
  }
}

module.exports = StationDaySetup;
