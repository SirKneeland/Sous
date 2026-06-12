// Referral code generation. Codes look like SOUS-A7X2: a fixed prefix plus four
// characters from an unambiguous alphabet (no 0/O/1/I/L) so they're easy to read
// aloud and type.

const ALPHABET = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

export function generateReferralCode(): string {
  let suffix = '';
  for (let i = 0; i < 4; i++) {
    const idx = Math.floor(Math.random() * ALPHABET.length);
    suffix += ALPHABET[idx];
  }
  return `SOUS-${suffix}`;
}
