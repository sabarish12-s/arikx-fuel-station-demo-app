const User = require('../models/User');
const {sendFcmToTokens} = require('./fcm');

async function stationManagementUsers(stationId) {
  return (await User.find({stationId, status: 'approved'})).filter((user) =>
    ['admin', 'superadmin'].includes(user.role),
  );
}

async function sendSalesEntrySubmittedNotification({entry, station, submittedByName}) {
  const recipients = await stationManagementUsers(entry.stationId);
  const tokens = recipients.flatMap((user) => user.fcmTokens || []);
  return sendFcmToTokens(tokens, {
    notification: {
      title: 'Sales Entry Submitted',
      body: `${submittedByName || 'A staff member'} submitted ${entry.date} for ${station?.name || 'the station'}.`,
    },
    data: {
      type: 'sales_entry_submitted',
      stationId: entry.stationId,
      entryId: entry.id,
      date: entry.date,
    },
  });
}

async function sendFuelPriceUpdateRequestedNotification({request, station, requestedByName}) {
  const recipients = await stationManagementUsers(request.stationId);
  const tokens = recipients.flatMap((user) => user.fcmTokens || []);
  return sendFcmToTokens(tokens, {
    notification: {
      title: 'Fuel Price Update Requested',
      body: `${requestedByName || 'A staff member'} requested fuel price changes for ${request.effectiveDate}.`,
    },
    data: {
      type: 'fuel_price_update_requested',
      stationId: request.stationId,
      requestId: request.id,
      date: request.effectiveDate,
      stationName: station?.name || '',
    },
  });
}

async function sendInventoryReorderAlert({station, fuelItem}) {
  const recipients = await stationManagementUsers(station.id);
  const tokens = recipients.flatMap((user) => user.fcmTokens || []);
  return sendFcmToTokens(tokens, {
    notification: {
      title: `${fuelItem.label} Reorder Alert`,
      body: fuelItem.alertMessage,
    },
    data: {
      type: 'inventory_reorder_alert',
      stationId: station.id,
      fuelTypeId: fuelItem.fuelTypeId,
      recommendedOrderDate: fuelItem.recommendedOrderDate || '',
      projectedRunoutDate: fuelItem.projectedRunoutDate || '',
    },
  });
}

async function sendDailyFuelRecordUpdatedNotification({
  record,
  station,
  updatedByName,
}) {
  const recipients = await stationManagementUsers(record.stationId);
  const tokens = recipients.flatMap((user) => user.fcmTokens || []);
  return sendFcmToTokens(tokens, {
    notification: {
      title: 'Daily Fuel Register Updated',
      body: `${updatedByName || 'A staff member'} saved density for ${record.date} at ${station?.name || 'the station'}.`,
    },
    data: {
      type: 'daily_fuel_record_updated',
      stationId: record.stationId,
      date: record.date,
    },
  });
}

module.exports = {
  sendDailyFuelRecordUpdatedNotification,
  sendFuelPriceUpdateRequestedNotification,
  sendInventoryReorderAlert,
  sendSalesEntrySubmittedNotification,
};
