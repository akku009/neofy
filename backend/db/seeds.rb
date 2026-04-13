require "faker"

# ── Idempotent — safe to re-run ──────────────────────────────────────────────
puts "Seeding Neofy development data..."

# ── Plans ─────────────────────────────────────────────────────────────────────
PLAN_SEEDS = [
  { name: "Free",     price_monthly: 0,     price_yearly: 0,     features: Plan::FREE_FEATURES,     sort_order: 0 },
  { name: "Basic",    price_monthly: 29,    price_yearly: 290,   features: Plan::BASIC_FEATURES,    sort_order: 1 },
  { name: "Grow",     price_monthly: 79,    price_yearly: 790,   features: Plan::GROW_FEATURES,     sort_order: 2 },
  { name: "Advanced", price_monthly: 199,   price_yearly: 1990,  features: Plan::ADVANCED_FEATURES, sort_order: 3 }
].freeze

PLAN_SEEDS.each do |attrs|
  Plan.find_or_create_by!(name: attrs[:name]) do |p|
    p.price_monthly = attrs[:price_monthly]
    p.price_yearly  = attrs[:price_yearly]
    p.features      = attrs[:features]
    p.sort_order    = attrs[:sort_order]
    p.active        = true
  end
end
puts "  Plans seeded: #{Plan.count}"

# ── Platform admin ───────────────────────────────────────────────────────────
admin = TenantScoped.with_bypass do
  User.find_or_create_by!(email: "admin@neofy.com") do |u|
    u.password              = "password123"
    u.password_confirmation = "password123"
    u.first_name            = "Platform"
    u.last_name             = "Admin"
    u.role                  = :admin
    u.confirmed_at          = Time.current
  end
end
puts "  Admin: #{admin.email}"

# ── Demo store owner ─────────────────────────────────────────────────────────
owner = TenantScoped.with_bypass do
  User.find_or_create_by!(email: "demo@neofy.com") do |u|
    u.password              = "password123"
    u.password_confirmation = "password123"
    u.first_name            = "Demo"
    u.last_name             = "Owner"
    u.role                  = :owner
    u.confirmed_at          = Time.current
  end
end
puts "  Owner: #{owner.email}"

# ── Demo store ───────────────────────────────────────────────────────────────
store = TenantScoped.with_bypass do
  Store.find_or_create_by!(subdomain: "demo") do |s|
    s.user        = owner
    s.name        = "Demo Fashion Store"
    s.currency    = "USD"
    s.timezone    = "UTC"
    s.email       = "store@demo.com"
    s.status      = :active
    s.plan        = :free
  end
end
puts "  Store: #{store.name} (#{store.subdomain}.neofy.com)"

# ── Set tenant context for seeding ───────────────────────────────────────────
Current.store = store

# ── Products ─────────────────────────────────────────────────────────────────
PRODUCT_SEEDS = [
  {
    title:        "Classic White Tee",
    description:  "A timeless white cotton t-shirt. Perfect for everyday wear.",
    product_type: "Tops",
    vendor:       "Neofy Basics",
    tags:         "cotton, classic, white, t-shirt",
    status:       :active,
    published_at: Time.current,
    variants: [
      { title: "Small / White",  sku: "CWT-S",  price: 24.99, inventory_quantity: 30, option1: "Small",  option2: "White", position: 1 },
      { title: "Medium / White", sku: "CWT-M",  price: 24.99, inventory_quantity: 50, option1: "Medium", option2: "White", position: 2 },
      { title: "Large / White",  sku: "CWT-L",  price: 24.99, inventory_quantity: 40, option1: "Large",  option2: "White", position: 3 },
      { title: "XL / White",     sku: "CWT-XL", price: 26.99, inventory_quantity: 20, option1: "XL",     option2: "White", position: 4 },
    ]
  },
  {
    title:        "Slim Fit Jeans",
    description:  "Premium slim fit denim jeans. Available in two washes.",
    product_type: "Bottoms",
    vendor:       "Neofy Denim",
    tags:         "jeans, denim, slim-fit",
    status:       :active,
    published_at: Time.current,
    variants: [
      { title: "30x30 / Dark",  sku: "SFJ-30D", price: 79.99, compare_at_price: 99.99, inventory_quantity: 15, option1: "30x30", option2: "Dark Wash",  position: 1 },
      { title: "32x30 / Dark",  sku: "SFJ-32D", price: 79.99, compare_at_price: 99.99, inventory_quantity: 18, option1: "32x30", option2: "Dark Wash",  position: 2 },
      { title: "34x32 / Light", sku: "SFJ-34L", price: 79.99, compare_at_price: 99.99, inventory_quantity: 12, option1: "34x32", option2: "Light Wash", position: 3 },
    ]
  },
  {
    title:        "Minimalist Cap",
    description:  "Structured 6-panel cap with embroidered logo.",
    product_type: "Accessories",
    vendor:       "Neofy Accessories",
    tags:         "cap, hat, accessories, unisex",
    status:       :draft,
    variants: [
      { title: "Black",  sku: "CAP-BLK", price: 34.99, inventory_quantity: 25, option1: "Black",  position: 1 },
      { title: "Navy",   sku: "CAP-NVY", price: 34.99, inventory_quantity: 25, option1: "Navy",   position: 2 },
      { title: "Beige",  sku: "CAP-BGE", price: 34.99, inventory_quantity: 10, option1: "Beige",  position: 3 },
    ]
  }
].freeze

PRODUCT_SEEDS.each do |seed|
  variants_data = seed.delete(:variants) { [] }

  product = TenantScoped.with_bypass do
    Product.find_or_initialize_by(store: store, handle: seed[:title].downcase.gsub(/\s+/, "-"))
  end

  product.assign_attributes(seed)

  if product.new_record?
    product.save!
    variants_data.each { |v| product.variants.create!(v.merge(store: store)) }
    puts "  Created product: #{product.title} (#{variants_data.size} variants)"
  else
    puts "  Skipped (exists): #{product.title}"
  end
end

# ── Clear tenant context ──────────────────────────────────────────────────────
Current.store = nil

puts "\nDone! #{Product.for_platform.count} products, #{Variant.for_platform.count} variants."
puts "Login: demo@neofy.com / password123"
puts "Store: http://demo.lvh.me:3000"
