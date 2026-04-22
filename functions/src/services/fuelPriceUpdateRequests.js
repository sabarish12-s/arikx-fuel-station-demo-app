const FuelPriceUpdateRequest = require('../models/FuelPriceUpdateRequest');
const ShiftEntry = require('../models/ShiftEntry');
const StationDaySetup = require('../models/StationDaySetup');
const {getDaySetupState} = require('./daySetups');
const {nowIso} = require('../utils/time');

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

function normalizeFuelPrices(value = {}, fallback = {}) {
  return ['petrol', 'diesel', 'two_t_oil'].reduce((result, fuelTypeId) => {
    const source = value?.[fuelTypeId] || {};
    const fallbackSource = fallback?.[fuelTypeId] || {};
    result[fuelTypeId] = {
      costPrice: roundNumber(
        source.costPrice ?? fallbackSource.costPrice ?? 0,
      ),
      sellingPrice: roundNumber(
        source.sellingPrice ?? fallbackSource.sellingPrice ?? 0,
      ),
    };
    return result;
  }, {});
}

function hasAnyPriceChange(currentPrices = {}, requestedPrices = {}) {
  return ['petrol', 'diesel', 'two_t_oil'].some((fuelTypeId) => {
    const current = currentPrices[fuelTypeId] || {};
    const requested = requestedPrices[fuelTypeId] || {};
    return (
      roundNumber(current.costPrice) !== roundNumber(requested.costPrice) ||
      roundNumber(current.sellingPrice) !== roundNumber(requested.sellingPrice)
    );
  });
}

async function activeSetupForRequest(stationId, effectiveDate) {
  const normalizedDate = normalizeDateKey(effectiveDate);
  if (!normalizedDate) {
    throw new Error('Valid effective date is required.');
  }
  const state = await getDaySetupState(stationId);
  if (!state.setupExists) {
    throw new Error('Create a day setup before requesting fuel price changes.');
  }
  const setup = await StationDaySetup.latestActiveOnOrBefore(
    stationId,
    normalizedDate,
  );
  if (!setup) {
    throw new Error('No active day setup was found for this date.');
  }
  return setup;
}

async function createFuelPriceUpdateRequest({
  stationId,
  effectiveDate,
  fuelPrices,
  note = '',
  requestedBy = '',
  requestedByName = '',
}) {
  const normalizedDate = normalizeDateKey(effectiveDate);
  const setup = await activeSetupForRequest(stationId, normalizedDate);
  const currentPrices = normalizeFuelPrices(setup.fuelPrices);
  const requestedPrices = normalizeFuelPrices(fuelPrices, currentPrices);

  if (!hasAnyPriceChange(currentPrices, requestedPrices)) {
    throw new Error('Change at least one fuel price before submitting.');
  }

  const request = new FuelPriceUpdateRequest({
    stationId,
    effectiveDate: normalizedDate,
    currentPrices,
    requestedPrices,
    note,
    requestedBy,
    requestedByName,
  });
  return request.save();
}

async function listFuelPriceUpdateRequests({
  stationId,
  status = '',
  requestedBy = '',
} = {}) {
  const requests = await FuelPriceUpdateRequest.listForStation(stationId, {
    status,
  });
  const normalizedRequester = String(requestedBy || '').trim();
  if (!normalizedRequester) {
    return requests;
  }
  return requests.filter((request) => request.requestedBy === normalizedRequester);
}

async function approveFuelPriceUpdateRequest({
  stationId,
  requestId,
  reviewedBy = '',
  reviewedByName = '',
  reviewNote = '',
}) {
  const request = await FuelPriceUpdateRequest.findById(requestId);
  if (!request || request.stationId !== stationId) {
    return null;
  }
  if (request.status !== 'pending') {
    throw new Error('Only pending fuel price requests can be approved.');
  }

  const setup = await activeSetupForRequest(stationId, request.effectiveDate);
  setup.fuelPrices = normalizeFuelPrices(request.requestedPrices, setup.fuelPrices);
  setup.updatedBy = String(reviewedBy || '').trim();
  setup.updatedByName = String(reviewedByName || '').trim();
  await setup.save();

  request.status = 'approved';
  request.reviewedAt = nowIso();
  request.reviewedBy = String(reviewedBy || '').trim();
  request.reviewedByName = String(reviewedByName || '').trim();
  request.reviewNote = String(reviewNote || '').trim();
  await request.save();

  ShiftEntry.invalidateStationCache(stationId);
  await ShiftEntry.recomputeFrom(stationId, request.effectiveDate);
  return request;
}

async function rejectFuelPriceUpdateRequest({
  stationId,
  requestId,
  reviewedBy = '',
  reviewedByName = '',
  reviewNote = '',
}) {
  const request = await FuelPriceUpdateRequest.findById(requestId);
  if (!request || request.stationId !== stationId) {
    return null;
  }
  if (request.status !== 'pending') {
    throw new Error('Only pending fuel price requests can be rejected.');
  }
  request.status = 'rejected';
  request.reviewedAt = nowIso();
  request.reviewedBy = String(reviewedBy || '').trim();
  request.reviewedByName = String(reviewedByName || '').trim();
  request.reviewNote = String(reviewNote || '').trim();
  return request.save();
}

module.exports = {
  approveFuelPriceUpdateRequest,
  createFuelPriceUpdateRequest,
  listFuelPriceUpdateRequests,
  rejectFuelPriceUpdateRequest,
};
