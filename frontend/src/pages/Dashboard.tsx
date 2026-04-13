import { useEffect, useState } from 'react'
import { ShoppingCart, Package, Users, DollarSign, TrendingUp, ArrowUpRight, Loader2 } from 'lucide-react'
import { useAuth } from '../context/AuthContext'
import { useCurrentStore } from '../hooks/useStore'
import api from '../lib/api'

interface Metrics {
  revenue:   { total: string; count: number }
  orders:    { total: number; paid: number }
  products:  { total: number; active: number }
  customers: { total: number; new: number }
  top_products: Array<{ title: string; total_sold: number; total_revenue: string }>
}

export default function Dashboard() {
  const { user } = useAuth()
  const store     = useCurrentStore()
  const [metrics, setMetrics] = useState<Metrics | null>(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    if (!store) return
    api.get(`/stores/${store.id}/dashboard?period=30d`)
      .then(r => setMetrics(r.data))
      .catch(() => {})
      .finally(() => setLoading(false))
  }, [store?.id])

  return (
    <div className="p-8">
      {/* Header */}
      <div className="mb-8">
        <h1 className="text-2xl font-semibold text-gray-900">
          Welcome back, {user?.first_name} 👋
        </h1>
        <p className="mt-1 text-sm text-gray-500">
          Here's what's happening in your store today.
        </p>
      </div>

      {/* Stats grid */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-5 mb-8">
        {[
          { label: 'Revenue (30d)', value: metrics ? `$${metrics.revenue.total}` : '—', icon: DollarSign, color: 'text-green-600', bg: 'bg-green-50' },
          { label: 'Orders (30d)',  value: metrics ? String(metrics.orders.total)    : '—', icon: ShoppingCart, color: 'text-blue-600', bg: 'bg-blue-50' },
          { label: 'Products',      value: metrics ? String(metrics.products.active) : '—', icon: Package, color: 'text-purple-600', bg: 'bg-purple-50' },
          { label: 'Customers',     value: metrics ? String(metrics.customers.total) : '—', icon: Users, color: 'text-orange-600', bg: 'bg-orange-50' },
        ].map(({ label, value, icon: Icon, color, bg }) => (
          <div key={label} className="bg-white rounded-xl border border-gray-200 p-5">
            <div className="flex items-center justify-between mb-3">
              <span className="text-sm font-medium text-gray-500">{label}</span>
              <div className={`w-9 h-9 rounded-lg ${bg} flex items-center justify-center`}>
                <Icon className={`w-5 h-5 ${color}`} />
              </div>
            </div>
            <div className="flex items-end justify-between">
              <span className="text-2xl font-semibold text-gray-900">
                {loading ? <Loader2 className="w-5 h-5 animate-spin text-gray-400" /> : value}
              </span>
              <ArrowUpRight className="w-3.5 h-3.5 text-green-600" />
            </div>
          </div>
        ))}
      </div>

      {/* Recent orders placeholder */}
      <div className="bg-white rounded-xl border border-gray-200">
        <div className="flex items-center justify-between px-6 py-4 border-b border-gray-100">
          <h2 className="text-sm font-semibold text-gray-900">Recent Orders</h2>
          <div className="flex items-center gap-1.5 text-xs font-medium text-brand-600 cursor-pointer hover:underline">
            <TrendingUp className="w-3.5 h-3.5" />
            View all
          </div>
        </div>
        <div className="flex flex-col items-center justify-center py-16 text-center">
          <ShoppingCart className="w-10 h-10 text-gray-300 mb-3" />
          <p className="text-sm font-medium text-gray-500">No orders yet</p>
          <p className="text-xs text-gray-400 mt-1">
            Orders will appear here once customers start purchasing.
          </p>
        </div>
      </div>
    </div>
  )
}
