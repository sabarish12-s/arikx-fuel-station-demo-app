const {
  claimsFor,
  getDataRecord,
  listDataRecords,
  upsertDataRecord,
} = require('../utils/authStore');
const {nowIso} = require('../utils/time');

const ENTITY_TYPE = 'fuelPriceUpdateRequest';

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

function normalizeFuelPrices(value = {}) {
  return ['petrol', 'diesel', 'two_t_oil'].reduce((result, fuelTypeId) => {
    const source = value?.[fuelTypeId] || {};
    result[fuelTypeId] = {
      costPrice: roundNumber(source.costPrice),
      sellingPrice: roundNumber(source.sellingPrice),
    };
    return result;
  }, {});
}

function normalizeStatus(value) {
  const status = String(value || '').trim().toLowerCase();
  return ['pending', 'approved', 'rejected'].includes(status)
    ? status
    : 'pending';
}

function requestIdFor({stationId, effectiveDate, requestedBy}) {
  const timestamp = nowIso().replace(/[^0-9A-Za-z]/g, '');
  return [
    String(stationId || '').trim(),
    normalizeDateKey(effectiveDate),
    String(requestedBy || '').trim() || 'sales',
    timestamp,
  ].join(':');
}

class FuelPriceUpdateRequest {
  constructor({
    id = '',
    stationId = '',
    effectiveDate = '',
    currentPrices = {},
    requestedPrices = {},
    note = '',
    status = 'pending',
    requestedAt = null,
    requestedBy = '',
    requestedByName = '',
    reviewedAt = '',
    reviewedBy = '',
    reviewedByName = '',
    reviewNote = '',
  }) {
    this.id = String(id || '').trim();
    this.stationId = String(stationId || '').trim();
    this.effectiveDate = normalizeDateKey(effectiveDate);
    this.currentPrices = normalizeFuelPrices(currentPrices);
    this.requestedPrices = normalizeFuelPrices(requestedPrices);
    this.note = String(note || '').trim();
    this.status = normalizeStatus(status);
    this.requestedAt = String(requestedAt || '').trim() || null;
    this.requestedBy = String(requestedBy || '').trim();
    this.requestedByName = String(requestedByName || '').trim();
    this.reviewedAt = String(reviewedAt || '').trim();
    this.reviewedBy = String(reviewedBy || '').trim();
    this.reviewedByName = String(reviewedByName || '').trim();
    this.reviewNote = String(reviewNote || '').trim();
  }

  static fromRecord(record) {
    if (!record) {
      return null;
    }
    const claims = claimsFor(record);
    return new FuelPriceUpdateRequest({
      id: claims.id || claims.ek || record.uid || '',
      stationId: claims.sid || '',
      effectiveDate: claims.dt || '',
      currentPrices: claims.cp || {},
      requestedPrices: claims.rp || {},
      note: claims.nt || '',
      status: claims.st || 'pending',
      requestedAt: claims.ra || null,
      requestedBy: claims.rb || '',
      requestedByName: claims.rbn || '',
      reviewedAt: claims.va || '',
      reviewedBy: claims.vb || '',
      reviewedByName: claims.vbn || '',
      reviewNote: claims.vn || '',
    });
  }

  toRecordPayload() {
    return {
      id: this.id,
      sid: this.stationId,
      dt: this.effectiveDate,
      cp: this.currentPrices,
      rp: this.requestedPrices,
      nt: this.note,
      st: this.status,
      ra: this.requestedAt,
      rb: this.requestedBy,
      rbn: this.requestedByName,
      va: this.reviewedAt,
      vb: this.reviewedBy,
      vbn: this.reviewedByName,
      vn: this.reviewNote,
    };
  }

  toJson() {
    return {
      id: this.id,
      stationId: this.stationId,
      effectiveDate: this.effectiveDate,
      currentPrices: this.currentPrices,
      requestedPrices: this.requestedPrices,
      note: this.note,
      status: this.status,
      requestedAt: this.requestedAt,
      requestedBy: this.requestedBy,
      requestedByName: this.requestedByName,
      reviewedAt: this.reviewedAt,
      reviewedBy: this.reviewedBy,
      reviewedByName: this.reviewedByName,
      reviewNote: this.reviewNote,
    };
  }

  async save() {
    if (!this.id) {
      this.id = requestIdFor(this);
    }
    if (!this.requestedAt) {
      this.requestedAt = nowIso();
    }
    await upsertDataRecord({
      entityType: ENTITY_TYPE,
      entityKey: this.id,
      displayName: `${this.effectiveDate} Fuel Price Request`,
      payload: this.toRecordPayload(),
    });
    return this;
  }

  static async findById(id) {
    return FuelPriceUpdateRequest.fromRecord(await getDataRecord(ENTITY_TYPE, id));
  }

  static async listForStation(stationId, {status = ''} = {}) {
    const normalizedStationId = String(stationId || '').trim();
    const normalizedStatus = String(status || '').trim().toLowerCase();
    const requests = (await listDataRecords(ENTITY_TYPE))
      .map((record) => FuelPriceUpdateRequest.fromRecord(record))
      .filter(Boolean)
      .filter((request) => request.stationId === normalizedStationId)
      .filter((request) => !normalizedStatus || request.status === normalizedStatus);
    requests.sort((left, right) =>
      String(right.requestedAt || '').localeCompare(String(left.requestedAt || '')),
    );
    return requests;
  }
}

module.exports = FuelPriceUpdateRequest;
