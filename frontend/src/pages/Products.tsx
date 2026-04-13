import { useState, useEffect } from 'react'
import { Plus, Search, Filter, MoreHorizontal, Package, Loader2 } from 'lucide-react'
import type { Product } from '../types'
import { useCurrentStore } from '../hooks/useStore'
import api from '../lib/api'

const STATUS_BADGE: Record<string, string> = {
  active:   'bg-green-100 text-green-700',
  draft:    'bg-gray-100 text-gray-600',
  archived: 'bg-red-100 text-red-700',
}

export default function Products() {
  const store = useCurrentStore()
  const [products, setProducts] = useState<Product[]>([])
  const [loading, setLoading]   = useState(true)
  const [search, setSearch]     = useState('')

  useEffect(() => {
    if (!store) return
    api.get(`/stores/${store.id}/products`, { params: { q: search || undefined } })
      .then(r => setProducts(r.data.products ?? r.data))
      .catch(() => {})
      .finally(() => setLoading(false))
  }, [store?.id, search])

  return (
    <div className="p-8">
      {/* Header */}
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-2xl font-semibold text-gray-900">Products</h1>
          <p className="mt-1 text-sm text-gray-500">{products.length} products</p>
        </div>
        <button className="inline-flex items-center gap-2 bg-brand-600 hover:bg-brand-700 text-white text-sm font-medium px-4 py-2 rounded-lg transition-colors">
          <Plus className="w-4 h-4" />
          Add product
        </button>
      </div>

      {/* Toolbar */}
      <div className="flex items-center gap-3 mb-5">
        <div className="flex-1 relative">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
          <input
            type="text"
            placeholder="Search products…"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            className="w-full pl-9 pr-4 py-2 text-sm border border-gray-200 rounded-lg bg-white focus:outline-none focus:ring-2 focus:ring-brand-500 focus:border-transparent"
          />
        </div>
        <button className="inline-flex items-center gap-2 border border-gray-200 bg-white text-sm text-gray-600 px-3 py-2 rounded-lg hover:bg-gray-50 transition-colors">
          <Filter className="w-4 h-4" />
          Filter
        </button>
      </div>

      {/* Table */}
      <div className="bg-white rounded-xl border border-gray-200 overflow-hidden">
        {loading ? (
          <div className="flex items-center justify-center py-20">
            <Loader2 className="w-6 h-6 animate-spin text-gray-400" />
          </div>
        ) : products.length === 0 ? (
          <div className="flex flex-col items-center justify-center py-20 text-center">
            <Package className="w-10 h-10 text-gray-300 mb-3" />
            <p className="text-sm font-medium text-gray-500">No products yet</p>
            <p className="text-xs text-gray-400 mt-1 mb-5">
              Add your first product to start selling.
            </p>
            <button className="inline-flex items-center gap-2 bg-brand-600 hover:bg-brand-700 text-white text-sm font-medium px-4 py-2 rounded-lg transition-colors">
              <Plus className="w-4 h-4" />
              Add product
            </button>
          </div>
        ) : (
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-gray-100 bg-gray-50">
                <th className="text-left px-6 py-3 text-xs font-medium text-gray-500 uppercase tracking-wider">Product</th>
                <th className="text-left px-6 py-3 text-xs font-medium text-gray-500 uppercase tracking-wider">Status</th>
                <th className="text-left px-6 py-3 text-xs font-medium text-gray-500 uppercase tracking-wider">Inventory</th>
                <th className="text-left px-6 py-3 text-xs font-medium text-gray-500 uppercase tracking-wider">Type</th>
                <th className="px-6 py-3" />
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-100">
              {products.map((product) => (
                <tr key={product.id} className="hover:bg-gray-50 cursor-pointer">
                  <td className="px-6 py-4">
                    <div className="flex items-center gap-3">
                      <div className="w-10 h-10 bg-gray-100 rounded-lg flex items-center justify-center">
                        <Package className="w-4 h-4 text-gray-400" />
                      </div>
                      <div>
                        <p className="font-medium text-gray-900">{product.title}</p>
                        <p className="text-xs text-gray-400">{product.variants.length} variant{product.variants.length !== 1 ? 's' : ''}</p>
                      </div>
                    </div>
                  </td>
                  <td className="px-6 py-4">
                    <span className={`inline-flex items-center px-2 py-0.5 rounded text-xs font-medium capitalize ${STATUS_BADGE[product.status]}`}>
                      {product.status}
                    </span>
                  </td>
                  <td className="px-6 py-4 text-gray-600">
                    {product.variants.reduce((sum, v) => sum + v.inventory_quantity, 0)} in stock
                  </td>
                  <td className="px-6 py-4 text-gray-500">{product.product_type ?? '—'}</td>
                  <td className="px-6 py-4 text-right">
                    <button className="p-1.5 rounded hover:bg-gray-100 text-gray-400">
                      <MoreHorizontal className="w-4 h-4" />
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>
    </div>
  )
}
