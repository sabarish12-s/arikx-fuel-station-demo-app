const express = require('express');

const ShiftEntry = require('../models/ShiftEntry');
const Station = require('../models/Station');
const {requireApproved, requireAuth} = require('../middleware/auth');
const {
  getDailySummary,
  getSalesDashboard,
} = require('../services/analytics');
const {syncInventoryLedgerForStation} = require('../services/inventoryLedger');
const {sendSalesEntrySubmittedNotification} = require('../services/notifications');
const {todayInStationTimeZone} = require('../utils/time');

const router = express.Router();

router.use(requireAuth, requireApproved);

function isEntryValidationError(message = '') {
  return (
    message.includes('Mismatch reason') ||
    message.includes('Future dates') ||
    message.includes('Valid date') ||
    message.includes('Credit entry') ||
    message.includes('Pump credit total') ||
    message.includes('Sales entry is locked') ||
    message.includes('Create a day setup') ||
    message.includes('already submitted')
  );
}

function endOfMonthForMonthKey(month = '') {
  if (!/^\d{4}-\d{2}$/.test(month)) {
    return '';
  }
  const [year, monthNumber] = month.split('-').map((part) => Number(part));
  return new Date(Date.UTC(year, monthNumber, 0)).toISOString().split('T')[0];
}

router.get('/dashboard', async (req, res) => {
  const date = req.query.date?.toString() || todayInStationTimeZone();
  const payload = await getSalesDashboard(req.authUser.stationId, date);
  return res.status(200).json(payload);
});

router.post('/entries/preview', async (req, res) => {
  const date = req.body?.date?.toString() || todayInStationTimeZone();
  let preview;
  try {
    preview = await ShiftEntry.preview({
      stationId: req.authUser.stationId,
      date,
      closingReadings: req.body?.closingReadings || {},
      pumpSalesmen: req.body?.pumpSalesmen || {},
      pumpAttendants: req.body?.pumpAttendants || {},
      pumpTesting: req.body?.pumpTesting || {},
      pumpPayments: req.body?.pumpPayments || {},
      pumpCollections: req.body?.pumpCollections || {},
      paymentBreakdown: req.body?.paymentBreakdown || {},
      creditEntries: req.body?.creditEntries || [],
      creditCollections: req.body?.creditCollections || [],
      mismatchReason: req.body?.mismatchReason || '',
    });
  } catch (error) {
    if (error instanceof Error && isEntryValidationError(error.message)) {
      return res.status(400).json({message: error.message});
    }
    throw error;
  }

  return res.status(200).json({entry: await ShiftEntry.toResolvedJson(preview)});
});

router.post('/entries/draft', async (req, res) => {
  const date = req.body?.date?.toString() || todayInStationTimeZone();

  let entry;
  try {
    entry = await ShiftEntry.saveDraft({
      stationId: req.authUser.stationId,
      date,
      submittedBy: req.authUser._id,
      closingReadings: req.body?.closingReadings || {},
      pumpSalesmen: req.body?.pumpSalesmen || {},
      pumpAttendants: req.body?.pumpAttendants || {},
      pumpTesting: req.body?.pumpTesting || {},
      pumpPayments: req.body?.pumpPayments || {},
      pumpCollections: req.body?.pumpCollections || {},
      paymentBreakdown: req.body?.paymentBreakdown || {},
      creditEntries: req.body?.creditEntries || [],
      creditCollections: req.body?.creditCollections || [],
      mismatchReason: req.body?.mismatchReason || '',
    });
  } catch (error) {
    if (error instanceof Error && isEntryValidationError(error.message)) {
      return res.status(400).json({message: error.message});
    }
    throw error;
  }

  return res.status(200).json({entry: await ShiftEntry.toResolvedJson(entry)});
});

router.post('/entries', async (req, res) => {
  const date = req.body?.date?.toString() || todayInStationTimeZone();

  let entry;
  try {
    entry = await ShiftEntry.create({
      stationId: req.authUser.stationId,
      date,
      submittedBy: req.authUser._id,
      closingReadings: req.body?.closingReadings || {},
      pumpSalesmen: req.body?.pumpSalesmen || {},
      pumpAttendants: req.body?.pumpAttendants || {},
      pumpTesting: req.body?.pumpTesting || {},
      pumpPayments: req.body?.pumpPayments || {},
      pumpCollections: req.body?.pumpCollections || {},
      paymentBreakdown: req.body?.paymentBreakdown || {},
      creditEntries: req.body?.creditEntries || [],
      creditCollections: req.body?.creditCollections || [],
      mismatchReason: req.body?.mismatchReason || '',
    });
  } catch (error) {
    if (
      error instanceof Error &&
      (error.message.includes('already exists') || isEntryValidationError(error.message))
    ) {
      const statusCode = error.message.includes('already exists') ? 409 : 400;
      return res.status(statusCode).json({message: error.message});
    }
    throw error;
  }

  try {
    const station = await Station.findById(req.authUser.stationId);
    await sendSalesEntrySubmittedNotification({
      entry,
      station,
      submittedByName: req.authUser.name,
    });
  } catch (notifyError) {
    console.error('Sales entry notification failed:', notifyError.message);
  }

  await syncInventoryLedgerForStation(req.authUser.stationId);

  return res.status(201).json({entry: await ShiftEntry.toResolvedJson(entry)});
});

router.get('/entries/:entryId', async (req, res) => {
  const entry = await ShiftEntry.findById(req.params.entryId);
  if (!entry) {
    return res.status(404).json({message: 'Entry not found'});
  }
  if (entry.stationId !== req.authUser.stationId) {
    return res.status(403).json({message: 'Entry does not belong to this station'});
  }
  return res.status(200).json({
    entry: await ShiftEntry.toResolvedJson(entry),
  });
});

router.patch('/entries/:entryId', async (req, res) => {
  const entry = await ShiftEntry.findById(req.params.entryId);
  if (!entry) {
    return res.status(404).json({message: 'Entry not found'});
  }
  if (entry.stationId !== req.authUser.stationId) {
    return res.status(403).json({message: 'Entry does not belong to this station'});
  }
  if (entry.approvedAt || entry.status === 'approved') {
    return res.status(403).json({message: 'Approved entries cannot be edited from sales.'});
  }

  let updated;
  const wasDraft = String(entry.status || '').trim() === 'draft';
  try {
    updated = await entry.updateBySales({
      closingReadings: req.body?.closingReadings || {},
      pumpSalesmen: req.body?.pumpSalesmen || {},
      pumpAttendants: req.body?.pumpAttendants || {},
      pumpTesting: req.body?.pumpTesting || {},
      pumpPayments: req.body?.pumpPayments || {},
      pumpCollections: req.body?.pumpCollections || {},
      paymentBreakdown: req.body?.paymentBreakdown || {},
      creditEntries: req.body?.creditEntries || [],
      creditCollections: req.body?.creditCollections || [],
      mismatchReason: req.body?.mismatchReason || '',
      submittedBy: req.authUser._id,
    });
  } catch (error) {
    if (
      error instanceof Error &&
      (error.message.includes('Approved entries cannot be edited') || isEntryValidationError(error.message))
    ) {
      const statusCode = error.message.includes('Approved entries cannot be edited') ? 403 : 400;
      return res.status(statusCode).json({message: error.message});
    }
    throw error;
  }

  if (wasDraft) {
    try {
      const station = await Station.findById(req.authUser.stationId);
      await sendSalesEntrySubmittedNotification({
        entry: updated,
        station,
        submittedByName: req.authUser.name,
      });
    } catch (notifyError) {
      console.error('Sales entry notification failed:', notifyError.message);
    }
  }

  await syncInventoryLedgerForStation(req.authUser.stationId);

  return res.status(200).json({entry: await ShiftEntry.toResolvedJson(updated)});
});

router.get('/entries', async (req, res) => {
  const month = req.query.month?.toString();
  const fromDate = req.query.from?.toString();
  const toDate = req.query.to?.toString();
  const summary = req.query.view?.toString() === 'summary';
  const rangeFromDate = fromDate || (month ? `${month}-01` : '');
  const rangeToDate = toDate || (month ? endOfMonthForMonthKey(month) : '');
  const entries = (rangeFromDate || rangeToDate)
    ? await ShiftEntry.allForStationRange(req.authUser.stationId, {
        fromDate: rangeFromDate,
        toDate: rangeToDate,
      })
    : await ShiftEntry.allForStation(req.authUser.stationId);
  const filtered = entries.filter((entry) => {
    const date = String(entry.date || '');
    if (month && !date.startsWith(month)) {
      return false;
    }
    if (fromDate && date < fromDate) {
      return false;
    }
    if (toDate && date > toDate) {
      return false;
    }
    return true;
  });
  return res.status(200).json({
    entries: await ShiftEntry.toResolvedJsonList(filtered, {summary}),
  });
});

router.get('/summary/daily', async (req, res) => {
  const date = req.query.date?.toString() || todayInStationTimeZone();
  const summary = await getDailySummary(req.authUser.stationId, date);
  return res.status(200).json(summary);
});

module.exports = router;
