class Product < ApplicationRecord
  include TenantScoped
  include SoftDeletable

  has_many :variants, dependent: :destroy

  # 0=draft, 1=active, 2=archived
  enum :status, { draft: 0, active: 1, archived: 2 }, prefix: true

  validates :title, presence: true, length: { maximum: 255 }
  validates :handle, presence: true,
                     uniqueness: { scope: :store_id },
                     format: {
                       with: /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/,
                       message: "only allows lowercase letters, numbers, and hyphens"
                     }

  before_validation :generate_handle, if: -> { handle.blank? && title.present? }

  # ── Scopes ───────────────────────────────────────────────────────────────────
  scope :published,       -> { where.not(published_at: nil).where("published_at <= ?", Time.current) }
  scope :filter_by_status, ->(status) { status.present? ? where(status: status) : all }
  scope :search,          ->(query) {
    return all if query.blank?
    where("title LIKE :q OR description LIKE :q OR vendor LIKE :q", q: "%#{sanitize_sql_like(query)}%")
  }

  # ── Helpers ──────────────────────────────────────────────────────────────────
  def tags_array
    tags.to_s.split(",").map(&:strip).reject(&:empty?)
  end

  def publish!
    update!(status: :active, published_at: Time.current)
  end

  def unpublish!
    update!(status: :draft, published_at: nil)
  end

  def in_stock?
    variants.sum(:inventory_quantity).positive?
  end

  def to_template_hash
    first_variant = variants.first
    {
      "id"          => id,
      "title"       => title,
      "description" => description.to_s,
      "handle"      => handle,
      "vendor"      => vendor.to_s,
      "product_type" => product_type.to_s,
      "tags"        => tags_array.join(", "),
      "status"      => status,
      "price"       => first_variant&.price&.to_s || "0.00",
      "in_stock"    => in_stock?,
      "currency"    => TenantScoped.with_bypass { store&.currency } || "USD"
    }
  end

  private

  def generate_handle
    self.handle = title.downcase
                       .gsub(/[^a-z0-9\s\-]/, "")
                       .gsub(/\s+/, "-")
                       .squeeze("-")
                       .delete_prefix("-")
                       .delete_suffix("-")
  end
end
