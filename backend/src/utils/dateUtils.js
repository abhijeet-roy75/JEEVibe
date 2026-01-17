/**
 * Date Utilities for Indian Standard Time (IST)
 *
 * All date/time operations should use IST (UTC+5:30) for Indian students.
 */

const IST_OFFSET_HOURS = 5.5; // IST is UTC+5:30
const IST_OFFSET_MS = IST_OFFSET_HOURS * 60 * 60 * 1000;

/**
 * Get current date/time in IST
 * @returns {Date} Current time adjusted to IST
 */
function getNowIST() {
  const now = new Date();
  return new Date(now.getTime() + IST_OFFSET_MS);
}

/**
 * Convert a UTC date to IST
 * @param {Date} utcDate - Date in UTC
 * @returns {Date} Date adjusted to IST
 */
function toIST(utcDate) {
  return new Date(utcDate.getTime() + IST_OFFSET_MS);
}

/**
 * Get today's date string in IST (YYYY-MM-DD)
 * @returns {string} Today's date in IST
 */
function getTodayIST() {
  const ist = getNowIST();
  return formatDateIST(ist);
}

/**
 * Get yesterday's date string in IST (YYYY-MM-DD)
 * @returns {string} Yesterday's date in IST
 */
function getYesterdayIST() {
  const ist = getNowIST();
  ist.setDate(ist.getDate() - 1);
  return formatDateIST(ist);
}

/**
 * Format a date to YYYY-MM-DD string (using IST components)
 * @param {Date} date - Date object (should already be in IST)
 * @returns {string} Formatted date string
 */
function formatDateIST(date) {
  const year = date.getUTCFullYear();
  const month = String(date.getUTCMonth() + 1).padStart(2, '0');
  const day = String(date.getUTCDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
}

/**
 * Get start of day in IST as UTC timestamp
 * @param {Date} [date] - Optional date (defaults to now)
 * @returns {Date} Start of day in IST, as UTC Date
 */
function getStartOfDayIST(date = new Date()) {
  const ist = toIST(date);
  // Set to start of day in IST
  ist.setUTCHours(0, 0, 0, 0);
  // Convert back to UTC
  return new Date(ist.getTime() - IST_OFFSET_MS);
}

/**
 * Get end of day in IST as UTC timestamp
 * @param {Date} [date] - Optional date (defaults to now)
 * @returns {Date} End of day in IST, as UTC Date
 */
function getEndOfDayIST(date = new Date()) {
  const ist = toIST(date);
  // Set to end of day in IST
  ist.setUTCHours(23, 59, 59, 999);
  // Convert back to UTC
  return new Date(ist.getTime() - IST_OFFSET_MS);
}

/**
 * Get day of week in IST (0 = Sunday, 6 = Saturday)
 * @param {Date} [date] - Optional date (defaults to now)
 * @returns {number} Day of week
 */
function getDayOfWeekIST(date = new Date()) {
  const ist = toIST(date);
  return ist.getUTCDay();
}

/**
 * Get day name in IST
 * @param {Date} [date] - Optional date (defaults to now)
 * @returns {string} Day name (Sun, Mon, etc.)
 */
function getDayNameIST(date = new Date()) {
  const dayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  return dayNames[getDayOfWeekIST(date)];
}

/**
 * Check if a UTC timestamp falls on today in IST
 * @param {Date} utcDate - Date to check
 * @returns {boolean} True if the date is today in IST
 */
function isTodayIST(utcDate) {
  const dateIST = toIST(utcDate);
  const todayIST = getNowIST();
  return formatDateIST(dateIST) === formatDateIST(todayIST);
}

/**
 * Get dates for the last N days in IST
 * @param {number} days - Number of days
 * @returns {Array<{date: string, dayName: string, isToday: boolean}>}
 */
function getLastNDaysIST(days = 7) {
  const result = [];
  const nowIST = getNowIST();

  for (let i = days - 1; i >= 0; i--) {
    const date = new Date(nowIST);
    date.setDate(date.getDate() - i);
    result.push({
      date: formatDateIST(date),
      dayName: getDayNameIST(new Date(date.getTime() - IST_OFFSET_MS)), // Convert back for getDayNameIST
      isToday: i === 0
    });
  }

  return result;
}

module.exports = {
  IST_OFFSET_HOURS,
  IST_OFFSET_MS,
  getNowIST,
  toIST,
  getTodayIST,
  getYesterdayIST,
  formatDateIST,
  getStartOfDayIST,
  getEndOfDayIST,
  getDayOfWeekIST,
  getDayNameIST,
  isTodayIST,
  getLastNDaysIST
};
