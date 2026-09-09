import React from 'react';
import { CheckCircle2, LogIn } from 'lucide-react';
import { ThemeToggle } from './ThemeToggle';

interface EmailConfirmedScreenProps {
  onLogin: () => void;
}

export const EmailConfirmedScreen: React.FC<EmailConfirmedScreenProps> = ({ onLogin }) => (
  <div className="min-h-screen bg-app px-4 py-6 flex items-center justify-center transition-colors">
    <div className="fixed right-4 top-4"><ThemeToggle /></div>
    <main className="w-full max-w-md bg-card border border-line rounded-3xl shadow-card px-6 py-8 text-center">
      <img src="/images/Omiki.png" alt="Omiki Golf" className="w-24 h-24 object-contain mx-auto mb-5" />
      <div className="w-14 h-14 bg-accent-soft rounded-full flex items-center justify-center mx-auto mb-4">
        <CheckCircle2 className="w-8 h-8 text-accent-ink" />
      </div>
      <h1 className="text-3xl font-bold text-ink mb-3">¡Bienvenido a Omiki Golf!</h1>
      <p className="text-lg font-semibold text-accent-ink mb-3">Tu correo ha sido validado.</p>
      <p className="text-ink-3 mb-7">Tu cuenta ya está lista. Puedes cerrar esta ventana y volver a Omiki Golf para iniciar sesión.</p>
      <button
        type="button"
        onClick={onLogin}
        className="w-full inline-flex items-center justify-center gap-2 bg-accent hover:bg-accent-hover text-on-accent font-semibold py-3 rounded-xl transition-colors"
      >
        <LogIn size={19} />
        Ir a iniciar sesión
      </button>
    </main>
  </div>
);
