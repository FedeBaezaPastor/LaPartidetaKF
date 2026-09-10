import { aliasValue, body, HttpError, rateLimit, serve } from '../_shared/admin.ts';

serve(async (req, api) => {
  const input = await body(req);
  if (input.action !== 'login' && input.action !== 'recover') throw new HttpError(400, 'Acción no válida.');
  const alias = aliasValue(input.alias).toLowerCase();
  const recovering = input.action === 'recover';
  // Account-level limits cannot be bypassed by spoofing a forwarded IP header.
  await rateLimit(api.service, `admin-${input.action}:${alias}`, recovering ? 3 : 10, recovering ? 3600 : 900);
  await rateLimit(api.service, `admin-${input.action}:global`, recovering ? 50 : 300, 60);
  const { data: admin, error } = await api.service.from('app_administrators')
    .select('user_id, status').eq('alias_key', alias).maybeSingle();
  if (error) throw new HttpError(503, 'El acceso administrativo aún no está disponible.');
  const allowed = admin && admin.status !== 'disabled' && (recovering || admin.status === 'active');

  if (recovering) {
    if (allowed) {
      const { data } = await api.service.auth.admin.getUserById(admin.user_id);
      if (data.user?.email) {
        const { error: mailError } = await api.auth.auth.resetPasswordForEmail(data.user.email, {
          redirectTo: `${api.origin}/?admin-action=recovery`,
        });
        if (mailError) console.error('Administrative recovery email failed');
      }
    }
    // Same response for unknown, pending, disabled and active aliases.
    return { ok: true };
  }

  if (typeof input.password !== 'string' || input.password.length > 1024 || !input.password) {
    throw new HttpError(400, 'Introduce la contraseña.');
  }
  const { data: authUser } = allowed ? await api.service.auth.admin.getUserById(admin.user_id) : { data: { user: null } };
  if (!authUser.user?.email) throw new HttpError(401, 'Usuario o contraseña incorrectos.');
  const { data, error: loginError } = await api.auth.auth.signInWithPassword({
    email: authUser.user.email, password: input.password,
  });
  if (loginError || !data.session) throw new HttpError(401, 'Usuario o contraseña incorrectos.');
  // Recheck status after authentication to close a concurrent deactivation race.
  const caller = api.caller(`Bearer ${data.session.access_token}`);
  const { data: current, error: currentError } = await caller.rpc('get_my_app_administrator');
  if (currentError || current?.status !== 'active') {
    await api.auth.auth.signOut({ scope: 'local' });
    throw new HttpError(403, 'No tienes acceso administrativo.');
  }
  const { error: auditError } = await caller.rpc('record_app_admin_login');
  if (auditError) {
    await api.auth.auth.signOut({ scope: 'local' });
    throw new HttpError(503, 'No se ha podido registrar el acceso.');
  }
  return { session: { access_token: data.session.access_token, refresh_token: data.session.refresh_token } };
});
