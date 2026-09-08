import React, { useState, useRef, useEffect } from 'react';
import { ArrowLeft, Eye, EyeOff, Check, X, AlertCircle, Camera, Info, MailCheck } from 'lucide-react';
import { supabase } from '../services/supabaseClient';
import { userService } from '../services/userService';
import { PlanType } from '../types';

interface RegistrationFormProps {
  planType: PlanType;
  onBack: () => void;
  onRegistered: () => void;
}

const AVATAR_PRESETS = [
  'https://api.dicebear.com/7.x/adventurer/svg?seed=Golf1&backgroundColor=dbeafe',
  'https://api.dicebear.com/7.x/adventurer/svg?seed=Golf2&backgroundColor=fce7f3',
  'https://api.dicebear.com/7.x/adventurer/svg?seed=Golf3&backgroundColor=d1fae5',
  'https://api.dicebear.com/7.x/adventurer/svg?seed=Golf4&backgroundColor=fef3c7',
  'https://api.dicebear.com/7.x/adventurer/svg?seed=Golf5&backgroundColor=ede9fe',
  'https://api.dicebear.com/7.x/adventurer/svg?seed=Golf6&backgroundColor=fee2e2',
];

const TEE_OPTIONS = ['amarillo', 'rojo', 'blanco', 'azul'];

export const RegistrationForm: React.FC<RegistrationFormProps> = ({ planType, onBack, onRegistered }) => {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [nick, setNick] = useState('');
  const [nickStatus, setNickStatus] = useState<'idle' | 'checking' | 'available' | 'taken'>('idle');
  const [displayName, setDisplayName] = useState('');
  const [handicap, setHandicap] = useState('');
  const [defaultTee, setDefaultTee] = useState('amarillo');
  const [country, setCountry] = useState('Espana');
  const [postalCode, setPostalCode] = useState('');
  const [age, setAge] = useState('');
  const [avatarUrl, setAvatarUrl] = useState(AVATAR_PRESETS[0]);
  const [acceptedTerms, setAcceptedTerms] = useState(false);
  const [over14, setOver14] = useState(false);
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const [confirmationEmail, setConfirmationEmail] = useState('');
  const nickTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  useEffect(() => {
    if (nick.length < 3) {
      setNickStatus('idle');
      return;
    }
    setNickStatus('checking');
    if (nickTimerRef.current) clearTimeout(nickTimerRef.current);
    nickTimerRef.current = setTimeout(async () => {
      try {
        const available = await userService.checkNickAvailable(nick);
        setNickStatus(available ? 'available' : 'taken');
      } catch {
        setNickStatus('idle');
      }
    }, 500);
    return () => { if (nickTimerRef.current) clearTimeout(nickTimerRef.current); };
  }, [nick]);

  const validatePassword = (pw: string): string | null => {
    if (pw.length < 6) return 'La contrasena debe tener al menos 6 caracteres';
    if (!/[A-Z]/.test(pw)) return 'Debe incluir al menos una mayuscula';
    if (!/[a-z]/.test(pw)) return 'Debe incluir al menos una minuscula';
    if (!/[^a-zA-Z0-9]/.test(pw)) return 'Debe incluir al menos un caracter especial';
    return null;
  };

  const handleSubmit = async () => {
    setError('');

    if (!nick) {
      setError('El Nick es obligatorio');
      return;
    }

    if (nickStatus !== 'available') {
      setError('El Nick no esta disponible o sigue comprobando');
      return;
    }

    if (!over14) {
      setError('Debes confirmar que tienes al menos 14 anos');
      return;
    }

    if (!acceptedTerms) {
      setError('Debes aceptar los terminos y la politica de privacidad');
      return;
    }

    setLoading(true);
    try {
      let userId: string;

      if (email && password) {
        const { data: authData, error: authError } = await supabase.auth.signUp({
          email,
          password,
          options: {
            emailRedirectTo: `${window.location.origin}/?email-confirmed=1`,
            data: {
              registration_pending: true,
              requested_plan: planType,
              nick,
              display_name: displayName || null,
              avatar_url: avatarUrl,
              exact_handicap: handicap ? parseFloat(handicap) : 0,
              default_tee: defaultTee,
              country,
              postal_code: postalCode || null,
              age: age ? parseInt(age) : null,
              accepted_terms: true,
            },
          },
        });
        if (authError) throw authError;
        if (!authData.user) throw new Error('Error al crear la cuenta');

        if (!authData.session) {
          setConfirmationEmail(email);
          return;
        }
        userId = authData.user.id;
      } else {
        const { data: authData, error: authError } = await supabase.auth.signInAnonymously();
        if (authError) throw authError;
        if (!authData.user) throw new Error('Error al crear la cuenta de prueba');
        userId = authData.user.id;
      }

      await userService.createProfile({
        user_id: userId,
        nick,
        display_name: displayName || undefined,
        avatar_url: avatarUrl,
        exact_handicap: handicap ? parseFloat(handicap) : 0,
        default_tee: defaultTee,
        country,
        postal_code: postalCode || undefined,
        age: age ? parseInt(age) : undefined,
        accepted_terms: true,
      });

      onRegistered();
    } catch (err: any) {
      if (err.message?.includes('already registered')) {
        setError('Este email ya esta registrado');
      } else {
        setError(err.message || 'Error al registrar');
      }
    } finally {
      setLoading(false);
    }
  };

  if (confirmationEmail) {
    return (
      <div className="min-h-screen bg-app flex items-center justify-center p-4 transition-colors">
        <div className="max-w-md w-full bg-card border border-line rounded-2xl shadow-card p-8 text-center">
          <div className="w-16 h-16 bg-accent-soft rounded-full flex items-center justify-center mx-auto mb-5">
            <MailCheck className="w-8 h-8 text-accent-ink" />
          </div>
          <h1 className="text-2xl font-bold text-ink mb-3">Confirma tu correo</h1>
          <p className="text-ink-3 mb-2">Te hemos enviado un mensaje de Omiki Golf a:</p>
          <p className="font-semibold text-ink break-all mb-5">{confirmationEmail}</p>
          <p className="text-sm text-ink-3 mb-6">
            Abre el correo y pulsa “Confirmar mi cuenta”. Después volverás a Omiki Golf con tu sesión iniciada.
          </p>
          <button
            type="button"
            onClick={onBack}
            className="w-full bg-card-2 hover:bg-neutral-hover text-ink-2 border border-line font-semibold py-3 rounded-xl transition-colors"
          >
            Volver
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-app transition-colors">
      <div className="max-w-lg mx-auto px-4 py-6">
        <button
          onClick={onBack}
          className="flex items-center gap-2 text-ink-3 hover:text-ink transition-colors mb-6"
        >
          <ArrowLeft size={20} />
          Volver
        </button>

        <div className="bg-card rounded-2xl shadow-card p-6 md:p-8">
          <h1 className="text-2xl font-bold text-ink mb-1">Crear cuenta {planType === 'player' ? 'Player' : 'Team'}</h1>
          <p className="text-sm text-ink-3 mb-6">Configura tu perfil de jugador</p>

          {error && (
            <div className="bg-red-50 border border-red-200 text-red-700 text-sm p-3 rounded-xl mb-4 flex items-center gap-2">
              <AlertCircle size={16} />
              {error}
            </div>
          )}

          {/* Avatar selection */}
          <div className="mb-5">
            <label className="block text-sm font-medium text-ink-2 mb-2">Avatar</label>
            <div className="flex flex-wrap gap-3">
              {AVATAR_PRESETS.map((url, i) => (
                <button
                  key={i}
                  onClick={() => setAvatarUrl(url)}
                  className={`w-14 h-14 rounded-full overflow-hidden border-2 transition-all ${avatarUrl === url ? 'border-accent ring-2 ring-emerald-200' : 'border-line'}`}
                >
                  <img src={url} alt="avatar" className="w-full h-full" />
                </button>
              ))}
              <div className="w-14 h-14 rounded-full border-2 border-dashed border-line-2 flex items-center justify-center text-ink-4">
                <Camera size={18} />
              </div>
            </div>
          </div>

          {/* Nick with real-time validation */}
          <div className="mb-4">
            <label className="block text-sm font-medium text-ink-2 mb-1">
              Nick <span className="text-red-500">*</span>
            </label>
            <div className="relative">
              <input
                type="text"
                value={nick}
                onChange={(e) => setNick(e.target.value)}
                placeholder="Tu apodo unico"
                className="w-full px-4 py-2.5 border rounded-xl focus:ring-2 focus:ring-accent focus:border-transparent pr-10"
                style={{ borderColor: nickStatus === 'available' ? '#059669' : nickStatus === 'taken' ? '#ef4444' : '#d1d5db' }}
              />
              <div className="absolute right-3 top-1/2 -translate-y-1/2">
                {nickStatus === 'checking' && <div className="w-4 h-4 border-2 border-line-2 border-t-emerald-600 rounded-full animate-spin" />}
                {nickStatus === 'available' && <Check size={18} className="text-accent-ink" />}
                {nickStatus === 'taken' && <X size={18} className="text-red-500" />}
              </div>
            </div>
            {nickStatus === 'available' && <p className="text-xs text-accent-ink mt-1">Nick disponible</p>}
            {nickStatus === 'taken' && <p className="text-xs text-red-500 mt-1">Este Nick ya esta cogido</p>}
            {nickStatus === 'idle' && nick.length > 0 && <p className="text-xs text-ink-4 mt-1">Minimo 3 caracteres</p>}
          </div>

          {/* Email + Password (optional for demo) */}
          <div className="grid md:grid-cols-2 gap-4 mb-4">
            <div>
              <label className="block text-sm font-medium text-ink-2 mb-1">Email <span className="text-ink-4 text-xs">(opcional)</span></label>
              <input
                type="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                placeholder="tu@email.com"
                className="w-full px-4 py-2.5 border border-line-2 rounded-xl focus:ring-2 focus:ring-accent focus:border-transparent"
              />
            </div>
            <div>
              <label className="block text-sm font-medium text-ink-2 mb-1">Contrasena <span className="text-ink-4 text-xs">(opcional)</span></label>
              <div className="relative">
                <input
                  type={showPassword ? 'text' : 'password'}
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  placeholder="Min 6, mayus, minus, especial"
                  className="w-full px-4 py-2.5 border border-line-2 rounded-xl focus:ring-2 focus:ring-accent focus:border-transparent pr-10"
                />
                <button
                  onClick={() => setShowPassword(!showPassword)}
                  className="absolute right-3 top-1/2 -translate-y-1/2 text-ink-4"
                >
                  {showPassword ? <EyeOff size={18} /> : <Eye size={18} />}
                </button>
              </div>
            </div>
          </div>

          {/* Display name + handicap */}
          <div className="grid md:grid-cols-2 gap-4 mb-4">
            <div>
              <label className="block text-sm font-medium text-ink-2 mb-1">Nombre (opcional)</label>
              <input
                type="text"
                value={displayName}
                onChange={(e) => setDisplayName(e.target.value)}
                placeholder="Tu nombre real"
                className="w-full px-4 py-2.5 border border-line-2 rounded-xl focus:ring-2 focus:ring-accent focus:border-transparent"
              />
            </div>
            <div>
              <label className="block text-sm font-medium text-ink-2 mb-1">Handicap exacto</label>
              <input
                type="number"
                step="0.1"
                value={handicap}
                onChange={(e) => setHandicap(e.target.value)}
                placeholder="Ej: 12.4"
                className="w-full px-4 py-2.5 border border-line-2 rounded-xl focus:ring-2 focus:ring-accent focus:border-transparent"
              />
            </div>
          </div>

          {/* Default tee */}
          <div className="mb-4">
            <label className="block text-sm font-medium text-ink-2 mb-2">Barras por defecto</label>
            <div className="flex gap-2">
              {TEE_OPTIONS.map(t => (
                <button
                  key={t}
                  onClick={() => setDefaultTee(t)}
                  className={`px-4 py-2 rounded-lg text-sm font-medium capitalize transition-all ${defaultTee === t ? 'bg-accent text-on-accent' : 'bg-card-2 text-ink-3 hover:bg-neutral-hover'}`}
                >
                  {t}
                </button>
              ))}
            </div>
          </div>

          {/* Country + Postal + Age */}
          <div className="grid md:grid-cols-3 gap-4 mb-4">
            <div>
              <label className="block text-sm font-medium text-ink-2 mb-1">Pais</label>
              <input
                type="text"
                value={country}
                onChange={(e) => setCountry(e.target.value)}
                className="w-full px-4 py-2.5 border border-line-2 rounded-xl focus:ring-2 focus:ring-accent focus:border-transparent"
              />
            </div>
            <div>
              <label className="block text-sm font-medium text-ink-2 mb-1">Cod. Postal</label>
              <input
                type="text"
                value={postalCode}
                onChange={(e) => setPostalCode(e.target.value)}
                className="w-full px-4 py-2.5 border border-line-2 rounded-xl focus:ring-2 focus:ring-accent focus:border-transparent"
              />
            </div>
            <div>
              <label className="block text-sm font-medium text-ink-2 mb-1">Edad</label>
              <input
                type="number"
                value={age}
                onChange={(e) => setAge(e.target.value)}
                placeholder="Ej: 35"
                className="w-full px-4 py-2.5 border border-line-2 rounded-xl focus:ring-2 focus:ring-accent focus:border-transparent"
              />
            </div>
          </div>

          {/* Checkboxes */}
          <div className="space-y-3 mb-6">
            <label className="flex items-start gap-2 cursor-pointer">
              <input type="checkbox" checked={over14} onChange={(e) => setOver14(e.target.checked)} className="mt-0.5 w-5 h-5 accent-emerald-600" />
              <span className="text-sm text-ink-3">Confirmo que tengo al menos 14 anos</span>
            </label>
            <label className="flex items-start gap-2 cursor-pointer">
              <input type="checkbox" checked={acceptedTerms} onChange={(e) => setAcceptedTerms(e.target.checked)} className="mt-0.5 w-5 h-5 accent-emerald-600" />
              <span className="text-sm text-ink-3">Acepto los <a href="#" className="text-accent-ink underline">terminos</a> y la <a href="#" className="text-accent-ink underline">politica de privacidad</a></span>
            </label>
          </div>

          <button
            onClick={handleSubmit}
            disabled={loading}
            className="w-full bg-accent hover:bg-accent-hover text-on-accent font-semibold py-3 rounded-xl transition-colors disabled:opacity-50"
          >
            {loading ? 'Creando cuenta...' : 'Crear cuenta y continuar'}
          </button>

          <p className="text-xs text-ink-4 mt-3 flex items-center justify-center gap-1">
            <Info size={12} />
            Tras registrar, elegiras metodo de pago: tarjeta o Bitcoin Lightning
          </p>
        </div>
      </div>
    </div>
  );
};
