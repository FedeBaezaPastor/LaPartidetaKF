import { GameState } from '../types';
import { safeStorage } from './safeStorage';

const STORAGE_KEY = 'golf_game_state';
const GROUP_ID_KEY = 'current_group_id';
const GROUP_CODE_KEY = 'current_group_code';
const GROUP_CREATOR_KEY = 'is_group_creator';
const LIMITED_ACCESS_KEY = 'has_limited_access';
const ACTIVE_ROUND_ID_KEY = 'active_round_id';

export const storageUtils = {
  saveGame: (gameState: GameState): void => {
    try {
      const serialized = JSON.stringify(gameState);
      safeStorage.setItem(STORAGE_KEY, serialized);
    } catch (error) {
      console.error('Error saving game state:', error);
    }
  },

  loadGame: (): GameState | null => {
    try {
      const stored = safeStorage.getItem(STORAGE_KEY);
      if (!stored) return null;
      return JSON.parse(stored) as GameState;
    } catch (error) {
      console.error('Error loading game state:', error);
      return null;
    }
  },

  clearGame: (): void => {
    try {
      safeStorage.removeItem(STORAGE_KEY);
    } catch (error) {
      console.error('Error clearing game state:', error);
    }
  },

  hasGameState: (): boolean => {
    return safeStorage.getItem(STORAGE_KEY) !== null;
  },

  saveCurrentGroup: (groupId: string, groupCode: string, isCreator: boolean = false, hasLimitedAccess: boolean = false): void => {
    try {
      safeStorage.setItem(GROUP_ID_KEY, groupId);
      safeStorage.setItem(GROUP_CODE_KEY, groupCode);
      safeStorage.setItem(GROUP_CREATOR_KEY, isCreator.toString());
      safeStorage.setItem(LIMITED_ACCESS_KEY, hasLimitedAccess.toString());
    } catch (error) {
      console.error('Error saving current group:', error);
    }
  },

  getCurrentGroupId: (): string | null => {
    try {
      return safeStorage.getItem(GROUP_ID_KEY);
    } catch (error) {
      console.error('Error getting current group ID:', error);
      return null;
    }
  },

  getCurrentGroupCode: (): string | null => {
    try {
      return safeStorage.getItem(GROUP_CODE_KEY);
    } catch (error) {
      console.error('Error getting current group code:', error);
      return null;
    }
  },

  isGroupCreator: (): boolean => {
    try {
      return safeStorage.getItem(GROUP_CREATOR_KEY) === 'true';
    } catch (error) {
      console.error('Error getting group creator status:', error);
      return false;
    }
  },

  hasLimitedAccess: (): boolean => {
    try {
      return safeStorage.getItem(LIMITED_ACCESS_KEY) === 'true';
    } catch (error) {
      console.error('Error getting limited access status:', error);
      return false;
    }
  },

  clearCurrentGroup: (): void => {
    try {
      safeStorage.removeItem(GROUP_ID_KEY);
      safeStorage.removeItem(GROUP_CODE_KEY);
      safeStorage.removeItem(GROUP_CREATOR_KEY);
      safeStorage.removeItem(LIMITED_ACCESS_KEY);
    } catch (error) {
      console.error('Error clearing current group:', error);
    }
  },

  hasCurrentGroup: (): boolean => {
    return safeStorage.getItem(GROUP_ID_KEY) !== null;
  },

  saveActiveRound: (roundId: string): void => {
    try {
      safeStorage.setItem(ACTIVE_ROUND_ID_KEY, roundId);
    } catch (error) {
      console.error('Error saving active round:', error);
    }
  },

  getActiveRoundId: (): string | null => {
    try {
      return safeStorage.getItem(ACTIVE_ROUND_ID_KEY);
    } catch (error) {
      console.error('Error getting active round ID:', error);
      return null;
    }
  },

  clearActiveRound: (): void => {
    try {
      safeStorage.removeItem(ACTIVE_ROUND_ID_KEY);
    } catch (error) {
      console.error('Error clearing active round:', error);
    }
  },
};
