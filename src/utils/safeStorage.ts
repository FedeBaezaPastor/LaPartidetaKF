import type { SupportedStorage } from '@supabase/supabase-js';

class SafeStorage implements SupportedStorage {
  private memoryStorage: Map<string, string>;
  private isLocalStorageAvailable: boolean;
  private checkAttempted: boolean;

  constructor() {
    this.memoryStorage = new Map();
    this.checkAttempted = false;
    this.isLocalStorageAvailable = false;

    try {
      this.isLocalStorageAvailable = this.checkLocalStorageAvailable();
      console.log('📦 SafeStorage initialized. localStorage available:', this.isLocalStorageAvailable);
    } catch (e) {
      console.warn('⚠️ SafeStorage initialization error:', e);
      this.isLocalStorageAvailable = false;
    }
  }

  private checkLocalStorageAvailable(): boolean {
    if (this.checkAttempted) {
      return this.isLocalStorageAvailable;
    }

    this.checkAttempted = true;

    try {
      if (typeof window === 'undefined' || !window.localStorage) {
        return false;
      }
      const testKey = '__test_storage__';
      window.localStorage.setItem(testKey, 'test');
      const result = window.localStorage.getItem(testKey);
      window.localStorage.removeItem(testKey);
      return result === 'test';
    } catch (e) {
      return false;
    }
  }

  getItem(key: string): string | null {
    try {
      if (this.isLocalStorageAvailable) {
        try {
          return window.localStorage.getItem(key);
        } catch (e) {
          this.isLocalStorageAvailable = false;
        }
      }
      return this.memoryStorage.get(key) || null;
    } catch (error) {
      return this.memoryStorage.get(key) || null;
    }
  }

  setItem(key: string, value: string): void {
    try {
      if (this.isLocalStorageAvailable) {
        try {
          window.localStorage.setItem(key, value);
        } catch (e) {
          this.isLocalStorageAvailable = false;
        }
      }
      this.memoryStorage.set(key, value);
    } catch (error) {
      this.memoryStorage.set(key, value);
    }
  }

  removeItem(key: string): void {
    try {
      if (this.isLocalStorageAvailable) {
        try {
          window.localStorage.removeItem(key);
        } catch (e) {
          this.isLocalStorageAvailable = false;
        }
      }
      this.memoryStorage.delete(key);
    } catch (error) {
      this.memoryStorage.delete(key);
    }
  }

  clear(): void {
    try {
      if (this.isLocalStorageAvailable) {
        try {
          window.localStorage.clear();
        } catch (e) {
          this.isLocalStorageAvailable = false;
        }
      }
      this.memoryStorage.clear();
    } catch (error) {
      this.memoryStorage.clear();
    }
  }
}

export const safeStorage = new SafeStorage();
