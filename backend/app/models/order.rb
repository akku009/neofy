class Order < ApplicationRecord
  include TenantScoped
  include SoftDeletable

  belongs_to :customer, optional: true  # nil = guest checkout
  has_many   :order_items, dependent: :destroy
  has_one    :payment,     dependent: :destroy

  # financial_status: 0=pending, 1=authorized, 2=partially_paid, 3=paid,
  #                   4=partially_refunded, 5=refunded, 6=voided
  enum :financial_status, {
    pending: 0, authorized: 1, partially_paid: 2, paid: 3,
    partially_refunded: 4, refunded: 5, voided: 6
  }, prefix: true

  # fulfillment_status: 0=unfulfilled, 1=partially_fulfilled, 2=fulfilled, 3=restocked
  enum :fulfillment_status, {
    unfulfilled: 0, partially_fulfilled: 1, fulfilled: 2, restocked: 3
  }, prefix: true

  # cancel_reason: 0=customer, 1=fraud, 2=inventory, 3=declined, 4=other
  enum :cancel_reason, {
    customer: 0, fraud: 1, inventory: 2, declined: 3, other: 4
  }, prefix: true, allow_nil: true

  validates :order_number,  presence: true, uniqueness: { scope: :store_id }
  validates :total_price,   numericality: { greater_than_or_equal_to: 0 }
  validates :currency,      presence: true

  before_validation :assign_order_number, on: :create

  # ── Scopes ───────────────────────────────────────────────────────────────────
  scope :filter_by_financial_status,   ->(s) { s.present? ? where(financial_status: s)   : all }
  scope :filter_by_fulfillment_status, ->(s) { s.present? ? where(fulfillment_status: s) : all }
  scope :pending,    -> { where(financial_status: :pending)  }
  scope :paid,       -> { where(financial_status: :paid)     }
  scope :cancelled,  -> { where.not(cancelled_at: nil)       }
  scope :open,       -> { where(cancelled_at: nil)           }

  # ── Helpers ──────────────────────────────────────────────────────────────────
  def cancellable?
    financial_status_pending? || financial_status_authorized?
  end

  def paid?
    financial_status_paid?
  end

  def items_count
    order_items.size
  end

  private

  def assign_order_number
    return if order_number.present?

    self.order_number = generate_unique_order_number
  end

  def generate_unique_order_number
    loop do
      next_number = TenantScoped.with_bypass do
        store.orders.with_deleted.count + 1001
      end
      candidate = "##{next_number}"
      exists = TenantScoped.with_bypass { store.orders.with_deleted.exists?(order_number: candidate) }
      break candidate unless exists
    end
  end
end
