class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class

  # Ensure UUID is set before create even when the DB default isn't configured.
  before_create :assign_uuid

  private

  def assign_uuid
    self.id ||= SecureRandom.uuid
  end
end
