const DeliveryReceipt = require('../models/DeliveryReceipt');
const InventoryAlertLog = require('../models/InventoryAlertLog');
const ShiftEntry = require('../models/ShiftEntry');
const Station = require('../models/Station');
const StationDaySetup = require('../models/StationDaySetup');
const {todayInStationTimeZone} = require('../utils/time');
const {sendInventoryReorderAlert} = require('./notifications');

function roundNumber(value) {
  return Math.round((Number(value || 0) + Number.EPSILON) * 100) / 100;
}

function normalizeStock(value = {}) {
  return {
    petrol: roundNumber(value.petrol),
    diesel: roundNumber(value.diesel),
    two_t_oil: roundNumber(value.two_t_oil),
  };
}

function isoDateToUtcDate(date) {
  const [year = '0', month = '1', day = '1'] = String(date || '').split('-');
  return new Date(Date.UTC(Number(year), Number(month) - 1, Number(day)));
}

function utcDateToIsoDate(date) {
  return `${date.getUTCFullYear()}-${String(date.getUTCMonth() + 1).padStart(2, '0')}-${String(
    date.getUTCDate(),
  ).padStart(2, '0')}`;
}

function shiftIsoDate(date, offsetDays) {
  const shifted = isoDateToUtcDate(date);
  shifted.setUTCDate(shifted.getUTCDate() + offsetDays);
  return utcDateToIsoDate(shifted);
}

function fuelLabel(fuelTypeId) {
  switch (fuelTypeId) {
    case 'petrol':
      return 'Petrol';
    case 'diesel':
      return 'Diesel';
    case 'two_t_oil':
      return '2T Oil';
    default:
      return fuelTypeId;
  }
}

function buildInventoryDashboardStation(station) {
  return {
    id: station?.id || '',
    name: station?.name || '',
  };
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
    String(left.date).localeCompare(String(right.date)),
  );
}

function inventoryFuelTotal(entry, fuelKey) {
  const inventoryTotals = entry?.inventoryTotals || {};
  const fallbackTotals = entry?.totals?.sold || {};
  return roundNumber(
    Number(
      inventoryTotals?.[fuelKey] ??
        fallbackTotals?.[fuelKey] ??
        0,
    ),
  );
}

function averageDailySales(entries, fuelKey, endDate = todayInStationTimeZone()) {
  const dailyMap = new Map();
  for (const entry of entries) {
    dailyMap.set(
      entry.date,
      roundNumber(
        Number(dailyMap.get(entry.date) || 0) +
          Number(inventoryFuelTotal(entry, fuelKey) || 0),
        ),
    );
  }
  const windowDates = Array.from({length: 7}, (_, index) => shiftIsoDate(endDate, -index)).reverse();
  const enteredDates = windowDates.filter((date) => dailyMap.has(date));
  if (enteredDates.length === 0) {
    return 0;
  }
  return roundNumber(
    enteredDates.reduce((sum, date) => sum + Number(dailyMap.get(date) || 0), 0) /
      enteredDates.length,
  );
}

function buildForecastItem({
  station,
  fuelTypeId,
  currentStock,
  averageSales,
  today,
}) {
  const leadDays = Math.max(0, Number(station.inventoryPlanning?.deliveryLeadDays || 0));
  const alertBeforeDays = Math.max(
    0,
    Number(station.inventoryPlanning?.alertBeforeDays || 0),
  );
  const label = fuelLabel(fuelTypeId);
  const daysRemaining =
    averageSales > 0 ? roundNumber(currentStock / averageSales) : null;
  const projectedRunoutDate =
    daysRemaining == null
      ? ''
      : shiftIsoDate(today, Math.max(0, Math.floor(daysRemaining)));
  const recommendedOrderDate =
    projectedRunoutDate
      ? shiftIsoDate(projectedRunoutDate, -(leadDays + alertBeforeDays))
      : '';
  const shouldAlert =
    averageSales > 0 && currentStock <= averageSales * (leadDays + alertBeforeDays);

  const alertMessage = shouldAlert
    ? `${label} stock is projected to run low. Order by ${recommendedOrderDate || today}.`
    : '';

  return {
    fuelTypeId,
    label,
    currentStock: roundNumber(currentStock),
    averageDailySales: roundNumber(averageSales),
    daysRemaining,
    projectedRunoutDate,
    recommendedOrderDate,
    shouldAlert,
    alertMessage,
  };
}

async function buildInventoryDashboard(stationId) {
  const station = await Station.findById(stationId);
  const today = todayInStationTimeZone();
  const activeSetup = await StationDaySetup.latestActiveOnOrBefore(stationId, today);
  const activeStock = normalizeStock(activeSetup?.startingStock || {});
  const activeDate = String(activeSetup?.effectiveDate || '').trim();
  const [entries, receipts] = await Promise.all([
    activeDate
      ? ShiftEntry.allForStationRange(stationId, {
          fromDate: activeDate,
          includePrevious: false,
        })
      : ShiftEntry.allForStation(stationId),
    activeDate
      ? DeliveryReceipt.allForStationRange(stationId, {
          fromDate: activeDate,
        })
      : DeliveryReceipt.allForStation(stationId),
  ]);
  const normalizedEntries = normalizeInventoryEntries(entries);
  const currentStock = {
    petrol: activeStock.petrol,
    diesel: activeStock.diesel,
    two_t_oil: activeStock.two_t_oil,
  };

  for (const receipt of receipts) {
    if (activeDate && String(receipt.date || '').localeCompare(activeDate) < 0) {
      continue;
    }
    if (String(receipt.date || '').localeCompare(today) > 0) {
      continue;
    }
    for (const fuelTypeId of ['petrol', 'diesel', 'two_t_oil']) {
      currentStock[fuelTypeId] = roundNumber(
        Number(currentStock[fuelTypeId] || 0) +
          Number(receipt.quantities?.[fuelTypeId] || 0),
      );
    }
  }

  for (const entry of normalizedEntries) {
    if (activeDate && String(entry.date || '').localeCompare(activeDate) < 0) {
      continue;
    }
    if (String(entry.date || '').localeCompare(today) > 0) {
      continue;
    }
    currentStock.petrol = roundNumber(
      Number(currentStock.petrol || 0) - Number(inventoryFuelTotal(entry, 'petrol') || 0),
    );
    currentStock.diesel = roundNumber(
      Number(currentStock.diesel || 0) - Number(inventoryFuelTotal(entry, 'diesel') || 0),
    );
    currentStock.two_t_oil = roundNumber(
      Number(currentStock.two_t_oil || 0) - Number(inventoryFuelTotal(entry, 'twoT') || 0),
    );
  }

  if (station?.inventoryPlanning) {
    station.inventoryPlanning = {
      ...station.inventoryPlanning,
      openingStock: activeStock,
      currentStock,
      updatedAt: String(activeSetup?.createdAt || '').trim(),
    };
  }

  const forecast = ['petrol', 'diesel', 'two_t_oil'].map((fuelTypeId) =>
    buildForecastItem({
      station,
      fuelTypeId,
      currentStock: currentStock[fuelTypeId] || 0,
      averageSales: averageDailySales(
        normalizedEntries,
        fuelTypeId === 'two_t_oil' ? 'twoT' : fuelTypeId,
        today,
      ),
      today,
    }),
  );

  return {
    station: buildInventoryDashboardStation(station),
    inventoryPlanning: {
      ...station.inventoryPlanning,
      openingStock: activeStock,
      currentStock,
    },
    activeStockSnapshot:
      activeSetup == null
        ? null
        : {
            id: activeSetup.id,
            effectiveDate: activeSetup.effectiveDate,
            stock: activeSetup.startingStock,
            note: activeSetup.note,
            createdAt: activeSetup.createdAt,
            createdBy: activeSetup.createdBy,
            createdByName: activeSetup.createdByName,
          },
    forecast,
    deliveries: receipts.slice(0, 1).map((receipt) => receipt.toSummaryJson()),
  };
}

async function runDailyReorderAlerts(runDate = todayInStationTimeZone()) {
  const stations = await Station.findAll();
  const sent = [];

  for (const station of stations) {
    const dashboard = await buildInventoryDashboard(station.id);
    for (const fuelItem of dashboard.forecast) {
      if (!fuelItem.shouldAlert) {
        continue;
      }
      if (await InventoryAlertLog.exists(station.id, fuelItem.fuelTypeId, runDate)) {
        continue;
      }
      await sendInventoryReorderAlert({station, fuelItem});
      await new InventoryAlertLog({
        id: InventoryAlertLog.idFor(station.id, fuelItem.fuelTypeId, runDate),
        stationId: station.id,
        fuelTypeId: fuelItem.fuelTypeId,
        date: runDate,
      }).save();
      sent.push({stationId: station.id, fuelTypeId: fuelItem.fuelTypeId});
    }
  }

  return {
    date: runDate,
    sent,
  };
}

module.exports = {
  buildInventoryDashboard,
  runDailyReorderAlerts,
};
