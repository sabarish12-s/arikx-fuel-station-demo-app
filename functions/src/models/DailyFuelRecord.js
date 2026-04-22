const {
  claimsFor,
  getDataRecord,
  listDataRecords,
  upsertDataRecord,
} = require('../utils/authStore');
const {getFirestore} = require('../config/firebase');
const {nowIso} = require('../utils/time');

const ENTITY_TYPE = 'dailyFuelRecord';
const COLLECTION_NAME = 'dailyFuelRecords';
const STATION_CACHE_TTL_MS = 15000;
const stationRecordsCache = new Map();

function roundDensity(value) {
  return Math.round((Number(value || 0) + Number.EPSILON) * 1000) / 1000;
}

function normalizeDate(value) {
  const raw = String(value || '').trim();
  if (!raw) {
    throw new Error('Effective date is required.');
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

function normalizeDensity(value = {}, {allowEmpty = false} = {}) {
  const density = {
    petrol: roundDensity(value?.petrol),
    diesel: roundDensity(value?.diesel),
  };
  if (allowEmpty) {
    return density;
  }
  if (!(density.petrol > 0) || !(density.diesel > 0)) {
    throw new Error('Petrol and diesel density must be greater than zero.');
  }
  return density;
}

function compareDailyFuelRecords(left, right) {
  return (
    String(left.date || '').localeCompare(String(right.date || '')) ||
    String(left.updatedAt || '').localeCompare(String(right.updatedAt || '')) ||
    String(left.id || '').localeCompare(String(right.id || ''))
  );
}

function cloneDailyFuelRecord(record) {
  return new DailyFuelRecord({
    id: record?.id,
    stationId: record?.stationId,
    date: record?.date,
    density: record?.density,
    createdAt: record?.createdAt,
    createdBy: record?.createdBy,
    createdByName: record?.createdByName,
    updatedAt: record?.updatedAt,
    updatedBy: record?.updatedBy,
    updatedByName: record?.updatedByName,
    allowEmptyDensity: true,
  });
}

function cloneDailyFuelRecords(records = []) {
  return records.map((record) => cloneDailyFuelRecord(record));
}

class DailyFuelRecord {
  constructor({
    id,
    stationId,
    date,
    density = {},
    createdAt = null,
    createdBy = '',
    createdByName = '',
    updatedAt = null,
    updatedBy = '',
    updatedByName = '',
    allowEmptyDensity = false,
  }) {
    if (!String(stationId || '').trim()) {
      throw new Error('Station is required.');
    }
    this.id = String(id || '').trim();
    this.stationId = String(stationId || '').trim();
    this.date = normalizeDate(date);
    this.density = normalizeDensity(density, {allowEmpty: allowEmptyDensity});
    this.createdAt = String(createdAt || '').trim() || null;
    this.createdBy = String(createdBy || '').trim();
    this.createdByName = String(createdByName || '').trim();
    this.updatedAt = String(updatedAt || '').trim() || null;
    this.updatedBy = String(updatedBy || '').trim();
    this.updatedByName = String(updatedByName || '').trim();
  }

  static idFor(stationId, date) {
    return `${String(stationId || '').trim()}:${normalizeDate(date)}`;
  }

  static fromRecord(record) {
    if (!record) {
      return null;
    }
    const claims = claimsFor(record);
    return new DailyFuelRecord({
      id: claims.id || claims.ek || '',
      stationId: claims.sid || '',
      date: claims.dt || '',
      density: claims.den || {},
      createdAt: claims.ca || '',
      createdBy: claims.cb || '',
      createdByName: claims.cbn || '',
      updatedAt: claims.ua || '',
      updatedBy: claims.ub || '',
      updatedByName: claims.ubn || '',
      allowEmptyDensity: true,
    });
  }

  static fromStoredDocument(snapshot) {
    if (!snapshot?.exists) {
      return null;
    }
    const data = snapshot.data() || {};
    return new DailyFuelRecord({
      id: data.id || data.ek || snapshot.id || '',
      stationId: data.sid || '',
      date: data.dt || '',
      density: data.den || {},
      createdAt: data.ca || data.createdAt || '',
      createdBy: data.cb || '',
      createdByName: data.cbn || '',
      updatedAt: data.ua || data.updatedAt || '',
      updatedBy: data.ub || '',
      updatedByName: data.ubn || '',
      allowEmptyDensity: true,
    });
  }

  toRecordPayload() {
    return {
      id: this.id,
      sid: this.stationId,
      dt: this.date,
      den: this.density,
      ca: this.createdAt,
      cb: this.createdBy,
      cbn: this.createdByName,
      ua: this.updatedAt,
      ub: this.updatedBy,
      ubn: this.updatedByName,
    };
  }

  toJson() {
    return {
      id: this.id,
      stationId: this.stationId,
      date: this.date,
      density: this.density,
      createdAt: this.createdAt,
      createdBy: this.createdBy,
      createdByName: this.createdByName,
      updatedAt: this.updatedAt,
      updatedBy: this.updatedBy,
      updatedByName: this.updatedByName,
    };
  }

  async save() {
    const timestamp = nowIso();
    if (!this.id) {
      this.id = DailyFuelRecord.idFor(this.stationId, this.date);
    }
    if (!this.createdAt) {
      this.createdAt = timestamp;
    }
    this.updatedAt = timestamp;
    await upsertDataRecord({
      entityType: ENTITY_TYPE,
      entityKey: this.id,
      displayName: `${this.date} daily fuel register`,
      payload: this.toRecordPayload(),
    });
    DailyFuelRecord.invalidateStationCache(this.stationId);
    return this;
  }

  static invalidateStationCache(stationId) {
    if (!stationId) {
      return;
    }
    stationRecordsCache.delete(String(stationId));
  }

  static async findById(id) {
    return DailyFuelRecord.fromRecord(await getDataRecord(ENTITY_TYPE, id));
  }

  static async findByDate(stationId, date) {
    const normalizedDate = normalizeDate(date);
    return DailyFuelRecord.findById(DailyFuelRecord.idFor(stationId, normalizedDate));
  }

  static async allForStation(stationId, {forceRefresh = false} = {}) {
    const normalizedStationId = String(stationId || '').trim();
    if (!normalizedStationId) {
      return [];
    }

    const cached = stationRecordsCache.get(normalizedStationId);
    if (!forceRefresh && cached && cached.expiresAt > Date.now()) {
      return cloneDailyFuelRecords(cached.records);
    }

    let records = [];
    try {
      const snapshot = await getFirestore()
        .collection(COLLECTION_NAME)
        .where('sid', '==', normalizedStationId)
        .get();
      records = snapshot.docs
        .map((doc) => DailyFuelRecord.fromStoredDocument(doc))
        .filter(Boolean)
        .sort(compareDailyFuelRecords);
    } catch (error) {
      console.warn('DailyFuelRecord station query fallback:', error.message);
    }

    if (records.length === 0) {
      records = (await listDataRecords(ENTITY_TYPE))
        .map((record) => DailyFuelRecord.fromRecord(record))
        .filter(Boolean)
        .filter((record) => record.stationId === normalizedStationId)
        .sort(compareDailyFuelRecords);
    }

    stationRecordsCache.set(normalizedStationId, {
      expiresAt: Date.now() + STATION_CACHE_TTL_MS,
      records: cloneDailyFuelRecords(records),
    });
    return cloneDailyFuelRecords(records);
  }

  static async allForStationRange(stationId, {fromDate = '', toDate = '', forceRefresh = false} = {}) {
    const records = await DailyFuelRecord.allForStation(stationId, {forceRefresh});
    return records.filter((record) => {
      if (fromDate && String(record.date || '') < String(fromDate || '')) {
        return false;
      }
      if (toDate && String(record.date || '') > String(toDate || '')) {
        return false;
      }
      return true;
    });
  }
}

module.exports = DailyFuelRecord;
