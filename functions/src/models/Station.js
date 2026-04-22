const {
  getDataRecord,
  upsertDataRecord,
  claimsFor,
  listDataRecords,
} = require('../utils/authStore');
const {DEFAULT_STATION} = require('../utils/seedData');
const {nowIso} = require('../utils/time');

const ENTITY_TYPE = 'station';
const STATION_CACHE_TTL_MS = 300000;
const stationByIdCache = new Map();
let stationsCache = null;

function cloneStation(station) {
  return station ? new Station(station.toJson()) : null;
}

function cloneStations(stations = []) {
  return stations.map((station) => cloneStation(station));
}

function normalizeInventoryPlanning(value = {}) {
  const openingStock = value?.openingStock || value?.currentStock || {};
  const currentStock = value?.currentStock || openingStock;
  return {
    openingStock: {
      petrol: Number(openingStock.petrol || 0),
      diesel: Number(openingStock.diesel || 0),
      two_t_oil: Number(openingStock.two_t_oil || 0),
    },
    currentStock: {
      petrol: Number(currentStock.petrol || 0),
      diesel: Number(currentStock.diesel || 0),
      two_t_oil: Number(currentStock.two_t_oil || 0),
    },
    deliveryLeadDays: Math.max(0, Number(value?.deliveryLeadDays || 0)),
    alertBeforeDays: Math.max(0, Number(value?.alertBeforeDays || 0)),
    updatedAt: String(value?.updatedAt || '').trim(),
  };
}

function normalizeSalesmanCode(value) {
  return String(value || '').trim().toUpperCase();
}

function createSalesmanId(code) {
  return `salesman-${normalizeSalesmanCode(code).toLowerCase().replace(/[^a-z0-9]+/g, '-')}`;
}

function normalizeSalesmen(value = [], {touchUpdatedAt = false} = {}) {
  const timestamp = nowIso();
  const seenCodes = new Set();
  const salesmen = [];

  for (const item of Array.isArray(value) ? value : []) {
    const name = String(item?.name || '').trim();
    const code = normalizeSalesmanCode(item?.code);
    const active = item?.active !== false;
    const createdAt = String(item?.createdAt || '').trim();
    const updatedAt = String(item?.updatedAt || '').trim();

    if (!name && !code) {
      continue;
    }
    if (!name) {
      throw new Error('Salesman name is required.');
    }
    if (!code) {
      throw new Error(`Salesman code is required for ${name}.`);
    }

    const codeKey = code.toLowerCase();
    if (seenCodes.has(codeKey)) {
      throw new Error(`Salesman code ${code} already exists.`);
    }
    seenCodes.add(codeKey);

    salesmen.push({
      id: String(item?.id || '').trim() || createSalesmanId(code),
      name,
      code,
      active,
      createdAt: createdAt || timestamp,
      updatedAt: touchUpdatedAt ? timestamp : (updatedAt || timestamp),
    });
  }

  return salesmen;
}

class Station {
  constructor({
    id,
    name,
    code,
    city,
    shifts = [],
    pumps = [],
    baseReadings = {},
    meterLimits = {},
    inventoryPlanning = {},
    flagThreshold = 0.01,
    salesmen = [],
  }) {
    this.id = id;
    this.name = name;
    this.code = code;
    this.city = city;
    this.shifts = shifts;
    this.pumps = pumps;
    this.baseReadings = baseReadings;
    this.meterLimits = meterLimits;
    this.inventoryPlanning = normalizeInventoryPlanning(inventoryPlanning);
    this.flagThreshold = typeof flagThreshold === 'number' && flagThreshold >= 0
      ? flagThreshold
      : 0.01;
    this.salesmen = normalizeSalesmen(salesmen);
  }

  static fromRecord(record) {
    if (!record) {
      return null;
    }
    const claims = claimsFor(record);
    return new Station({
      id: claims.id,
      name: claims.name,
      code: claims.code,
      city: claims.city,
      shifts: ['daily'],
      pumps: claims.pumps || [],
      baseReadings: claims.baseReadings || {},
      meterLimits: claims.meterLimits || {},
      inventoryPlanning: claims.inventoryPlanning || {},
      flagThreshold: claims.flagThreshold != null ? Number(claims.flagThreshold) : 0.01,
      salesmen: claims.salesmen || [],
    });
  }

  async save() {
    this.shifts = ['daily'];
    this.salesmen = normalizeSalesmen(this.salesmen, {touchUpdatedAt: true});
    await upsertDataRecord({
      entityType: ENTITY_TYPE,
      entityKey: this.id,
      displayName: this.name,
      payload: {
        id: this.id,
        name: this.name,
        code: this.code,
        city: this.city,
        shifts: ['daily'],
        pumps: this.pumps,
        baseReadings: this.baseReadings,
        meterLimits: this.meterLimits,
        inventoryPlanning: this.inventoryPlanning,
        flagThreshold: this.flagThreshold,
        salesmen: this.salesmen,
      },
    });
    Station.invalidateCache(this.id);
    return this;
  }

  static async getDefault() {
    return Station.findById(DEFAULT_STATION.id);
  }

  static async ensureDefault() {
    const existing = await Station.findById(DEFAULT_STATION.id);
    if (existing) {
      let changed = false;
      const pumps = [...(existing.pumps || [])];
      const pump2Index = pumps.findIndex((pump) => pump.id === 'pump2');
      if (pump2Index !== -1) {
        const pump2 = {...pumps[pump2Index]};
        const nozzles = Array.isArray(pump2.nozzles) ? [...pump2.nozzles] : [];
        if (!nozzles.some((nozzle) => nozzle.fuelTypeId === 'two_t_oil')) {
          nozzles.push({fuelTypeId: 'two_t_oil', label: '2T Oil Gun'});
          pump2.nozzles = nozzles;
          pumps[pump2Index] = pump2;
          changed = true;
        }
      }
      const baseReadings = {...(existing.baseReadings || {})};
      const meterLimits = {...(existing.meterLimits || {})};
      const inventoryPlanning = normalizeInventoryPlanning(existing.inventoryPlanning);
      const salesmen = normalizeSalesmen(existing.salesmen || []);
      for (const [pumpId, readings] of Object.entries(DEFAULT_STATION.baseReadings)) {
        const current = {...(baseReadings[pumpId] || {})};
        if (current.twoT == null) {
          current.twoT = readings.twoT || 0;
          baseReadings[pumpId] = current;
          changed = true;
        }
      }
      for (const [pumpId, readings] of Object.entries(DEFAULT_STATION.meterLimits || {})) {
        const current = {...(meterLimits[pumpId] || {})};
        if (current.petrol == null) {
          current.petrol = readings.petrol || 0;
          changed = true;
        }
        if (current.diesel == null) {
          current.diesel = readings.diesel || 0;
          changed = true;
        }
        if (current.twoT == null) {
          current.twoT = readings.twoT || 0;
          changed = true;
        }
        meterLimits[pumpId] = current;
      }
      if (!inventoryPlanning.updatedAt) {
        inventoryPlanning.updatedAt = DEFAULT_STATION.inventoryPlanning.updatedAt || '';
        changed = true;
      }
      for (const fuelKey of ['petrol', 'diesel', 'two_t_oil']) {
        if (inventoryPlanning.openingStock?.[fuelKey] == null) {
          const fallbackOpening =
            DEFAULT_STATION.inventoryPlanning.openingStock?.[fuelKey] != null
              ? DEFAULT_STATION.inventoryPlanning.openingStock[fuelKey]
              : DEFAULT_STATION.inventoryPlanning.currentStock[fuelKey] || 0;
          inventoryPlanning.openingStock[fuelKey] = fallbackOpening;
          changed = true;
        }
      }
      for (const fuelKey of ['petrol', 'diesel', 'two_t_oil']) {
        if (inventoryPlanning.currentStock?.[fuelKey] == null) {
          inventoryPlanning.currentStock[fuelKey] =
            DEFAULT_STATION.inventoryPlanning.currentStock[fuelKey] || 0;
          changed = true;
        }
      }
      if (inventoryPlanning.deliveryLeadDays == null || Number.isNaN(inventoryPlanning.deliveryLeadDays)) {
        inventoryPlanning.deliveryLeadDays =
          DEFAULT_STATION.inventoryPlanning.deliveryLeadDays || 0;
        changed = true;
      }
      if (inventoryPlanning.alertBeforeDays == null || Number.isNaN(inventoryPlanning.alertBeforeDays)) {
        inventoryPlanning.alertBeforeDays =
          DEFAULT_STATION.inventoryPlanning.alertBeforeDays || 0;
        changed = true;
      }
      if (changed) {
        existing.pumps = pumps;
        existing.baseReadings = baseReadings;
        existing.meterLimits = meterLimits;
        existing.inventoryPlanning = inventoryPlanning;
        existing.salesmen = salesmen;
        await existing.save();
      }
      return existing;
    }
    const station = new Station(DEFAULT_STATION);
    await station.save();
    return station;
  }

  static async findById(id) {
    const normalizedId = String(id || '').trim();
    if (!normalizedId) {
      return null;
    }

    const cached = stationByIdCache.get(normalizedId);
    if (cached && cached.expiresAt > Date.now()) {
      return cloneStation(cached.station);
    }

    const station = Station.fromRecord(await getDataRecord(ENTITY_TYPE, normalizedId));
    if (!station) {
      stationByIdCache.delete(normalizedId);
      return null;
    }
    stationByIdCache.set(normalizedId, {
      expiresAt: Date.now() + STATION_CACHE_TTL_MS,
      station: cloneStation(station),
    });
    return cloneStation(station);
  }

  static async findAll() {
    if (stationsCache && stationsCache.expiresAt > Date.now()) {
      return cloneStations(stationsCache.stations);
    }

    const stations = (await listDataRecords(ENTITY_TYPE))
      .map((record) => Station.fromRecord(record))
      .filter(Boolean);
    stationsCache = {
      expiresAt: Date.now() + STATION_CACHE_TTL_MS,
      stations: cloneStations(stations),
    };
    for (const station of stations) {
      stationByIdCache.set(station.id, {
        expiresAt: Date.now() + STATION_CACHE_TTL_MS,
        station: cloneStation(station),
      });
    }
    return cloneStations(stations);
  }

  static invalidateCache(id = '') {
    const normalizedId = String(id || '').trim();
    if (normalizedId) {
      stationByIdCache.delete(normalizedId);
    }
    stationsCache = null;
  }

  toJson() {
    return {
      id: this.id,
      name: this.name,
      code: this.code,
      city: this.city,
      shifts: this.shifts,
      pumps: this.pumps,
      baseReadings: this.baseReadings,
      meterLimits: this.meterLimits,
      inventoryPlanning: this.inventoryPlanning,
      flagThreshold: this.flagThreshold,
      salesmen: this.salesmen,
    };
  }
}

module.exports = Station;
