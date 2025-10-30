// app/success/page.tsx
'use client';

import { useEffect, Suspense } from 'react';
import { useSearchParams } from 'next/navigation';
import { useCartStore } from '@/lib/store';
import Link from 'next/link';
import { CheckCircle } from 'lucide-react';

function SuccessContent() {
  const searchParams = useSearchParams();
  const sessionId = searchParams.get('session_id');
  const clearCart = useCartStore((state) => state.clearCart);

  useEffect(() => {
    // Clear cart after successful payment
    clearCart();
  }, [clearCart]);

  return (
    <main className="min-h-screen bg-gray-50 flex items-center justify-center px-4">
      <div className="max-w-md w-full bg-white rounded-lg shadow-lg p-8 text-center">
        <div className="mb-6">
          <CheckCircle className="mx-auto text-green-500" size={64} />
        </div>
        
        <h1 className="text-3xl font-bold text-gray-900 mb-4">
          Paiement Réussi !
        </h1>
        
        <p className="text-gray-600 mb-2">
          Merci pour votre commande !
        </p>
        
        {sessionId && (
          <p className="text-sm text-gray-500 mb-6">
            ID de session : <code className="bg-gray-100 px-2 py-1 rounded">{sessionId}</code>
          </p>
        )}
        
        <div className="space-y-4">
          <div className="bg-blue-50 border border-blue-200 rounded-lg p-4 text-left">
            <h3 className="font-semibold text-blue-900 mb-2">
              🎉 Prochaines étapes
            </h3>
            <ul className="text-sm text-blue-800 space-y-1">
              <li>✅ Paiement traité par Stripe</li>
              <li>⚡ Webhook envoyé à Lambda</li>
              <li>📦 Commande en cours de traitement (EC2 Worker)</li>
              <li>📧 Email de confirmation à venir</li>
            </ul>
          </div>
          
          <Link
            href="/"
            className="block w-full bg-blue-600 text-white py-3 rounded-lg font-semibold hover:bg-blue-700 transition-colors"
          >
            Retour à la boutique
          </Link>
        </div>
      </div>
    </main>
  );
}

export default function SuccessPage() {
  return (
    <Suspense fallback={
      <div className="min-h-screen bg-gray-50 flex items-center justify-center">
        <div className="text-center">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600 mx-auto mb-4"></div>
          <p className="text-gray-600">Chargement...</p>
        </div>
      </div>
    }>
      <SuccessContent />
    </Suspense>
  );
}