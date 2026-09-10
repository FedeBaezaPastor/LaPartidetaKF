import { NavigationButton } from '../NavigationButton';
import { useState } from 'react';
import { LockKeyhole } from 'lucide-react';
import { supabase } from '../../services/supabaseClient';
import type { AdminAccount } from '../../services/adminService';

export function AdminPasswordSetup({ account, onDone, onLogout }: {
  account: AdminAccount;
  onDone: () => Promise<void>;
  onLogout: () => Promise<void>;
}) {
  const [password, setPassword] = useState('');
  const [confirmation, setConfirmation] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const [saved, setSaved] = useState(false);

  const submit = async (event: React.FormEvent) => {
    event.preventDefault();
    if (busy) return;
    if (password.length < 12) { setError('Utiliza al menos 12 caracteres.'); return; }
    if (password !== confirmation) { setError('Las contraseñas no coinciden.'); return; }
    setBusy(true);
    setError('');
    try {
      const { error: updateError } = await supabase.auth.updateUser({ password });
      if (updateError) throw updateError;
      setPassword('');
      setConfirmation('');
      setSaved(true);
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'No se ha podido guardar la contraseña.');
    } finally { setBusy(false); }
  };

  return (
    <div className="min-h-screen bg-app flex items-center justify-center p-4">
      <main className="w-full max-w-md bg-card border border-line rounded-2xl shadow-card p-6">
        <LockKeyhole size={30} className="text-accent-ink mb-4" />
        <h1 className="text-xl font-bold text-ink">Contraseña de administrador</h1>
        <p className="text-ink-3 mt-2 mb-5">Cuenta {account.alias}. Esta contraseña es independiente de la de tu jugador.</p>
        {saved ? (
          <div>
            <p role="status" className="text-accent-ink mb-4">Contraseña guardada correctamente.</p>
            <button onClick={() => void onDone()} className="w-full bg-accent text-on-accent rounded-xl py-3">Entrar al panel</button>
          </div>
        ) : (
          <form onSubmit={submit} className="space-y-4">
            <label className="block text-ink-2">Nueva contraseña
              <input type="password" autoComplete="new-password" minLength={12} maxLength={128} required value={password}
                onChange={e => setPassword(e.target.value)} className="mt-2 w-full bg-card border border-line rounded-xl p-3" />
            </label>
            <p className="text-xs text-ink-3">Mínimo 12 caracteres.</p>
            <label className="block text-ink-2">Repetir contraseña
              <input type="password" autoComplete="new-password" minLength={12} maxLength={128} required value={confirmation}
                onChange={e => setConfirmation(e.target.value)} className="mt-2 w-full bg-card border border-line rounded-xl p-3" />
            </label>
            {error && <p role="alert" className="text-red-600">{error}</p>}
            <button disabled={busy} className="w-full bg-accent text-on-accent rounded-xl py-3 disabled:opacity-50">{busy ? 'Guardando…' : 'Guardar contraseña'}</button>
          </form>
        )}
        <NavigationButton destination="logout" disabled={busy} onClick={() => void onLogout()} className="mt-5" />
      </main>
    </div>
  );
}
