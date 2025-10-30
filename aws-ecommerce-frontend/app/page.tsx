// app/page.tsx
import { getServerStripe } from '@/lib/stripe';
import ProductCard from '@/components/ProductCard';
import Cart from '@/components/Cart';

async function getProducts() {
  const stripe = getServerStripe(); // ← Ajouter cette ligne
  
  const products = await stripe.products.list({
    active: true,
    expand: ['data.default_price'],
  });

  return products.data.map((product) => {
    const price = product.default_price as any;
    return {
      id: product.id,
      name: product.name,
      description: product.description,
      price: price?.unit_amount || 0,
      currency: price?.currency || 'eur',
      image: product.images[0] || '/placeholder.png',
      priceId: price?.id || '',
    };
  });
}

export default async function Home() {
  const products = await getProducts();

  return (
    <main className="min-h-screen bg-gray-50">
      <Cart />
      
      {/* Header */}
      <header className="bg-white shadow-sm">
        <div className="container mx-auto px-4 py-6">
          <h1 className="text-3xl font-bold text-gray-900">
            🛍️ AWS E-commerce
          </h1>
          <p className="text-gray-600 mt-2">
            Plateforme e-commerce sur AWS Cloud
          </p>
        </div>
      </header>

      {/* Products Grid */}
      <div className="container mx-auto px-4 py-8">
        <h2 className="text-2xl font-bold mb-6">Nos Produits</h2>
        
        {products.length === 0 ? (
          <div className="text-center py-12">
            <p className="text-gray-600 text-lg">
              Aucun produit disponible pour le moment.
            </p>
            <p className="text-gray-500 text-sm mt-2">
              Créez des produits dans votre{' '}
              <a
                href="https://dashboard.stripe.com/test/products"
                target="_blank"
                rel="noopener noreferrer"
                className="text-blue-600 hover:underline"
              >
                Stripe Dashboard
              </a>
            </p>
          </div>
        ) : (
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-6">
            {products.map((product) => (
              <ProductCard key={product.id} product={product} />
            ))}
          </div>
        )}
      </div>

      {/* Footer */}
      <footer className="bg-white border-t mt-12">
        <div className="container mx-auto px-4 py-6 text-center text-gray-600">
          <p>© 2025 AWS E-commerce Project - IMT CI3</p>
        </div>
      </footer>
    </main>
  );
}