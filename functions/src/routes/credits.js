const express = require('express');

const CreditTransaction = require('../models/CreditTransaction');
const {requireApproved, requireAuth} = require('../middleware/auth');
const {
  getCreditCustomerDetail,
  getCreditLedgerSummary,
  listCreditCustomers,
} = require('../services/creditLedger');
const {syncDailySalesSummaryForDate} = require('../services/analytics');
const {todayInStationTimeZone} = require('../utils/time');

const router = express.Router();

router.use(requireAuth, requireApproved);

router.get('/summary', async (req, res) => {
  const summary = await getCreditLedgerSummary(req.authUser.stationId, {
    from: req.query.from?.toString(),
    to: req.query.to?.toString(),
  });
  return res.status(200).json({summary});
});

router.get('/customers', async (req, res) => {
  const payload = await listCreditCustomers(req.authUser.stationId, {
    query: req.query.query?.toString(),
    status: req.query.status?.toString() || 'all',
    from: req.query.from?.toString(),
    to: req.query.to?.toString(),
  });
  return res.status(200).json(payload);
});

router.get('/customers/:customerId', async (req, res) => {
  const payload = await getCreditCustomerDetail(
    req.authUser.stationId,
    req.params.customerId,
    {
      from: req.query.from?.toString(),
      to: req.query.to?.toString(),
      type: req.query.type?.toString() || 'all',
    },
  );
  if (!payload) {
    return res.status(404).json({message: 'Credit customer not found'});
  }
  return res.status(200).json(payload);
});

router.post('/collections', async (req, res) => {
  let transaction;
  try {
    transaction = await CreditTransaction.recordStandaloneCollection({
      stationId: req.authUser.stationId,
      customerId: req.body?.customerId?.toString(),
      name: req.body?.name?.toString() || '',
      amount: req.body?.amount,
      date: req.body?.date?.toString() || todayInStationTimeZone(),
      paymentMode: req.body?.paymentMode?.toString() || '',
      createdBy: req.authUser._id,
      note: req.body?.note?.toString() || '',
    });
  } catch (error) {
    if (
      error instanceof Error &&
      (
        error.message.includes('Credit customer name') ||
        error.message.includes('Collection amount') ||
        error.message.includes('Collection date') ||
        error.message.includes('Collection payment mode')
      )
    ) {
      return res.status(400).json({message: error.message});
    }
    throw error;
  }
  await syncDailySalesSummaryForDate(
    req.authUser.stationId,
    transaction.date,
  );
  return res.status(201).json({transaction: transaction.toJson()});
});

module.exports = router;
