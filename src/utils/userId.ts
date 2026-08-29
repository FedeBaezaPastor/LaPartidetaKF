import { safeStorage } from './safeStorage';

const ANONYMOUS_USER_KEY = 'la_partideta_device_user_id';

export const getUserId = (): string => {
  // 1. Intentar obtener un ID previo guardado en el navegador
  let userId = safeStorage.getItem(ANONYMOUS_USER_KEY);

  // 2. Si no existe (primera vez que entra), creamos uno y lo guardamos
  if (!userId) {
    userId = `anon_${crypto.randomUUID()}`;
    safeStorage.setItem(ANONYMOUS_USER_KEY, userId);
  }

  return userId;
};