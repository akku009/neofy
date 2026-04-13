class Current < ActiveSupport::CurrentAttributes
  # Set once per request in ApplicationController before_action hooks.
  attribute :store       # The resolved Store from subdomain or store_id param
  attribute :user        # The authenticated User from JWT
  attribute :request_id  # For tracing / logging
end
