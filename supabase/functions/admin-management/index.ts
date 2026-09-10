import { aliasValue, body, HttpError, rateLimit, requireAdministrator, serve, uuidValue } from '../_shared/admin.ts';

serve(async (req, api) => {
  const { user } = await requireAdministrator(req, api);
  const input = await body(req);
  if (input.action !== 'invite' && input.action !== 'resend') throw new HttpError(400, 'Acción no válida.');
  await rateLimit(api.service, `admin-invite:${user.id}`, 10, 3600);
  let targetId: string;
  let targetEmail: string;
  if (input.action === 'invite') {
    const alias = aliasValue(input.alias);
    if (typeof input.email !== 'string' || input.email.length > 254 || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(input.email.trim())) {
      throw new HttpError(400, 'Introduce un correo válido.');
    }
    targetEmail = input.email.trim().toLowerCase();
    const { data: existing, error: lookupError } = await api.service.from('app_administrators')
      .select('user_id').eq('alias_key', alias.toLowerCase()).maybeSingle();
    if (lookupError) throw new HttpError(503, 'No se ha podido comprobar el alias.');
    if (existing) throw new HttpError(409, 'Ese alias ya existe.');
    // Auth enforces email uniqueness. Never promote or overwrite an existing player.
    const { data: created, error: createError } = await api.service.auth.admin.createUser({
      email: targetEmail,
      password: `${crypto.randomUUID()}${crypto.randomUUID()}`,
      email_confirm: false,
      app_metadata: { app_account_type: 'administrator' },
    });
    if (createError || !created.user) throw new HttpError(409, 'No se ha podido crear la cuenta. Utiliza un correo administrativo nuevo, por ejemplo con +admin.');
    targetId = created.user.id;
    const { error: registerError } = await api.service.rpc('register_app_administrator', {
      p_actor_id: user.id, p_user_id: targetId, p_alias: alias,
    });
    if (registerError) {
      // Only compensate the Auth account created by THIS request, never an existing one.
      const { error: cleanupError } = await api.service.auth.admin.deleteUser(targetId);
      if (cleanupError) console.error('Unassigned administrative Auth account requires cleanup');
      throw new HttpError(409, 'No se ha podido asignar el administrador. Actualiza la lista antes de reintentar.');
    }
  } else {
    targetId = uuidValue(input.userId);
    const { data: admin, error } = await api.service.from('app_administrators')
      .select('status').eq('user_id', targetId).maybeSingle();
    if (error || !admin || admin.status !== 'invited') throw new HttpError(400, 'Solo se puede reenviar el acceso a una cuenta pendiente.');
    const { data } = await api.service.auth.admin.getUserById(targetId);
    if (!data.user?.email) throw new HttpError(404, 'Cuenta no encontrada.');
    targetEmail = data.user.email;
  }
  // A setup link lets the recipient set their own password; we never return a password.
  const { error: mailError } = await api.auth.auth.resetPasswordForEmail(targetEmail, {
    redirectTo: `${api.origin}/?admin-action=setup`,
  });
  if (mailError) {
    return { ok: true, emailSent: false, message: 'Cuenta creada. No se pudo enviar el correo; utiliza «Reenviar acceso».' };
  }
  const { error: auditError } = await api.service.rpc('record_app_admin_invitation_sent', { p_actor_id: user.id, p_user_id: targetId });
  if (auditError) throw new HttpError(503, 'El correo se ha enviado, pero no se ha podido registrar el envío. Actualiza la lista.');
  return { ok: true, emailSent: true };
});
