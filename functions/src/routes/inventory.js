const express = require('express');

const {inventoryAlertRunToken} = require('../config/env');
const DeliveryReceipt = require('../models/DeliveryReceipt');
const FuelPrice = require('../models/FuelPrice');
const FuelType = require('../models/FuelType');
const ShiftEntry = require('../models/ShiftEntry');
const Station = require('../models/Station');
const {listInventoryLedger, syncInventoryLedgerForStation} = require('../services/inventoryLedger');
const {buildInventoryDashboard, runDailyReorderAlerts} = require('../services/inventoryPlanning');
const {
  requireManagement,
  requireApproved,
  requireAuth,
  requireSuperAdmin,
} = require('../middleware/auth');
const {
  createStockSnapshot,
  deleteStockSnapshot,
  listStockSnapshotsForStation,
} = require('../services/inventoryStockSnapshots');
const {
  createOpeningReadingLog,
  deleteOpeningReadingLog,
  listOpeningReadingLogsForStation,
} = require('../services/pumpOpeningReadings');
const {
  createOrUpdateDaySetup,
  deleteDaySetup,
  getDaySetupState,
  listDaySetupHistory,
  resetOperationalDataForStation,
} = require('../services/daySetups');
const {
  approveFuelPriceUpdateRequest,
  createFuelPriceUpdateRequest,
  listFuelPriceUpdateRequests,
  rejectFuelPriceUpdateRequest,
} = require('../services/fuelPriceUpdateRequests');
const {
  sendFuelPriceUpdateRequestedNotification,
  sendDailyFuelRecordUpdatedNotification,
} = require('../services/notifications');
const {todayInStationTimeZone} = require('../utils/time');
const {
  getDailyFuelRecordForDate,
  listDailyFuelRecordsForStation,
  saveDailyFuelRecord,
} = require('../services/dailyFuelRecords');

const router = express.Router();

router.post('/reorder-alerts/run', async (req, res) => {
  if (
    !inventoryAlertRunToken ||
    req.headers['x-inventory-alert-token'] !== inventoryAlertRunToken
  ) {
    return res.status(401).json({message: 'Invalid alert run token'});
  }
  const result = await runDailyReorderAlerts();
  return res.status(200).json(result);
});

router.use(requireAuth, requireApproved);

router.get('/day-setup/state', async (req, res) => {
  const [state, history] = await Promise.all([
    getDaySetupState(req.authUser.stationId),
    listDaySetupHistory(req.authUser.stationId),
  ]);
  return res.status(200).json({
    ...state,
    setups: history.map((setup) => setup.toJson()),
  });
});

router.get('/daily-fuel/current', async (req, res) => {
  try {
    const requestedDate = req.query.date?.toString().trim();
    const targetDate =
      requestedDate ||
      (await ShiftEntry.getEntryAccessState(req.authUser.stationId)).allowedEntryDate ||
      todayInStationTimeZone();
    const record = await getDailyFuelRecordForDate(req.authUser.stationId, targetDate);
    return res.status(200).json({record});
  } catch (error) {
    if (error instanceof Error) {
      return res.status(400).json({message: error.message});
    }
    throw error;
  }
});

router.get('/daily-fuel', async (req, res) => {
  try {
    const records = await listDailyFuelRecordsForStation(req.authUser.stationId, {
      fromDate: req.query.from?.toString() || '',
      toDate: req.query.to?.toString() || '',
    });
    return res.status(200).json({records});
  } catch (error) {
    if (error instanceof Error) {
      return res.status(400).json({message: error.message});
    }
    throw error;
  }
});

router.put('/daily-fuel', async (req, res) => {
  let result;
  try {
    result = await saveDailyFuelRecord({
      stationId: req.authUser.stationId,
      date: req.body?.date?.toString() || '',
      density: req.body?.density || {},
      updatedBy: req.authUser._id,
      updatedByName: req.authUser.name?.toString() || '',
    });
  } catch (error) {
    if (error instanceof Error) {
      return res.status(400).json({message: error.message});
    }
    throw error;
  }

  if (req.authUser.role === 'sales') {
    try {
      const station = await Station.findById(req.authUser.stationId);
      await sendDailyFuelRecordUpdatedNotification({
        record: result.record,
        station,
        updatedByName: req.authUser.name,
      });
    } catch (notifyError) {
      console.error('Daily fuel register notification failed:', notifyError.message);
    }
  }

  return res.status(200).json({
    created: result.created,
    record: result.resolved,
  });
});

router.get('/day-setup', async (req, res) => {
  const setups = await listDaySetupHistory(req.authUser.stationId, {
    fromDate: req.query.from?.toString() || '',
    toDate: req.query.to?.toString() || '',
    deletedOnly: req.query.view?.toString() === 'deleted',
  });
  return res.status(200).json({
    setups: setups.map((setup) => setup.toJson()),
  });
});

router.put('/day-setup', requireSuperAdmin, async (req, res) => {
  let setup;
  try {
    setup = await createOrUpdateDaySetup({
      stationId: req.authUser.stationId,
      effectiveDate: req.body?.effectiveDate?.toString() || '',
      openingReadings: req.body?.openingReadings || {},
      startingStock: req.body?.startingStock || {},
      fuelPrices: req.body?.fuelPrices || {},
      note: req.body?.note?.toString() || '',
      actorId: req.authUser._id,
      actorName: req.authUser.name?.toString() || '',
    });
  } catch (error) {
    if (error instanceof Error) {
      return res.status(400).json({message: error.message});
    }
    throw error;
  }
  await syncInventoryLedgerForStation(req.authUser.stationId);
  return res.status(200).json({setup: setup.toJson()});
});

router.delete('/day-setup/:effectiveDate', requireSuperAdmin, async (req, res) => {
  let setup;
  try {
    setup = await deleteDaySetup({
      stationId: req.authUser.stationId,
      effectiveDate: req.params.effectiveDate,
      deletedBy: req.authUser._id,
      deletedByName: req.authUser.name?.toString() || '',
    });
  } catch (error) {
    if (error instanceof Error) {
      return res.status(400).json({message: error.message});
    }
    throw error;
  }
  if (!setup) {
    return res.status(404).json({message: 'Day setup not found'});
  }
  await syncInventoryLedgerForStation(req.authUser.stationId);
  return res.status(200).json({setup: setup.toJson()});
});

router.post('/day-setup/reset-operational-data', requireSuperAdmin, async (req, res) => {
  if (req.body?.confirm?.toString() !== 'RESET_OPERATIONAL_DATA') {
    return res.status(400).json({message: 'Confirmation token is required.'});
  }
  const result = await resetOperationalDataForStation(req.authUser.stationId);
  await syncInventoryLedgerForStation(req.authUser.stationId);
  return res.status(200).json({deleted: result});
});

router.get('/dashboard', async (req, res) => {
  const payload = await buildInventoryDashboard(req.authUser.stationId);
  return res.status(200).json(payload);
});

router.get('/deliveries', async (req, res) => {
  const summary = req.query.view?.toString() !== 'detail';
  const deliveries = await DeliveryReceipt.allForStation(req.authUser.stationId);
  return res.status(200).json({
    deliveries: deliveries.map((receipt) => (summary ? receipt.toSummaryJson() : receipt.toJson())),
  });
});

router.get('/ledger', async (req, res) => {
  let entries = await listInventoryLedger(req.authUser.stationId, {
    fromDate: req.query.from?.toString() || '',
    toDate: req.query.to?.toString() || '',
  });
  if (entries.length === 0) {
    await syncInventoryLedgerForStation(req.authUser.stationId);
    entries = await listInventoryLedger(req.authUser.stationId, {
      fromDate: req.query.from?.toString() || '',
      toDate: req.query.to?.toString() || '',
    });
  }
  return res.status(200).json({
    entries: entries.map((entry) => entry.toJson()),
  });
});

router.get('/stock-snapshots', async (req, res) => {
  const snapshots = await listStockSnapshotsForStation(req.authUser.stationId, {
    fromDate: req.query.from?.toString() || '',
    toDate: req.query.to?.toString() || '',
    deletedOnly: req.query.view?.toString() === 'deleted',
  });
  return res.status(200).json({
    snapshots: snapshots.map((snapshot) => snapshot.toJson()),
  });
});

router.post('/stock-snapshots', requireManagement, async (req, res) => {
  let snapshot;
  try {
    snapshot = await createStockSnapshot({
      stationId: req.authUser.stationId,
      effectiveDate: req.body?.effectiveDate?.toString() || '',
      stock: req.body?.stock || {},
      note: req.body?.note?.toString() || '',
      createdBy: req.authUser._id,
      createdByName: req.authUser.name?.toString() || '',
    });
  } catch (error) {
    if (error instanceof Error) {
      return res.status(400).json({message: error.message});
    }
    throw error;
  }
  await syncInventoryLedgerForStation(req.authUser.stationId);
  return res.status(201).json({snapshot: snapshot.toJson()});
});

router.delete('/stock-snapshots/:snapshotId', requireManagement, async (req, res) => {
  const snapshot = await deleteStockSnapshot({
    stationId: req.authUser.stationId,
    snapshotId: req.params.snapshotId,
    deletedBy: req.authUser._id,
    deletedByName: req.authUser.name?.toString() || '',
  });
  if (!snapshot) {
    return res.status(404).json({message: 'Stock history not found'});
  }
  await syncInventoryLedgerForStation(req.authUser.stationId);
  return res.status(200).json({snapshot: snapshot.toJson()});
});

router.get('/opening-readings', async (req, res) => {
  const logs = await listOpeningReadingLogsForStation(req.authUser.stationId, {
    fromDate: req.query.from?.toString() || '',
    toDate: req.query.to?.toString() || '',
    deletedOnly: req.query.view?.toString() === 'deleted',
  });
  return res.status(200).json({
    logs: logs.map((log) => log.toJson()),
  });
});

router.post('/opening-readings', requireManagement, async (req, res) => {
  let log;
  try {
    log = await createOpeningReadingLog({
      stationId: req.authUser.stationId,
      effectiveDate: req.body?.effectiveDate?.toString() || '',
      readings: req.body?.readings || {},
      note: req.body?.note?.toString() || '',
      createdBy: req.authUser._id,
      createdByName: req.authUser.name?.toString() || '',
    });
  } catch (error) {
    if (error instanceof Error) {
      return res.status(400).json({message: error.message});
    }
    throw error;
  }
  await syncInventoryLedgerForStation(req.authUser.stationId);
  return res.status(201).json({log: log.toJson()});
});

router.delete('/opening-readings/:logId', requireManagement, async (req, res) => {
  const log = await deleteOpeningReadingLog({
    stationId: req.authUser.stationId,
    logId: req.params.logId,
    deletedBy: req.authUser._id,
    deletedByName: req.authUser.name?.toString() || '',
  });
  if (!log) {
    return res.status(404).json({message: 'Opening reading history not found'});
  }
  await syncInventoryLedgerForStation(req.authUser.stationId);
  return res.status(200).json({log: log.toJson()});
});

router.post('/deliveries', async (req, res) => {
  let delivery;
  try {
    delivery = await DeliveryReceipt.create({
      stationId: req.authUser.stationId,
      fuelTypeId: req.body?.fuelTypeId,
      date: req.body?.date?.toString() || '',
      quantity: req.body?.quantity,
      quantities: req.body?.quantities,
      purchasedByName: req.authUser.name?.toString() || '',
      note: req.body?.note?.toString() || '',
      createdBy: req.authUser._id,
    });
  } catch (error) {
    if (error instanceof Error) {
      return res.status(400).json({message: error.message});
    }
    throw error;
  }
  await syncInventoryLedgerForStation(req.authUser.stationId);
  return res.status(201).json({delivery: delivery.toJson()});
});

router.get('/fuel-types', async (_req, res) => {
  const fuelTypes = await FuelType.findAll();
  return res.status(200).json({
    fuelTypes: fuelTypes.map((fuelType) => fuelType.toJson()),
  });
});

router.post('/fuel-types', async (req, res) => {
  if (!['admin', 'superadmin'].includes(req.authUser.role)) {
    return res.status(403).json({message: 'Management access required'});
  }
  const fuelType = await new FuelType(req.body || {}).save();
  return res.status(201).json({fuelType: fuelType.toJson()});
});

router.patch('/fuel-types/:fuelTypeId', async (req, res) => {
  if (!['admin', 'superadmin'].includes(req.authUser.role)) {
    return res.status(403).json({message: 'Management access required'});
  }
  const existing = await FuelType.findById(req.params.fuelTypeId);
  if (!existing) {
    return res.status(404).json({message: 'Fuel type not found'});
  }
  Object.assign(existing, req.body || {});
  const saved = await existing.save();
  return res.status(200).json({fuelType: saved.toJson()});
});

router.delete('/fuel-types/:fuelTypeId', async (req, res) => {
  if (!['admin', 'superadmin'].includes(req.authUser.role)) {
    return res.status(403).json({message: 'Management access required'});
  }
  const success = await FuelType.deleteById(req.params.fuelTypeId);
  if (!success) {
    return res.status(404).json({message: 'Fuel type not found'});
  }
  return res.status(200).json({deleted: true});
});

router.get('/prices', async (_req, res) => {
  const activeOnly = _req.query.view?.toString() === 'active';
  const prices = await FuelPrice.purgeExpiredDeletedPeriods();
  return res.status(200).json({
    prices: prices.map((price) => (activeOnly
      ? {
          fuelTypeId: price.fuelTypeId,
          costPrice: price.costPrice,
          sellingPrice: price.sellingPrice,
          updatedAt: price.updatedAt,
          effectiveFrom: price.effectiveFrom,
          effectiveTo: price.effectiveTo,
          periodCount: Array.isArray(price.periods)
            ? price.periods.filter((period) => !String(period?.deletedAt || '').trim()).length
            : 0,
        }
      : price.toJson())),
  });
});

router.delete('/prices/sets/:effectiveDate', requireManagement, async (req, res) => {
  let prices;
  try {
    prices = await FuelPrice.deleteSet({
      effectiveDate: req.params.effectiveDate,
      deletedBy: req.authUser._id,
      deletedByName: req.authUser.name?.toString() || '',
    });
  } catch (error) {
    if (error instanceof Error) {
      return res.status(400).json({message: error.message});
    }
    throw error;
  }
  if (!prices) {
    return res.status(404).json({message: 'Fuel price history not found'});
  }
  return res.status(200).json({prices: prices.map((price) => price.toJson())});
});

router.get('/price-update-requests', async (req, res) => {
  const isManagement = ['admin', 'superadmin'].includes(req.authUser.role);
  const status = req.query.status?.toString() || '';
  const requests = await listFuelPriceUpdateRequests({
    stationId: req.authUser.stationId,
    status,
    requestedBy: isManagement ? '' : req.authUser._id,
  });
  return res.status(200).json({
    requests: requests.map((request) => request.toJson()),
  });
});

router.post('/price-update-requests', async (req, res) => {
  let request;
  try {
    request = await createFuelPriceUpdateRequest({
      stationId: req.authUser.stationId,
      effectiveDate: req.body?.effectiveDate?.toString() || '',
      fuelPrices: req.body?.fuelPrices || {},
      note: req.body?.note?.toString() || '',
      requestedBy: req.authUser._id,
      requestedByName: req.authUser.name?.toString() || '',
    });
  } catch (error) {
    if (error instanceof Error) {
      return res.status(400).json({message: error.message});
    }
    throw error;
  }

  try {
    const station = await Station.findById(req.authUser.stationId);
    await sendFuelPriceUpdateRequestedNotification({
      request,
      station,
      requestedByName: req.authUser.name,
    });
  } catch (notifyError) {
    console.error('Fuel price update notification failed:', notifyError.message);
  }

  return res.status(201).json({request: request.toJson()});
});

router.post('/price-update-requests/:requestId/approve', requireSuperAdmin, async (req, res) => {
  let request;
  try {
    request = await approveFuelPriceUpdateRequest({
      stationId: req.authUser.stationId,
      requestId: req.params.requestId,
      reviewedBy: req.authUser._id,
      reviewedByName: req.authUser.name?.toString() || '',
      reviewNote: req.body?.note?.toString() || '',
    });
  } catch (error) {
    if (error instanceof Error) {
      return res.status(400).json({message: error.message});
    }
    throw error;
  }
  if (!request) {
    return res.status(404).json({message: 'Fuel price request not found'});
  }
  await syncInventoryLedgerForStation(req.authUser.stationId);
  return res.status(200).json({request: request.toJson()});
});

router.post('/price-update-requests/:requestId/reject', requireManagement, async (req, res) => {
  let request;
  try {
    request = await rejectFuelPriceUpdateRequest({
      stationId: req.authUser.stationId,
      requestId: req.params.requestId,
      reviewedBy: req.authUser._id,
      reviewedByName: req.authUser.name?.toString() || '',
      reviewNote: req.body?.note?.toString() || '',
    });
  } catch (error) {
    if (error instanceof Error) {
      return res.status(400).json({message: error.message});
    }
    throw error;
  }
  if (!request) {
    return res.status(404).json({message: 'Fuel price request not found'});
  }
  return res.status(200).json({request: request.toJson()});
});

router.put('/prices', async (req, res) => {
  if (!['admin', 'superadmin'].includes(req.authUser.role)) {
    return res.status(403).json({message: 'Management access required'});
  }
  const items = Array.isArray(req.body?.prices) ? req.body.prices : [];
  const saved = [];
  const updatedAt = nowIso();
  for (const item of items) {
    const price = new FuelPrice({
      fuelTypeId: item.fuelTypeId,
      costPrice: item.costPrice,
      sellingPrice: item.sellingPrice,
      effectiveFrom: item.effectiveFrom,
      effectiveTo: item.effectiveTo,
      periods: (Array.isArray(item.periods) ? item.periods : []).map((period) => ({
        ...period,
        updatedAt: period.updatedAt || updatedAt,
        updatedBy: period.updatedBy || req.authUser._id,
      })),
      updatedAt,
      updatedBy: req.authUser._id,
    });
    await price.save();
    saved.push(price);
  }
  return res.status(200).json({prices: saved.map((price) => price.toJson())});
});

router.get('/station-config', async (req, res) => {
  const station = await Station.findById(req.authUser.stationId);
  return res.status(200).json({station: station?.toJson() || null});
});

router.put('/station-config', async (req, res) => {
  const isManagement = ['admin', 'superadmin'].includes(req.authUser.role);
  const station = await Station.findById(req.authUser.stationId);
  if (!station) {
    return res.status(404).json({message: 'Station not found'});
  }

  if (!isManagement) {
    const allowedKeys = new Set(['salesmen']);
    const requestedKeys = Object.keys(req.body || {});
    const hasDisallowedKeys = requestedKeys.some((key) => !allowedKeys.has(key));
    if (hasDisallowedKeys) {
      return res.status(403).json({message: 'Only salesman settings can be updated from this account'});
    }
  }

  const previousBaseReadings = JSON.stringify(station.baseReadings || {});
  if (isManagement) {
    station.name = req.body?.name?.toString().trim() || station.name;
    station.code = req.body?.code?.toString().trim() || station.code;
    station.city = req.body?.city?.toString().trim() || station.city;
  }

  station.shifts = ['daily'];

  if (isManagement && Array.isArray(req.body?.pumps) && req.body.pumps.length > 0) {
    const labelById = new Map(
      req.body.pumps.map((pump) => [String(pump?.id || ''), String(pump?.label || '')]),
    );
    station.pumps = station.pumps.map((pump) => ({
      ...pump,
      label: labelById.get(String(pump.id)) || String(pump.label || ''),
    }));
  }

  if (isManagement && req.body?.meterLimits && typeof req.body.meterLimits === 'object') {
    station.meterLimits = station.pumps.reduce((accumulator, pump) => {
      const source = req.body.meterLimits?.[pump.id] || {};
      accumulator[pump.id] = {
        petrol: Number(source.petrol || 0),
        diesel: Number(source.diesel || 0),
        twoT: Number(source.twoT || 0),
      };
      return accumulator;
    }, {});
  }

  if (isManagement && req.body?.baseReadings && typeof req.body.baseReadings === 'object') {
    station.baseReadings = station.pumps.reduce((accumulator, pump) => {
      const source = req.body.baseReadings?.[pump.id] || {};
      accumulator[pump.id] = {
        petrol: Number(source.petrol || 0),
        diesel: Number(source.diesel || 0),
        twoT: Number(source.twoT || 0),
      };
      return accumulator;
    }, {});
  }

  if (isManagement && req.body?.flagThreshold != null) {
    const threshold = Number(req.body.flagThreshold);
    if (!Number.isNaN(threshold) && threshold >= 0) {
      station.flagThreshold = threshold;
    }
  }

  if (isManagement && req.body?.inventoryPlanning && typeof req.body.inventoryPlanning === 'object') {
    const planning = req.body.inventoryPlanning;
    station.inventoryPlanning = {
      ...station.inventoryPlanning,
      deliveryLeadDays: Math.max(0, Number(planning.deliveryLeadDays || 0)),
      alertBeforeDays: Math.max(0, Number(planning.alertBeforeDays || 0)),
    };
  }

  if (Array.isArray(req.body?.salesmen)) {
    station.salesmen = req.body.salesmen;
  }

  try {
    await station.save();
  } catch (error) {
    if (error instanceof Error) {
      return res.status(400).json({message: error.message});
    }
    throw error;
  }

  if (previousBaseReadings !== JSON.stringify(station.baseReadings || {})) {
    await ShiftEntry.recomputeFrom(station.id, '0000-00-00');
  }
  await syncInventoryLedgerForStation(station.id);

  return res.status(200).json({station: station.toJson()});
});

module.exports = router;
