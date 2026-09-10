import type { SupportedStorage } from '@supabase/supabase-js';

// The SDK uses storageKey as its BroadcastChannel name. It must be unique per
// document; the adapter maps it to stable sessionStorage keys for reloads.
export const authStorageKey = `golf.auth.instance.${crypto.randomUUID()}`;
const prefix = 'golf.auth.tab.v1';
const identityKey = `${prefix}.identity`;
const memory = new Map<string, string>();
let storage: Storage | null = null;
try {
  storage = window.sessionStorage;
  storage.setItem(`${prefix}.probe`, '1');
  storage.removeItem(`${prefix}.probe`);
} catch { storage = null; }
const read = (key: string) => { try { return storage ? storage.getItem(key) : memory.get(key) ?? null; } catch { storage = null; return memory.get(key) ?? null; } };
const write = (key: string, value: string) => { memory.set(key, value); try { storage?.setItem(key, value); } catch { storage = null; } };
const remove = (key: string) => { memory.delete(key); try { storage?.removeItem(key); } catch { storage = null; } };
function clearSession() {
  const keys = new Set(memory.keys());
  try { if (storage) for (let i = 0; i < storage.length; i++) { const key = storage.key(i); if (key) keys.add(key); } } catch { /* Memory fallback. */ }
  for (const key of keys) if (key.startsWith(`${prefix}.session`)) remove(key);
}
let tabId = read(identityKey) || crypto.randomUUID();
write(identityKey, tabId);
let settled = false;
let channel: BroadcastChannel | null = null;
// A duplicated tab can inherit sessionStorage. Detect another live owner and
// discard the copied session before the SDK reads or refreshes its tokens.
const ready = new Promise<void>(resolve => {
  try {
    if (typeof BroadcastChannel === 'undefined') { settled = true; resolve(); return; }
    channel = new BroadcastChannel('golf-auth-tab-ownership-v1');
    let copied = false;
    channel.onmessage = ({ data }) => {
      if (!data || data.tabId !== tabId || data.instance === authStorageKey) return;
      if (data.type === 'probe' && (settled || authStorageKey < data.instance)) {
        channel?.postMessage({ type: 'owned', tabId, instance: authStorageKey, target: data.instance });
      }
      if (data.type === 'owned' && data.target === authStorageKey && !settled) copied = true;
    };
    channel.postMessage({ type: 'probe', tabId, instance: authStorageKey });
    window.setTimeout(() => {
      if (copied) { clearSession(); tabId = crypto.randomUUID(); write(identityKey, tabId); }
      settled = true; resolve();
    }, 150);
  } catch { settled = true; resolve(); }
});
const keyFor = (key: string) => `${prefix}.session${key.startsWith(authStorageKey) ? key.slice(authStorageKey.length) : `.${key}`}`;
export const tabAuthStorage: SupportedStorage = {
  async getItem(key) { await ready; return read(keyFor(key)); },
  async setItem(key, value) { await ready; write(keyFor(key), value); },
  async removeItem(key) { await ready; remove(keyFor(key)); },
};
export async function clearTabAuthSession() { await ready; clearSession(); }
