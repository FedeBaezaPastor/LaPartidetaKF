import { safeStorage } from './safeStorage';

const ADMIN_PIN = '2248';
const STORAGE_KEY = 'divend_admin_authorized';

export const adminPinUtils = {
  verifyPin(pin: string): boolean {
    return pin === ADMIN_PIN;
  },

  isAuthorized(): boolean {
    return safeStorage.getItem(STORAGE_KEY) === 'true';
  },

  setAuthorized(): void {
    safeStorage.setItem(STORAGE_KEY, 'true');
  },

  clearAuthorization(): void {
    safeStorage.removeItem(STORAGE_KEY);
  },
};
