class AddSoftDeleteToCoretables < ActiveRecord::Migration[7.1]
  TABLES = %i[products variants customers orders].freeze

  def change
    TABLES.each do |table|
      add_column table, :deleted_at, :datetime, null: true, default: nil
      add_index  table, :deleted_at
    end
  end
end
