import React, { useState } from 'react';
import { QRCodeSVG } from 'qrcode.react';
import { Share2, Copy, Check, X, QrCode } from 'lucide-react';

interface ShareModalProps {
  onClose: () => void;
  shareUrl?: string;
  title?: string;
}

export default function ShareModal({ 
  onClose, 
  shareUrl = window.location.origin, 
  title = "¡Únete a La Partideta Golf!" 
}: ShareModalProps) {
  const [copied, setCopied] = useState(false);
  const [showQR, setShowQR] = useState(false);

  // Soporte para Web Share API nativa
  const canNativeShare = typeof navigator !== 'undefined' && !!navigator.share;

  const handleNativeShare = async () => {
    try {
      await navigator.share({
        title: 'La Partideta Golf',
        text: '¡Lleva el control de tus partidas de golf con amigos!',
        url: shareUrl,
      });
    } catch (err) {
      console.log('Error o cancelación al compartir:', err);
    }
  };

  const handleCopy = () => {
    navigator.clipboard.writeText(shareUrl);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  return (
    <div className="fixed inset-0 bg-black/60 backdrop-blur-sm z-50 flex items-center justify-center p-4">
      <div className="bg-card rounded-2xl max-w-sm w-full p-6 shadow-card relative animate-in fade-in zoom-in duration-200">
        <button 
          onClick={onClose}
          className="absolute top-4 right-4 text-ink-4 hover:text-ink-3 p-1 rounded-full"
        >
          <X className="w-5 h-5" />
        </button>

        <div className="text-center mb-6">
          <div className="inline-flex items-center justify-center w-12 h-12 bg-accent-soft rounded-full mb-3 text-accent-ink">
            <Share2 className="w-6 h-6" />
          </div>
          <h3 className="text-xl font-bold text-ink">{title}</h3>
          <p className="text-sm text-ink-3 mt-1">Comparte con tus amigos para empezar la partida</p>
        </div>

        {/* Muestra QR o Contenido principal */}
        {showQR ? (
          <div className="flex flex-col items-center justify-center p-4 bg-card-2 rounded-xl mb-4 border border-line">
            <QRCodeSVG value={shareUrl} size={180} level="M" includeMargin={true} />
            <p className="text-xs text-ink-3 mt-3 text-center">Escanea con la cámara del móvil para abrir la app</p>
          </div>
        ) : (
          <div className="space-y-3 mb-4">
            {canNativeShare && (
              <button
                onClick={handleNativeShare}
                className="w-full flex items-center justify-center gap-2 bg-accent text-on-accent font-semibold py-3 px-4 rounded-xl hover:bg-accent-hover transition-colors shadow-soft"
              >
                <Share2 className="w-5 h-5" />
                Compartir (WhatsApp, Apps...)
              </button>
            )}

            <button
              onClick={() => setShowQR(true)}
              className="w-full flex items-center justify-center gap-2 bg-card-2 text-ink font-semibold py-3 px-4 rounded-xl hover:bg-gray-200 transition-colors border border-line"
            >
              <QrCode className="w-5 h-5 text-ink-3" />
              Mostrar código QR
            </button>
          </div>
        )}

        {showQR && (
          <button
            onClick={() => setShowQR(false)}
            className="w-full mb-3 text-sm text-accent-ink font-medium hover:underline"
          >
            ← Volver a opciones de compartir
          </button>
        )}

        {/* Input con enlace para copiar */}
        <div className="flex items-center gap-2 bg-card-2 p-2 rounded-xl border border-line">
          <input
            type="text"
            readOnly
            value={shareUrl}
            className="bg-transparent text-xs text-ink-3 flex-1 outline-none px-2 font-mono truncate"
          />
          <button
            onClick={handleCopy}
            className="bg-card border border-line text-ink-2 p-2 rounded-lg hover:bg-card-2 transition-colors"
            title="Copiar enlace"
          >
            {copied ? <Check className="w-4 h-4 text-accent-ink" /> : <Copy className="w-4 h-4" />}
          </button>
        </div>
      </div>
    </div>
  );
}