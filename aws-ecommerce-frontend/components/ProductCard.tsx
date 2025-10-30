// components/ProductCard.tsx
'use client';

import Image from 'next/image';
import { Product } from '@/lib/stripe';
import { useCartStore } from '@/lib/store';
import { useState } from 'react';

export default function ProductCard({ product }: { product: Product }) {
  const addItem = useCartStore((state) => state.addItem);
  const [quantity, setQuantity] = useState(1);
  const [added, setAdded] = useState(false);

  const handleAddToCart = () => {
    addItem({ ...product, quantity });
    setAdded(true);
    setTimeout(() => setAdded(false), 2000);
  };

  return (
    <div className="border rounded-lg p-4 hover:shadow-lg transition-shadow">
      <div className="relative w-full h-48 mb-4">
        <Image
          src={product.image || '/placeholder.png'}
          alt={product.name}
          fill
          className="object-cover rounded-md"
        />
      </div>
      
      <h3 className="font-bold text-lg mb-2">{product.name}</h3>
      <p className="text-gray-600 text-sm mb-4 line-clamp-2">
        {product.description}
      </p>
      
      <div className="flex items-center justify-between mb-4">
        <span className="text-2xl font-bold">
          {(product.price / 100).toFixed(2)} €
        </span>
      </div>
      
      <div className="flex gap-2">
        <input
          type="number"
          min="1"
          max="99"
          value={quantity}
          onChange={(e) => setQuantity(Number(e.target.value))}
          className="w-16 px-2 py-1 border rounded"
        />
        <button
          onClick={handleAddToCart}
          className={`flex-1 py-2 px-4 rounded font-semibold transition-colors ${
            added
              ? 'bg-green-500 text-white'
              : 'bg-blue-600 text-white hover:bg-blue-700'
          }`}
        >
          {added ? '✓ Ajouté' : 'Ajouter au panier'}
        </button>
      </div>
    </div>
  );
}