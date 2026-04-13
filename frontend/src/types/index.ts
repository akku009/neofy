// ── Auth ──────────────────────────────────────────────────────────────────────
export interface User {
  id: number
  email: string
  first_name: string
  last_name: string
  role: 'owner' | 'admin'
}

// ── Store ─────────────────────────────────────────────────────────────────────
export interface Store {
  id: number
  name: string
  subdomain: string
  currency: string
  plan: 'free' | 'basic' | 'pro' | 'enterprise'
  status: 'active' | 'inactive' | 'suspended'
}

// ── Product ───────────────────────────────────────────────────────────────────
export interface Variant {
  id: number
  title: string
  sku: string | null
  price: string
  compare_at_price: string | null
  inventory_quantity: number
  position: number
}

export interface Product {
  id: number
  title: string
  handle: string
  description: string | null
  product_type: string | null
  vendor: string | null
  status: 'draft' | 'active' | 'archived'
  published_at: string | null
  variants: Variant[]
  created_at: string
  updated_at: string
}

// ── Order ─────────────────────────────────────────────────────────────────────
export interface OrderItem {
  id: number
  title: string
  variant_title: string | null
  sku: string | null
  quantity: number
  price: string
  line_total: string
}

export interface Order {
  id: number
  order_number: string
  email: string | null
  financial_status: string
  fulfillment_status: string
  total_price: string
  currency: string
  processed_at: string | null
  created_at: string
  order_items: OrderItem[]
}

// ── Pagination ────────────────────────────────────────────────────────────────
export interface PaginatedResponse<T> {
  data: T[]
  meta: {
    current_page: number
    total_pages: number
    total_count: number
    per_page: number
  }
}
