const {
  claimsFor,
  deleteDataRecord,
  getDataRecord,
  listDataRecords,
  upsertDataRecord,
} = require('../utils/authStore');
const {admin, getFirestore} = require('../config/firebase');
const {nowIso} = require('../utils/time');

const ENTITY_TYPE = 'dailySalesSummary';
const COLLECTION_NAME = 'dailySalesSummaries';
const STATION_CACHE_TTL_MS = 300000;
const stationSummaryCache = new Map();
const summaryByIdCache = new Map();

function roundNumber(value) {
  return Math.round((Number(value || 0) + Number.EPSILON) * 100) / 100;
}

function normalizeTotals(value = {}) {
  return {
    revenue: roundNumber(value.revenue),
    paymentTotal: roundNumber(value.paymentTotal),
    profit: roundNumber(value.profit),
    petrolSold: roundNumber(value.petrolSold),
    dieselSold: roundNumber(value.dieselSold),
    twoTSold: roundNumber(value.twoTSold),
    creditTotal: roundNumber(value.creditTotal),
    flaggedCount: Math.max(0, Number(value.flaggedCount || 0)),
    entriesCompleted: Math.max(0, Number(value.entriesCompleted || 0)),
    shiftsCompleted: Math.max(0, Number(value.shiftsCompleted || 0)),
  };
}

function normalizePaymentBreakdown(value = {}) {
  return {
    cash: roundNumber(value.cash),
    check: roundNumber(value.check),
    upi: roundNumber(value.upi),
    credit: roundNumber(value.credit),
  };
}

function normalizeFuelBreakdown(value = {}) {
  return {
    petrol: roundNumber(value.petrol),
    diesel: roundNumber(value.diesel),
    two_t_oil: roundNumber(value.two_t_oil),
  };
}

function normalizeTrend(value = {}) {
  return {
    date: String(value.date || '').trim(),
    revenue: roundNumber(value.revenue),
    paymentTotal: roundNumber(value.paymentTotal),
    profit: roundNumber(value.profit),
    petrolSold: roundNumber(value.petrolSold),
    dieselSold: roundNumber(value.dieselSold),
    twoTSold: roundNumber(value.twoTSold),
    entries: Math.max(0, Number(value.entries || 0)),
    shifts: Math.max(0, Number(value.shifts || 0)),
  };
}

function cloneJson(value) {
  return JSON.parse(JSON.stringify(value));
}

function cloneSummary(summary) {
  return summary ? new DailySalesSummary(summary.toJson()) : null;
}

function cloneSummaries(summaries = []) {
  return summaries.map((summary) => cloneSummary(summary));
}

function summaryId(stationId, date) {
  return `${String(stationId || '').trim()}:${String(date || '').trim()}`;
}

function stationRangeCacheKey(stationId, fromDate = '', toDate = '') {
  return `${stationId}:${fromDate || ''}:${toDate || ''}`;
}

class DailySalesSummary {
  constructor({
    id,
    stationId,
    date,
    totals = {},
    paymentBreakdown = {},
    fuelBreakdown = {},
    distribution = [],
    entries = [],
    trend = {},
    updatedAt = null,
  }) {
    this.stationId = String(stationId || '').trim();
    this.date = String(date || '').trim();
    this.id = String(id || '').trim() || summaryId(this.stationId, this.date);
    this.totals = normalizeTotals(totals);
    this.paymentBreakdown = normalizePaymentBreakdown(paymentBreakdown);
    this.fuelBreakdown = normalizeFuelBreakdown(fuelBreakdown);
    this.distribution = Array.isArray(distribution) ? cloneJson(distribution) : [];
    this.entries = Array.isArray(entries) ? cloneJson(entries) : [];
    this.trend = normalizeTrend(trend);
    this.updatedAt = String(updatedAt || '').trim() || null;
  }

  static fromRecord(record) {
    if (!record) {
      return null;
    }
    const claims = claimsFor(record);
    return new DailySalesSummary({
      id: claims.id || claims.ek || '',
      stationId: claims.sid || '',
      date: claims.dt || '',
      totals: claims.tl || {},
      paymentBreakdown: claims.pb || {},
      fuelBreakdown: claims.fb || {},
      distribution: claims.ds || [],
      entries: claims.es || [],
      trend: claims.tr || {},
      updatedAt: claims.ua || null,
    });
  }

  static fromStoredDocument(snapshot) {
    if (!snapshot?.exists) {
      return null;
    }
    const data = snapshot.data() || {};
    return new DailySalesSummary({
      id: data.id || data.ek || snapshot.id || '',
      stationId: data.sid || '',
      date: data.dt || '',
      totals: data.tl || {},
      paymentBreakdown: data.pb || {},
      fuelBreakdown: data.fb || {},
      distribution: data.ds || [],
      entries: data.es || [],
      trend: data.tr || {},
      updatedAt: data.ua || data.updatedAt || null,
    });
  }

  toRecordPayload() {
    return {
      id: this.id,
      sid: this.stationId,
      dt: this.date,
      tl: this.totals,
      pb: this.paymentBreakdown,
      fb: this.fuelBreakdown,
      ds: this.distribution,
      es: this.entries,
      tr: this.trend,
      ua: this.updatedAt,
    };
  }

  toJson() {
    return {
      id: this.id,
      stationId: this.stationId,
      date: this.date,
      totals: this.totals,
      paymentBreakdown: this.paymentBreakdown,
      fuelBreakdown: this.fuelBreakdown,
      distribution: cloneJson(this.distribution),
      entries: cloneJson(this.entries),
      trend: this.trend,
      updatedAt: this.updatedAt || '',
    };
  }

  toApiJson() {
    return {
      date: this.date,
      totals: this.totals,
      paymentBreakdown: this.paymentBreakdown,
      fuelBreakdown: this.fuelBreakdown,
      distribution: cloneJson(this.distribution),
      entries: cloneJson(this.entries),
      trend: this.trend.date ? [this.trend] : [],
    };
  }

  async save() {
    this.updatedAt = nowIso();
    await upsertDataRecord({
      entityType: ENTITY_TYPE,
      entityKey: this.id,
      displayName: `${this.date} daily sales summary`,
      payload: this.toRecordPayload(),
    });
    DailySalesSummary.invalidateStationCache(this.stationId);
    summaryByIdCache.set(this.id, {
      expiresAt: Date.now() + STATION_CACHE_TTL_MS,
      summary: cloneSummary(this),
    });
    return this;
  }

  async deletePermanent() {
    await deleteDataRecord(ENTITY_TYPE, this.id);
    DailySalesSummary.invalidateStationCache(this.stationId);
    summaryByIdCache.delete(this.id);
  }

  static async findByDate(stationId, date) {
    const normalizedId = summaryId(stationId, date);
    if (!normalizedId || normalizedId === ':') {
      return null;
    }

    const cached = summaryByIdCache.get(normalizedId);
    if (cached && cached.expiresAt > Date.now()) {
      return cloneSummary(cached.summary);
    }

    const summary = DailySalesSummary.fromRecord(
      await getDataRecord(ENTITY_TYPE, normalizedId),
    );
    if (!summary) {
      summaryByIdCache.delete(normalizedId);
      return null;
    }
    summaryByIdCache.set(normalizedId, {
      expiresAt: Date.now() + STATION_CACHE_TTL_MS,
      summary: cloneSummary(summary),
    });
    return cloneSummary(summary);
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
    const cached = stationSummaryCache.get(cacheKey);
    if (cached && cached.expiresAt > Date.now()) {
      return cloneSummaries(cached.summaries);
    }

    let summaries = [];
    let directQuerySucceeded = false;

    try {
      const documentId = admin.firestore.FieldPath.documentId();
      const startId = summaryId(normalizedStationId, normalizedFromDate || '');
      const endId = summaryId(normalizedStationId, normalizedToDate || '\uf8ff');
      const snapshot = await getFirestore()
        .collection(COLLECTION_NAME)
        .where(documentId, '>=', startId)
        .where(documentId, '<=', endId)
        .get();
      summaries = snapshot.docs
        .map((doc) => DailySalesSummary.fromStoredDocument(doc))
        .filter(Boolean)
        .filter((summary) => {
          if (summary.stationId !== normalizedStationId) {
            return false;
          }
          if (normalizedFromDate && String(summary.date || '') < normalizedFromDate) {
            return false;
          }
          if (normalizedToDate && String(summary.date || '') > normalizedToDate) {
            return false;
          }
          return true;
        });
      directQuerySucceeded = true;
    } catch (error) {
      console.warn('DailySalesSummary range query fallback:', error.message);
    }

    if (!directQuerySucceeded) {
      summaries = (await listDataRecords(ENTITY_TYPE))
        .map((record) => DailySalesSummary.fromRecord(record))
        .filter(Boolean)
        .filter((summary) => {
          if (summary.stationId !== normalizedStationId) {
            return false;
          }
          if (normalizedFromDate && String(summary.date || '') < normalizedFromDate) {
            return false;
          }
          if (normalizedToDate && String(summary.date || '') > normalizedToDate) {
            return false;
          }
          return true;
        });
    }

    summaries.sort((left, right) => String(left.date || '').localeCompare(String(right.date || '')));
    stationSummaryCache.set(cacheKey, {
      expiresAt: Date.now() + STATION_CACHE_TTL_MS,
      summaries: cloneSummaries(summaries),
    });
    for (const summary of summaries) {
      summaryByIdCache.set(summary.id, {
        expiresAt: Date.now() + STATION_CACHE_TTL_MS,
        summary: cloneSummary(summary),
      });
    }
    return cloneSummaries(summaries);
  }

  static invalidateStationCache(stationId) {
    const normalizedStationId = String(stationId || '').trim();
    if (!normalizedStationId) {
      return;
    }
    for (const key of stationSummaryCache.keys()) {
      if (key.startsWith(`${normalizedStationId}:`)) {
        stationSummaryCache.delete(key);
      }
    }
    for (const key of summaryByIdCache.keys()) {
      if (key.startsWith(`${normalizedStationId}:`)) {
        summaryByIdCache.delete(key);
      }
    }
  }
}

module.exports = DailySalesSummary;
