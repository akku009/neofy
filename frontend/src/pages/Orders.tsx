import { useState } from 'react'
import { Search, Filter, ShoppingCart } from 'lucide-react'
import type { Order } from '../types'

const FINANCIAL_BADGE: Record<string, string> = {
  pending:           'bg-yellow-100 text-yellow-700',
  authorized:        'bg-blue-100   text-blue-700',
  partially_paid:    'bg-orange-100 text-orange-700',
  paid:              'bg-green-100  text-green-700',
  partially_refunded:'bg-purple-100 text-purple-700',
  refunded:          'bg-gray-100   text-gray-600',
  voided:            'bg-red-100    text-red-700',
}

const FULFILLMENT_BADGE: Record<string, string> = {
  unfulfilled:          'bg-yellow-100 text-yellow-700',
  partially_fulfilled:  'bg-orange-100 text-orange-700',
  fulfilled:            'bg-green-100  text-green-700',
  restocked:            'bg-gray-100   text-gray-600',
}

export default function Orders() {
  const [orders] = useState<Order[]>([])
  const [search, setSearch] = useState('')

  return (
    <div className="p-8">
      {/* Header */}
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-2xl font-semibold text-gray-900">Orders</h1>
          <p className="mt-1 text-sm text-gray-500">{orders.length} orders</p>
        </div>
      </div>

      {/* Toolbar */}
      <div className="flex items-center gap-3 mb-5">
        <div className="flex-1 relative">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
          <input
            type="text"
            placeholder="Search by order number or email…"
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
        {orders.length === 0 ? (
          <div className="flex flex-col items-center justify-center py-20 text-center">
            <ShoppingCart className="w-10 h-10 text-gray-300 mb-3" />
            <p className="text-sm font-medium text-gray-500">No orders yet</p>
            <p className="text-xs text-gray-400 mt-1">
              Orders will appear here when customers complete a purchase.
            </p>
          </div>
        ) : (
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-gray-100 bg-gray-50">
                <th className="text-left px-6 py-3 text-xs font-medium text-gray-500 uppercase tracking-wider">Order</th>
                <th className="text-left px-6 py-3 text-xs font-medium text-gray-500 uppercase tracking-wider">Date</th>
                <th className="text-left px-6 py-3 text-xs font-medium text-gray-500 uppercase tracking-wider">Customer</th>
                <th className="text-left px-6 py-3 text-xs font-medium text-gray-500 uppercase tracking-wider">Payment</th>
                <th className="text-left px-6 py-3 text-xs font-medium text-gray-500 uppercase tracking-wider">Fulfillment</th>
                <th className="text-right px-6 py-3 text-xs font-medium text-gray-500 uppercase tracking-wider">Total</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-100">
              {orders.map((order) => (
                <tr key={order.id} className="hover:bg-gray-50 cursor-pointer">
                  <td className="px-6 py-4 font-medium text-brand-600">{order.order_number}</td>
                  <td className="px-6 py-4 text-gray-500">
                    {order.processed_at
                      ? new Date(order.processed_at).toLocaleDateString()
                      : new Date(order.created_at).toLocaleDateString()}
                  </td>
                  <td className="px-6 py-4 text-gray-700">{order.email ?? 'Guest'}</td>
                  <td className="px-6 py-4">
                    <span className={`inline-flex items-center px-2 py-0.5 rounded text-xs font-medium capitalize ${FINANCIAL_BADGE[order.financial_status]}`}>
                      {order.financial_status.replace('_', ' ')}
                    </span>
                  </td>
                  <td className="px-6 py-4">
                    <span className={`inline-flex items-center px-2 py-0.5 rounded text-xs font-medium capitalize ${FULFILLMENT_BADGE[order.fulfillment_status]}`}>
                      {order.fulfillment_status.replace('_', ' ')}
                    </span>
                  </td>
                  <td className="px-6 py-4 text-right font-medium text-gray-900">
                    {order.currency} {order.total_price}
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
