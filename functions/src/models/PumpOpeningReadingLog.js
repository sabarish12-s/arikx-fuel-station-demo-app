const {
  claimsFor,
  deleteDataRecord,
  getDataRecord,
  listDataRecords,
  upsertDataRecord,
} = require('../utils/authStore');
const {getFirestore} = require('../config/firebase');
const {nowIso} = require('../utils/time');

const ENTITY_TYPE = 'pumpOpeningReadingLog';
const COLLECTION_NAME = 'pumpOpeningReadingLogs';

function roundNumber(value) {
  return Math.round((Number(value || 0) + Number.EPSILON) * 100) / 100;
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

function normalizeReadings(readings = {}, pumps = []) {
  const result = {};
  for (const pump of pumps) {
    const source = readings?.[pump.id] || {};
    const item = {
      petrol: roundNumber(source.petrol),
      diesel: roundNumber(source.diesel),
      twoT: 0,
    };
    for (const fuelKey of ['petrol', 'diesel']) {
      if (item[fuelKey] < 0) {
        throw new Error('Opening readings must be non-negative.');
      }
    }
    result[pump.id] = item;
  }
  return result;
}

function compareLogs(left, right) {
  return (
    String(left.effectiveDate || '').localeCompare(String(right.effectiveDate || '')) ||
    String(left.createdAt || '').localeCompare(String(right.createdAt || '')) ||
    String(left.id || '').localeCompare(String(right.id || ''))
  );
}

class PumpOpeningReadingLog {
  constructor({
    id,
    stationId,
    effectiveDate,
    readings = {},
    note = '',
    createdAt = null,
    createdBy = '',
    createdByName = '',
    deletedAt = '',
    deletedBy = '',
    deletedByName = '',
  }) {
    if (!String(stationId || '').trim()) {
      throw new Error('Station is required.');
    }
    this.id = String(id || '').trim();
    this.stationId = String(stationId || '').trim();
    this.effectiveDate = normalizeDate(effectiveDate);
    this.readings = readings || {};
    this.note = String(note || '').trim();
    this.createdAt = String(createdAt || nowIso()).trim();
    this.createdBy = String(createdBy || '').trim();
    this.createdByName = String(createdByName || '').trim();
    this.deletedAt = String(deletedAt || '').trim();
    this.deletedBy = String(deletedBy || '').trim();
    this.deletedByName = String(deletedByName || '').trim();
  }

  static fromRecord(record) {
    if (!record) {
      return null;
    }
    const claims = claimsFor(record);
    return new PumpOpeningReadingLog({
      id: claims.id || claims.ek || '',
      stationId: claims.sid || '',
      effectiveDate: claims.ed || '',
      readings: claims.rd || {},
      note: claims.nt || '',
      createdAt: claims.ca || '',
      createdBy: claims.cb || '',
      createdByName: claims.cbn || '',
      deletedAt: claims.da || '',
      deletedBy: claims.db || '',
      deletedByName: claims.dbn || '',
    });
  }

  static fromStoredDocument(snapshot) {
    if (!snapshot?.exists) {
      return null;
    }
    const data = snapshot.data() || {};
    return new PumpOpeningReadingLog({
      id: data.id || data.ek || snapshot.id || '',
      stationId: data.sid || '',
      effectiveDate: data.ed || '',
      readings: data.rd || {},
      note: data.nt || '',
      createdAt: data.ca || '',
      createdBy: data.cb || '',
      createdByName: data.cbn || '',
      deletedAt: data.da || '',
      deletedBy: data.db || '',
      deletedByName: data.dbn || '',
    });
  }

  toRecordPayload() {
    return {
      id: this.id,
      sid: this.stationId,
      ed: this.effectiveDate,
      rd: this.readings,
      nt: this.note,
      ca: this.createdAt,
      cb: this.createdBy,
      cbn: this.createdByName,
      da: this.deletedAt,
      db: this.deletedBy,
      dbn: this.deletedByName,
    };
  }

  toJson() {
    return {
      id: this.id,
      stationId: this.stationId,
      effectiveDate: this.effectiveDate,
      readings: this.readings,
      note: this.note,
      createdAt: this.createdAt,
      createdBy: this.createdBy,
      createdByName: this.createdByName,
      deletedAt: this.deletedAt,
      deletedBy: this.deletedBy,
      deletedByName: this.deletedByName,
    };
  }

  async save() {
    await upsertDataRecord({
      entityType: ENTITY_TYPE,
      entityKey: this.id,
      displayName: `${this.effectiveDate} pump opening readings`,
      payload: this.toRecordPayload(),
    });
    return this;
  }

  static async findById(id) {
    return PumpOpeningReadingLog.fromRecord(await getDataRecord(ENTITY_TYPE, id));
  }

  static async deleteById(id) {
    return deleteDataRecord(ENTITY_TYPE, id);
  }

  static async allForStation(stationId) {
    if (!stationId) {
      return [];
    }
    try {
      const snapshot = await getFirestore()
        .collection(COLLECTION_NAME)
        .where('sid', '==', stationId)
        .get();
      return snapshot.docs
        .map((doc) => PumpOpeningReadingLog.fromStoredDocument(doc))
        .filter(Boolean)
        .sort(compareLogs);
    } catch (error) {
      console.warn('PumpOpeningReadingLog station query fallback:', error.message);
    }

    return (await listDataRecords(ENTITY_TYPE))
      .map((record) => PumpOpeningReadingLog.fromRecord(record))
      .filter(Boolean)
      .filter((entry) => entry.stationId === stationId)
      .sort(compareLogs);
  }
}

module.exports = {
  PumpOpeningReadingLog,
  compareLogs,
  normalizeReadings,
};
