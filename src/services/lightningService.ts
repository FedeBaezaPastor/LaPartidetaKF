// src/services/lightningService.ts

const BTCPAY_URL = import.meta.env.VITE_BTCPAY_URL || 'https://btcpay.arinsaldev.com';
const STORE_ID = import.meta.env.VITE_BTCPAY_STORE_ID || '47sSiMkJ16GkQnUcchV2mAuzBTewgbab3CPYqC9J4trH';
const API_KEY = import.meta.env.VITE_BTCPAY_API_KEY || 'cbf361861a77da7a45c23be6dcd53b78aaba5d55';

export interface LightningInvoice {
  paymentHash: string;
  paymentRequest: string;
  chargeId: string;
}

export interface PaymentStatus {
  paid: boolean;
  amount?: number;
}

const sleep = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));

export const createInvoice = async (
  amountSats: number,
  memo: string
): Promise<LightningInvoice> => {
  // 1. Crear factura indicando método BTC-LN
  const res = await fetch(`${BTCPAY_URL}/api/v1/stores/${STORE_ID}/invoices`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `token ${API_KEY}`,
    },
    body: JSON.stringify({
      amount: amountSats,
      currency: 'SATS',
      metadata: { itemDesc: memo },
      checkout: {
        paymentMethods: ['BTC-LN'],
      },
    }),
  });

  if (!res.ok) {
    const err = await res.text();
    throw new Error(`BTCPay error: ${err}`);
  }

  const invoiceData = await res.json();
  const invoiceId = invoiceData.id;

  let bolt11 = '';

  // 2. Consultar el listado general de payment-methods de la factura
  for (let i = 0; i < 5; i++) {
    await sleep(600);

    const methodsRes = await fetch(
      `${BTCPAY_URL}/api/v1/stores/${STORE_ID}/invoices/${invoiceId}/payment-methods`,
      {
        headers: {
          'Authorization': `token ${API_KEY}`,
        },
      }
    );

    if (methodsRes.ok) {
      const methods = await methodsRes.json();
      
      // Buscar el objeto correspondiente a BTC-LN o Lightning
      const lnMethod = Array.isArray(methods)
        ? methods.find(
            (m: any) =>
              m.paymentMethod === 'BTC-LN' ||
              m.paymentMethodId === 'BTC-LN' ||
              m.paymentMethod?.includes('LN')
          )
        : null;

      if (lnMethod) {
        bolt11 =
          lnMethod.destination ||
          lnMethod.paymentLink ||
          lnMethod.bip21 ||
          lnMethod.paymentMethodDetails?.destination ||
          '';

        if (bolt11) break;
      }
    }
  }

  // 3. Fallback: Si no se obtiene la cadena lnbc directa, usar el checkoutLink nativo
  if (!bolt11 && invoiceData.checkoutLink) {
    bolt11 = invoiceData.checkoutLink;
  }

  // Limpiar esquema o prefijo lightning: si existe
  if (bolt11.includes('lightning=')) {
    bolt11 = bolt11.split('lightning=')[1].split('&')[0];
  }
  bolt11 = bolt11.replace(/^lightning:/i, '').trim();

  if (!bolt11) {
    throw new Error('No se pudo obtener el método de pago Lightning.');
  }

  return {
    paymentHash: invoiceId,
    paymentRequest: bolt11,
    chargeId: invoiceId,
  };
};

export const checkPayment = async (invoiceId: string): Promise<PaymentStatus> => {
  const res = await fetch(`${BTCPAY_URL}/api/v1/stores/${STORE_ID}/invoices/${invoiceId}`, {
    headers: {
      'Authorization': `token ${API_KEY}`,
    },
  });

  if (!res.ok) return { paid: false };

  const data = await res.json();
  return {
    paid: data.status === 'Settled' || data.status === 'Processing',
    amount: Number(data.amount),
  };
};

export const waitForPayment = (
  amountSats: number,
  memo: string,
  onPaid: (invoice: LightningInvoice) => void,
  onError: (err: Error) => void
): { cancel: () => void } => {
  let cancelled = false;
  let intervalId: ReturnType<typeof setInterval> | null = null;

  const start = async () => {
    try {
      const invoice = await createInvoice(amountSats, memo);
      if (cancelled) return;

      intervalId = setInterval(async () => {
        if (cancelled) {
          if (intervalId) clearInterval(intervalId);
          return;
        }

        try {
          const status = await checkPayment(invoice.chargeId);
          if (status.paid) {
            if (intervalId) clearInterval(intervalId);
            onPaid(invoice);
          }
        } catch (err) {
          console.warn('Error en polling de pago:', err);
        }
      }, 3000);
    } catch (err) {
      if (!cancelled) onError(err as Error);
    }
  };

  start();

  return {
    cancel: () => {
      cancelled = true;
      if (intervalId) clearInterval(intervalId);
    },
  };
};