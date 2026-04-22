const STATION_TIME_ZONE = 'Asia/Kolkata';
const SHIFT_ORDER = ['morning', 'afternoon', 'night'];

function toDate(value) {
  if (!value) {
    return null;
  }
  if (value instanceof Date) {
    return value;
  }
  if (typeof value?.toDate === 'function') {
    return value.toDate();
  }
  return new Date(value);
}

function nowIso() {
  return new Date().toISOString();
}

function todayInStationTimeZone() {
  const formatter = new Intl.DateTimeFormat('en-CA', {
    timeZone: STATION_TIME_ZONE,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  });
  return formatter.format(new Date());
}

function currentMonthInStationTimeZone() {
  return todayInStationTimeZone().slice(0, 7);
}

function shiftIndex(shift) {
  const index = SHIFT_ORDER.indexOf(shift);
  return index === -1 ? SHIFT_ORDER.length : index;
}

function compareShiftEntries(a, b) {
  const dateCompare = String(a.date).localeCompare(String(b.date));
  if (dateCompare !== 0) {
    return dateCompare;
  }
  return shiftIndex(a.shift) - shiftIndex(b.shift);
}

function isLaterOrSame(entry, date, shift) {
  const dateCompare = String(entry.date).localeCompare(String(date));
  if (dateCompare > 0) {
    return true;
  }
  if (dateCompare < 0) {
    return false;
  }
  return shiftIndex(entry.shift) >= shiftIndex(shift);
}

module.exports = {
  SHIFT_ORDER,
  STATION_TIME_ZONE,
  compareShiftEntries,
  currentMonthInStationTimeZone,
  isLaterOrSame,
  nowIso,
  shiftIndex,
  toDate,
  todayInStationTimeZone,
};
