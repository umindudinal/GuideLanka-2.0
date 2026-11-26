/**
 * Restrict phone input to digits only, preserving an optional leading '+'.
 * Strips all letters, spaces, and other non-numeric characters.
 */
export const sanitizePhoneInput = (value) => {
  const raw = String(value || '');
  const hasLeadingPlus = raw.startsWith('+');
  const digitsOnly = raw.replace(/\D/g, '').slice(0, 15);
  return hasLeadingPlus ? `+${digitsOnly}` : digitsOnly;
};
