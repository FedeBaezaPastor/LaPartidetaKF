import React from 'react';
import { MailCheck } from 'lucide-react';

interface EmailSentModalProps {
  email?: string;
  onAccept: () => void;
}

export const EmailSentModal: React.FC<EmailSentModalProps> = ({ email, onAccept }) => (
  <div
    className="fixed inset-0 z-[150] bg-black/60 backdrop-blur-sm flex items-center justify-center p-4"
    role="dialog"
    aria-modal="true"
    aria-labelledby="email-sent-title"
  >
    <div className="w-full max-w-sm bg-card border border-line rounded-2xl shadow-card p-6 text-center">
      <div className="w-16 h-16 bg-accent-soft rounded-full flex items-center justify-center mx-auto mb-4">
        <MailCheck className="w-8 h-8 text-accent-ink" />
      </div>
      <h2 id="email-sent-title" className="text-2xl font-bold text-ink mb-3">Revisa tu correo</h2>
      <p className="text-ink-3 mb-2">Te hemos enviado un enlace de Omiki Golf para confirmar tu cuenta.</p>
      {email && <p className="font-semibold text-ink break-all mb-3">{email}</p>}
      <p className="text-sm text-ink-3 mb-6">Abre el mensaje y pulsa el botón de confirmación para validar tu correo.</p>
      <button
        type="button"
        onClick={onAccept}
        className="w-full bg-accent hover:bg-accent-hover text-on-accent font-semibold py-3 rounded-xl transition-colors"
      >
        Aceptar
      </button>
    </div>
  </div>
);
