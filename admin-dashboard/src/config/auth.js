// Admin allowlist - emails authorized to access the dashboard
// Add your admin emails here
export const ALLOWED_ADMINS = [
  // Add admin emails here, e.g.:
  'abhijeet.roy@gmail.com',
  'satishshetty@gmail.com',
];

// Check if an email is in the admin allowlist
export function isAllowedAdmin(email) {
  if (!email) return false;

  // If no admins configured, allow all (for initial setup)
  // Remove this check in production!
  if (ALLOWED_ADMINS.length === 0) {
    console.warn('No admin emails configured. Allowing all authenticated users.');
    return true;
  }

  return ALLOWED_ADMINS.includes(email.toLowerCase());
}
