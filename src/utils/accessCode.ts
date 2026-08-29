import { safeStorage } from './safeStorage';

const ACCESS_CODES_KEY = 'golf_access_codes';

export interface StoredAccessCode {
  roundId: string;
  code: string;
  timestamp: number;
}

export function generateAccessCode(): string {
  return Math.floor(1000 + Math.random() * 9000).toString();
}

export const accessCodeStorage = {
  saveAccessCode: (roundId: string, code: string): void => {
    try {
      const stored = accessCodeStorage.getAllAccessCodes();
      const updated = stored.filter(s => s.roundId !== roundId);
      updated.push({ roundId, code, timestamp: Date.now() });
      safeStorage.setItem(ACCESS_CODES_KEY, JSON.stringify(updated));
    } catch (error) {
      console.error('Error saving access code:', error);
    }
  },

  getAccessCode: (roundId: string): string | null => {
    try {
      const stored = accessCodeStorage.getAllAccessCodes();
      const found = stored.find(s => s.roundId === roundId);
      return found ? found.code : null;
    } catch (error) {
      console.error('Error getting access code:', error);
      return null;
    }
  },

  hasAccessCode: (roundId: string): boolean => {
    return accessCodeStorage.getAccessCode(roundId) !== null;
  },

  removeAccessCode: (roundId: string): void => {
    try {
      const stored = accessCodeStorage.getAllAccessCodes();
      const updated = stored.filter(s => s.roundId !== roundId);
      safeStorage.setItem(ACCESS_CODES_KEY, JSON.stringify(updated));
    } catch (error) {
      console.error('Error removing access code:', error);
    }
  },

  getAllAccessCodes: (): StoredAccessCode[] => {
    try {
      const stored = safeStorage.getItem(ACCESS_CODES_KEY);
      return stored ? JSON.parse(stored) : [];
    } catch (error) {
      console.error('Error getting all access codes:', error);
      return [];
    }
  },

  clearOldAccessCodes: (daysOld: number = 30): void => {
    try {
      const stored = accessCodeStorage.getAllAccessCodes();
      const cutoff = Date.now() - (daysOld * 24 * 60 * 60 * 1000);
      const updated = stored.filter(s => s.timestamp > cutoff);
      safeStorage.setItem(ACCESS_CODES_KEY, JSON.stringify(updated));
    } catch (error) {
      console.error('Error clearing old access codes:', error);
    }
  }
};
