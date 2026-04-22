const express = require('express');

const ShiftEntry = require('../models/ShiftEntry');
const {requireAuth, requireApproved, requireManagement} = require('../middleware/auth');
const {
  getManagementDashboard,
  getMonthlyReport,
  syncDailySalesSummaryForDate,
} = require('../services/analytics');
const {syncInventoryLedgerForStation} = require('../services/inventoryLedger');

const router = express.Router();

router.use(requireAuth, requireApproved, requireManagement);

function isEntryValidationError(message = '') {
  return (
    message.includes('Mismatch reason') ||
    message.includes('Credit entry') ||
    message.includes('Pump credit total')
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
  const payload = await getManagementDashboard(req.authUser.stationId, {
    preset: req.query.preset?.toString(),
    fromDate: req.query.from?.toString(),
    toDate: req.query.to?.toString(),
  });
  return res.status(200).json(payload);
});

router.get('/entries', async (req, res) => {
  const month = req.query.month?.toString();
  const fromDate = req.query.from?.toString();
  const toDate = req.query.to?.toString();
  const approvedOnly = req.query.approvedOnly?.toString() === 'true';
  const summary = req.query.view?.toString() !== 'detail';
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
    if (String(entry.status || '').trim() === 'draft') {
      return false;
    }
    if (approvedOnly && !ShiftEntry.isFinalized(entry)) {
      return false;
    }
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

router.get('/entries/:entryId', async (req, res) => {
  const entry = await ShiftEntry.findById(req.params.entryId);
  if (!entry) {
    return res.status(404).json({message: 'Entry not found'});
  }
  if (entry.stationId !== req.authUser.stationId) {
    return res.status(403).json({message: 'Entry does not belong to this station'});
  }
  return res.status(200).json({entry: await ShiftEntry.toResolvedJson(entry)});
});

router.patch('/entries/:entryId', async (req, res) => {
  const entry = await ShiftEntry.findById(req.params.entryId);
  if (!entry) {
    return res.status(404).json({message: 'Entry not found'});
  }
  if (entry.stationId !== req.authUser.stationId) {
    return res.status(403).json({message: 'Entry does not belong to this station'});
  }
  const access = await ShiftEntry.getMutationAccess(entry, {
    role: req.authUser.role,
  });
  if (!access.canEdit) {
    return res.status(403).json({message: access.updateReason});
  }
  let updated;
  try {
    updated = await entry.updateByAdmin({
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
      reviewedBy: req.authUser._id,
    });
  } catch (error) {
    if (error instanceof Error && isEntryValidationError(error.message)) {
      return res.status(400).json({message: error.message});
    }
    throw error;
  }
  await Promise.all([
    syncInventoryLedgerForStation(req.authUser.stationId),
    ShiftEntry.isFinalized(updated)
      ? syncDailySalesSummaryForDate(req.authUser.stationId, updated.date)
      : Promise.resolve(null),
  ]);
  return res.status(200).json({entry: await ShiftEntry.toResolvedJson(updated)});
});

router.patch('/entries/:entryId/date', async (req, res) => {
  return res.status(403).json({
    message: 'Entry date changes are disabled when sequential day setup is enforced.',
  });
});

router.post('/entries/:entryId/approve', async (req, res) => {
  const entry = await ShiftEntry.findById(req.params.entryId);
  if (!entry) {
    return res.status(404).json({message: 'Entry not found'});
  }
  if (entry.stationId !== req.authUser.stationId) {
    return res.status(403).json({message: 'Entry does not belong to this station'});
  }
  const access = await ShiftEntry.getMutationAccess(entry, {
    role: req.authUser.role,
  });
  if (!access.canApprove) {
    return res.status(403).json({message: access.approveReason});
  }
  await entry.approve(req.authUser._id);
  await Promise.all([
    syncInventoryLedgerForStation(req.authUser.stationId),
    syncDailySalesSummaryForDate(req.authUser.stationId, entry.date),
  ]);
  return res.status(200).json({entry: await ShiftEntry.toResolvedJson(entry)});
});

router.delete('/entries/:entryId', async (req, res) => {
  const entry = await ShiftEntry.findById(req.params.entryId);
  if (!entry) {
    return res.status(404).json({message: 'Entry not found'});
  }
  if (entry.stationId !== req.authUser.stationId) {
    return res.status(403).json({message: 'Entry does not belong to this station'});
  }
  const access = await ShiftEntry.getMutationAccess(entry, {
    role: req.authUser.role,
  });
  if (ShiftEntry.isFinalized(entry)) {
    if (!access.canOverrideDelete) {
      return res.status(403).json({message: access.deleteReason});
    }
  } else if (!access.canDelete) {
    return res.status(403).json({message: access.deleteReason});
  }

  const deleted = await ShiftEntry.deleteOne(entry.id);
  await Promise.all([
    syncInventoryLedgerForStation(req.authUser.stationId),
    ShiftEntry.isFinalized(entry)
      ? syncDailySalesSummaryForDate(req.authUser.stationId, entry.date)
      : Promise.resolve(null),
  ]);
  return res.status(200).json({
    deleted: true,
    overrideApplied: ShiftEntry.isFinalized(entry),
    entry: await ShiftEntry.toResolvedJson(deleted),
  });
});

router.get('/reports/monthly', async (req, res) => {
  const month = req.query.month?.toString();
  const fromDate = req.query.from?.toString();
  const toDate = req.query.to?.toString();
  const report = await getMonthlyReport(req.authUser.stationId, {
    month,
    fromDate,
    toDate,
  });
  return res.status(200).json(report);
});

module.exports = router;
