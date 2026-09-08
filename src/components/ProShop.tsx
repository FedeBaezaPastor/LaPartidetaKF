import React, { useState } from 'react';
import { ArrowLeft, Users, Palette, Plane, Check, Info, Zap, CreditCard } from 'lucide-react';
import { PaymentSelector } from './PaymentSelector';

interface ProShopProps {
  groupId: string;
  userId: string;
  onBack: () => void;
  onPurchaseComplete: () => void;
}

interface Product {
  type: 'extra_players' | 'premium_branding' | 'weekend_mode';
  icon: React.FC<any>;
  title: string;
  description: string;
  details: string[];
  price: number;
  tooltip: string;
}

const products: Product[] = [
  {
    type: 'extra_players',
    icon: Users,
    title: 'Pack +12 Jugadores',
    description: 'Amplia el limite del grupo de 20 a 32 plazas',
    details: ['32 jugadores maximo', 'Ideal para grandes clubes', 'Pago unico permanente'],
    price: 5000,
    tooltip: 'Aumenta el numero maximo de jugadores que pueden unirse a tu grupo de 20 a 32.',
  },
  {
    type: 'premium_branding',
    icon: Palette,
    title: 'ParTee Premium',
    description: 'Personalizacion de marca para tu club',
    details: ['Escudo del club personalizado', 'Colores personalizados', 'Reglas de apuesta a medida'],
    price: 10000,
    tooltip: 'Activa la personalizacion visual del grupo: escudo, colores y reglas de la gamificacion Hoyo 19.',
  },
  {
    type: 'weekend_mode',
    icon: Plane,
    title: 'ParTee Weekend',
    description: 'Gestion integrada de torneos de viaje',
    details: ['Torneos de 4 a 7 dias', 'Gestion de multiples campos', 'Pago temporal'],
    price: 8000,
    tooltip: 'Activa temporalmente la gestion de torneos de viaje con multiples campos y jornadas.',
  },
];

export const ProShop: React.FC<ProShopProps> = ({ groupId, userId, onBack, onPurchaseComplete }) => {
  const [selectedProduct, setSelectedProduct] = useState<Product | null>(null);
  const [showPayment, setShowPayment] = useState(false);
  const [purchased, setPurchased] = useState<string | null>(null);

  const handleBuy = (product: Product) => {
    setSelectedProduct(product);
    setShowPayment(true);
  };

  const handlePaymentSuccess = async () => {
    if (!selectedProduct) return;
    setPurchased(selectedProduct.type);
    setShowPayment(false);

    // Record purchase in database via supabase
    try {
      const { supabase } = await import('../services/supabaseClient');
      const activeUntil = selectedProduct.type === 'weekend_mode'
        ? new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString()
        : null;

      await supabase.from('pro_shop_purchases').insert({
        group_id: groupId,
        purchased_by: userId,
        product_type: selectedProduct.type,
        amount_paid: selectedProduct.price,
        payment_method: 'lightning',
        status: 'completed',
        active_until: activeUntil,
      });

      if (selectedProduct.type === 'extra_players') {
        await supabase.from('groups').update({ max_players: 32 }).eq('id', groupId);
      } else if (selectedProduct.type === 'premium_branding') {
        await supabase.from('groups').update({ premium_branding: true }).eq('id', groupId);
      } else if (selectedProduct.type === 'weekend_mode') {
        const until = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString();
        await supabase.from('groups').update({ weekend_mode_until: until }).eq('id', groupId);
      }
    } catch {
      // payment still succeeded, record may need retry
    }

    setTimeout(() => {
      onPurchaseComplete();
    }, 2000);
  };

  return (
    <div className="min-h-screen bg-gradient-to-b from-slate-50 to-emerald-50">
      <div className="max-w-lg mx-auto px-4 py-6">
        <button onClick={onBack} className="flex items-center gap-2 text-gray-600 hover:text-gray-800 mb-6">
          <ArrowLeft size={20} />
          Volver
        </button>

        <div className="text-center mb-6">
          <h1 className="text-2xl font-bold text-gray-900">Pro-Shop</h1>
          <p className="text-sm text-gray-500">Ampliaciones para tu Team</p>
        </div>

        {purchased && (
          <div className="bg-emerald-50 border border-emerald-200 rounded-xl p-4 mb-5 text-center">
            <Check className="text-emerald-600 mx-auto mb-2" size={28} />
            <p className="text-sm font-medium text-emerald-800">Compra completada con exito</p>
          </div>
        )}

        <div className="space-y-4">
          {products.map((product, i) => (
            <div key={i} className="bg-white rounded-2xl shadow-lg p-5">
              <div className="flex items-start gap-4 mb-4">
                <div className="w-12 h-12 bg-gradient-to-br from-emerald-100 to-emerald-200 rounded-xl flex items-center justify-center shrink-0">
                  <product.icon size={22} className="text-emerald-700" />
                </div>
                <div className="flex-1">
                  <div className="flex items-center gap-2">
                    <h3 className="font-bold text-gray-900">{product.title}</h3>
                    <InfoTrigger text={product.tooltip} />
                  </div>
                  <p className="text-sm text-gray-500 mt-0.5">{product.description}</p>
                </div>
              </div>

              <ul className="space-y-1 mb-4">
                {product.details.map((d, j) => (
                  <li key={j} className="flex items-center gap-2 text-sm text-gray-600">
                    <Check size={14} className="text-emerald-600" />
                    {d}
                  </li>
                ))}
              </ul>

              <div className="flex items-center justify-between">
                <span className="text-lg font-bold text-gray-900">{product.price} sats</span>
                <button
                  onClick={() => handleBuy(product)}
                  className="bg-emerald-600 hover:bg-emerald-700 text-white font-semibold px-6 py-2.5 rounded-xl transition-colors text-sm"
                >
                  Comprar
                </button>
              </div>
            </div>
          ))}
        </div>

        {showPayment && selectedProduct && (
          <PaymentSelector
            isOpen={showPayment}
            onClose={() => setShowPayment(false)}
            planType="team"
            userId={userId}
            amount={selectedProduct.price}
            description={selectedProduct.title}
            onSuccess={handlePaymentSuccess}
          />
        )}
      </div>
    </div>
  );
};

const InfoTrigger: React.FC<{ text: string }> = ({ text }) => {
  const [show, setShow] = useState(false);
  return (
    <div className="relative inline-block">
      <button
        onMouseEnter={() => setShow(true)}
        onMouseLeave={() => setShow(false)}
        onClick={() => setShow(!show)}
        className="text-gray-400 hover:text-gray-600"
      >
        <Info size={14} />
      </button>
      {show && (
        <div className="absolute z-50 right-0 top-6 w-56 bg-slate-800 text-white text-xs p-2.5 rounded-lg shadow-lg">
          {text}
        </div>
      )}
    </div>
  );
};
