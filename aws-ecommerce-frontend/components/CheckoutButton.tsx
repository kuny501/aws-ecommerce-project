// components/CheckoutButton.tsx
'use client';

import { useState } from 'react';
import { useCartStore } from '@/lib/store';
import { Auth } from 'aws-amplify';

import { useRouter } from 'next/navigation';

export default function CheckoutButton() {
  const [loading, setLoading] = useState(false);
  const items = useCartStore((state) => state.items);
  const router = useRouter();

  const handleCheckout = async () => {
    setLoading(true);

    try {
      // 1. Récupérer le token JWT Cognito
      let token = '';
      try {
        const session = await Auth.currentSession();
        token = session.getIdToken().getJwtToken();
        console.log('✅ Token JWT récupéré');
      } catch (authError) {
        console.error('❌ Pas de session Cognito, redirection vers /auth');
        alert('Veuillez vous connecter pour continuer');
        router.push('/auth');
        setLoading(false);
        return;
      }

      // 2. Call API Gateway avec le token
      const API_URL = process.env.NEXT_PUBLIC_API_GATEWAY_URL;
      
      if (!API_URL) {
        throw new Error('API Gateway URL not configured');
      }
      
      console.log('Calling API:', API_URL);
      console.log('Items:', items);
      
      const response = await fetch(API_URL, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': token, // Ajouter le token JWT dans les en-têtes
        },
        body: JSON.stringify({
          items: items.map((item) => ({
            price: item.priceId,
            quantity: item.quantity,
          })),
        }),
      });

      const data = await response.json();
      console.log('Response:', data);
      
      if (!response.ok) {
        if (response.status === 401 || response.status === 403) {
          // Token invalide ou expiré
          alert('Session expirée. Veuillez vous reconnecter.');
          router.push('/auth');
          return;
        }
        throw new Error(data.error || 'Checkout failed');
      }

      // 3. Redirect to Stripe Checkout URL
      window.location.href = data.url;
      
    } catch (error) {
      console.error('Checkout error:', error);
      alert('Erreur lors du checkout. Veuillez réessayer.');
      setLoading(false);
    }
  };

  return (
    <button
      onClick={handleCheckout}
      disabled={loading}
      className="w-full bg-green-600 text-white py-3 rounded-lg font-semibold hover:bg-green-700 disabled:bg-gray-400 transition-colors"
    >
      {loading ? 'Redirection...' : 'Passer au paiement'}
    </button>
  );
}