import { useState, useEffect } from 'react'
import api from '../lib/api'
import type { Store } from '../types'

export function useStores() {
  const [stores, setStores] = useState<Store[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    api.get('/stores')
      .then(res => setStores(res.data))
      .catch(err => setError(err.response?.data?.error || 'Failed to load stores'))
      .finally(() => setLoading(false))
  }, [])

  return { stores, loading, error }
}

export function useCurrentStore() {
  const { stores } = useStores()
  // Returns the first active store (can be enhanced to support store selection)
  return stores.find(s => s.status === 'active') || stores[0] || null
}
