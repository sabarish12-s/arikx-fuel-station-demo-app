const {
  claimsFor,
  getDataRecord,
  listDataRecords,
  upsertDataRecord,
} = require('../utils/authStore');
const {getFirestore} = require('../config/firebase');
const StationDaySetup = require('./StationDaySetup');
const {DEFAULT_FUEL_PRICES} = require('../utils/seedData');
const {nowIso, todayInStationTimeZone} = require('../utils/time');

const ENTITY_TYPE = 'fuelPrice';
const COLLECTION_NAME = 'fuelPrices';
const DELETED_HISTORY_RETENTION_DAYS = 30;
const FUEL_PRICE_CACHE_TTL_MS = 300000;
let allFuelPricesCache = null;

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

function sortPeriods(periods = []) {
  return [...periods].sort((left, right) => {
    const leftFrom = left.effectiveFrom || '9999-12-31';
    const rightFrom = right.effectiveFrom || '9999-12-31';
    const fromCompare = leftFrom.localeCompare(rightFrom);
    if (fromCompare !== 0) {
      return fromCompare;
    }
    const leftTo = left.effectiveTo || '9999-12-31';
    const rightTo = right.effectiveTo || '9999-12-31';
    return leftTo.localeCompare(rightTo);
  });
}

function periodAppliesOn(period = {}, referenceDate) {
  if (String(period?.deletedAt || '').trim()) {
    return false;
  }
  const effectiveFrom = normalizeDateKey(period?.effectiveFrom);
  if (!effectiveFrom) {
    return false;
  }
  const effectiveTo = normalizeDateKey(period?.effectiveTo);
  if (effectiveFrom.localeCompare(referenceDate) > 0) {
    return false;
  }
  return !effectiveTo || effectiveTo.localeCompare(referenceDate) >= 0;
}

function normalizePeriods(
  periods = [],
  fallback = {},
  {allowEmpty = false} = {},
) {
  const source = Array.isArray(periods) && periods.length > 0
    ? periods
    : allowEmpty
      ? []
      : [
          {
            effectiveFrom:
              fallback.effectiveFrom ||
              fallback.updatedAt ||
              todayInStationTimeZone(),
            effectiveTo: fallback.effectiveTo || '',
            costPrice: fallback.costPrice || 0,
            sellingPrice: fallback.sellingPrice || 0,
            updatedAt: fallback.updatedAt || null,
            updatedBy: fallback.updatedBy || null,
            deletedAt: '',
            deletedBy: '',
            deletedByName: '',
          },
        ];

  const normalized = source
    .map((item) => ({
      effectiveFrom: normalizeDateKey(item?.effectiveFrom) || todayInStationTimeZone(),
      effectiveTo: normalizeDateKey(item?.effectiveTo),
      costPrice: Number(item?.costPrice || 0),
      sellingPrice: Number(item?.sellingPrice || 0),
      updatedAt: item?.updatedAt || fallback.updatedAt || null,
      updatedBy: item?.updatedBy || fallback.updatedBy || null,
      deletedAt: item?.deletedAt || '',
      deletedBy: item?.deletedBy || '',
      deletedByName: item?.deletedByName || '',
    }))
    .filter((item) => item.effectiveFrom);

  return sortPeriods(normalized);
}

function currentPeriodFrom(
  periods = [],
  referenceDate = todayInStationTimeZone(),
) {
  if (!Array.isArray(periods) || periods.length === 0) {
    return null;
  }
  const sorted = sortPeriods(periods).filter(
    (period) => !String(period?.deletedAt || '').trim(),
  );
  const applicable = sorted.filter((period) =>
    periodAppliesOn(period, referenceDate),
  );
  if (applicable.length > 0) {
    return applicable.at(-1);
  }
  const started = sorted.filter(
    (period) =>
      String(period?.effectiveFrom || '').localeCompare(referenceDate) <= 0,
  );
  if (started.length > 0) {
    return started.at(-1);
  }
  return sorted[0] || null;
}

class FuelPrice {
  constructor({
    fuelTypeId,
    costPrice,
    sellingPrice,
    updatedAt = null,
    updatedBy = null,
    effectiveFrom = '',
    effectiveTo = '',
    periods = [],
    allowEmptyPeriods = false,
  }) {
    this.fuelTypeId = fuelTypeId;
    this.updatedAt = updatedAt;
    this.updatedBy = updatedBy;
    this.periods = normalizePeriods(periods, {
      costPrice,
      sellingPrice,
      updatedAt,
      updatedBy,
      effectiveFrom,
      effectiveTo,
    }, {allowEmpty: allowEmptyPeriods});

    const currentPeriod = currentPeriodFrom(this.periods) || {
      costPrice: Number(costPrice || 0),
      sellingPrice: Number(sellingPrice || 0),
      effectiveFrom: normalizeDateKey(effectiveFrom),
      effectiveTo: normalizeDateKey(effectiveTo),
    };

    this.costPrice = Number(currentPeriod.costPrice || 0);
    this.sellingPrice = Number(currentPeriod.sellingPrice || 0);
    this.effectiveFrom = currentPeriod.effectiveFrom || '';
    this.effectiveTo = currentPeriod.effectiveTo || '';
  }

  static fromRecord(record) {
    if (!record) {
      return null;
    }
    const claims = claimsFor(record);
    return new FuelPrice({
      fuelTypeId: claims.fuelTypeId,
      costPrice: claims.costPrice,
      sellingPrice: claims.sellingPrice,
      updatedAt: claims.updatedAt || null,
      updatedBy: claims.updatedBy || null,
      effectiveFrom: claims.effectiveFrom || '',
      effectiveTo: claims.effectiveTo || '',
      periods: claims.periods || [],
    });
  }

  toJson() {
    return {
      fuelTypeId: this.fuelTypeId,
      costPrice: this.costPrice,
      sellingPrice: this.sellingPrice,
      updatedAt: this.updatedAt,
      updatedBy: this.updatedBy,
      effectiveFrom: this.effectiveFrom,
      effectiveTo: this.effectiveTo,
      periods: this.periods,
    };
  }

  async save() {
    await upsertDataRecord({
      entityType: ENTITY_TYPE,
      entityKey: this.fuelTypeId,
      displayName: `Price:${this.fuelTypeId}`,
      payload: this.toJson(),
    });
    FuelPrice.invalidateCache();
    return this;
  }

  static async ensureDefaults() {
    const existing = await FuelPrice.findAll();
    if (existing.length === 0) {
      for (const item of DEFAULT_FUEL_PRICES) {
        await new FuelPrice({
          ...item,
          updatedAt: new Date().toISOString(),
          effectiveFrom: todayInStationTimeZone(),
        }).save();
      }
      return FuelPrice.findAll();
    }
    const existingIds = new Set(existing.map((item) => item.fuelTypeId));
    for (const item of DEFAULT_FUEL_PRICES) {
      if (!existingIds.has(item.fuelTypeId)) {
        await new FuelPrice({
          ...item,
          updatedAt: new Date().toISOString(),
          effectiveFrom: todayInStationTimeZone(),
        }).save();
      }
    }
    return FuelPrice.findAll();
  }

  static async findAll() {
    if (allFuelPricesCache && allFuelPricesCache.expiresAt > Date.now()) {
      return allFuelPricesCache.prices.map((price) => new FuelPrice(price.toJson()));
    }

    let mapped = [];

    try {
      const snapshot = await getFirestore().collection(COLLECTION_NAME).get();
      mapped = snapshot.docs
        .map((doc) => FuelPrice.fromRecord({
          customClaims: doc.data() || {},
        }))
        .filter(Boolean);
    } catch (error) {
      console.warn('FuelPrice collection query fallback:', error.message);
    }

    if (mapped.length === 0) {
      mapped = (await listDataRecords(ENTITY_TYPE))
      .map((record) => FuelPrice.fromRecord(record))
      .filter(Boolean);
    }

    const byFuelTypeId = new Map();
    for (const price of mapped) {
      const existing = byFuelTypeId.get(price.fuelTypeId);
      if (!existing) {
        byFuelTypeId.set(price.fuelTypeId, price);
        continue;
      }
      const existingUpdatedAt = String(existing.updatedAt || '');
      const nextUpdatedAt = String(price.updatedAt || '');
      if (nextUpdatedAt.localeCompare(existingUpdatedAt) >= 0) {
        byFuelTypeId.set(price.fuelTypeId, price);
      }
    }

    const prices = [...byFuelTypeId.values()].sort((a, b) => a.fuelTypeId.localeCompare(b.fuelTypeId));
    allFuelPricesCache = {
      expiresAt: Date.now() + FUEL_PRICE_CACHE_TTL_MS,
      prices: prices.map((price) => new FuelPrice(price.toJson())),
    };
    return prices.map((price) => new FuelPrice(price.toJson()));
  }

  static async findByFuelTypeId(fuelTypeId) {
    const normalizedFuelTypeId = String(fuelTypeId || '').trim();
    if (!normalizedFuelTypeId) {
      return null;
    }
    if (allFuelPricesCache && allFuelPricesCache.expiresAt > Date.now()) {
      const cachedPrice = allFuelPricesCache.prices.find(
        (price) => price.fuelTypeId === normalizedFuelTypeId,
      );
      if (cachedPrice) {
        return new FuelPrice(cachedPrice.toJson());
      }
    }
    return FuelPrice.fromRecord(await getDataRecord(ENTITY_TYPE, fuelTypeId));
  }

  static invalidateCache() {
    allFuelPricesCache = null;
  }

  static async purgeExpiredDeletedPeriods() {
    const cutoffIso = new Date(
      Date.now() - DELETED_HISTORY_RETENTION_DAYS * 24 * 60 * 60 * 1000,
    ).toISOString();
    const prices = await FuelPrice.findAll();
    const saved = [];
    for (const price of prices) {
      const retainedPeriods = price.periods.filter((period) => {
        const deletedAt = String(period?.deletedAt || '').trim();
        return !deletedAt || deletedAt.localeCompare(cutoffIso) >= 0;
      });
      if (retainedPeriods.length === price.periods.length) {
        saved.push(price);
        continue;
      }
      const nextPrice = new FuelPrice({
        fuelTypeId: price.fuelTypeId,
        costPrice: price.costPrice,
        sellingPrice: price.sellingPrice,
        updatedAt: price.updatedAt,
        updatedBy: price.updatedBy,
        periods: retainedPeriods,
        allowEmptyPeriods: retainedPeriods.length === 0,
      });
      await nextPrice.save();
      saved.push(nextPrice);
    }
    return saved;
  }

  static async deleteSet({
    effectiveDate,
    deletedBy = '',
    deletedByName = '',
  }) {
    const dateKey = normalizeDateKey(effectiveDate);
    if (!dateKey) {
      throw new Error('Valid effective date is required.');
    }
    const prices = await FuelPrice.purgeExpiredDeletedPeriods();
    const deletedAt = nowIso();
    const saved = [];
    let matched = false;
    for (const price of prices) {
      const periods = price.periods.map((period) => {
        if (normalizeDateKey(period.effectiveFrom) !== dateKey) {
          return period;
        }
        matched = true;
        if (String(period.deletedAt || '').trim()) {
          return period;
        }
        return {
          ...period,
          deletedAt,
          deletedBy: String(deletedBy || '').trim(),
          deletedByName: String(deletedByName || '').trim(),
        };
      });
      const nextPrice = new FuelPrice({
        fuelTypeId: price.fuelTypeId,
        costPrice: price.costPrice,
        sellingPrice: price.sellingPrice,
        updatedAt: price.updatedAt,
        updatedBy: price.updatedBy,
        periods,
      });
      await nextPrice.save();
      saved.push(nextPrice);
    }
    return matched ? saved : null;
  }

  static async getSnapshot(referenceDate = todayInStationTimeZone(), stationId = '') {
    if (stationId) {
      const activeSetup = await StationDaySetup.latestActiveOnOrBefore(
        stationId,
        referenceDate,
      );
      if (activeSetup) {
        return Object.entries(activeSetup.fuelPrices || {}).reduce(
          (accumulator, [fuelTypeId, prices]) => {
            accumulator[fuelTypeId] = {
              costPrice: Number(prices?.costPrice || 0),
              sellingPrice: Number(prices?.sellingPrice || 0),
            };
            return accumulator;
          },
          {},
        );
      }
    }

    const prices = await FuelPrice.findAll();
    return prices.reduce((accumulator, price) => {
      accumulator[price.fuelTypeId] = {
        costPrice: price.costPrice,
        sellingPrice: price.sellingPrice,
      };
      return accumulator;
    }, {});
  }
}

module.exports = FuelPrice;
