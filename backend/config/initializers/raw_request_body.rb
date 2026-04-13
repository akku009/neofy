# Stripe webhook signature verification uses request.body.read to access the
# raw payload bytes. In Rails API mode, request.body is a rewindable StringIO
# so this works without any extra middleware.
#
# IMPORTANT: The Webhooks::StripeController inherits from ActionController::API
# (not ApplicationController), so Rails' JSON param parsing does NOT consume
# the body before the controller reads it. No extra gems are needed.
#
# If you ever add middleware that reads the body early, add a rewind here:
#   Rails.application.config.middleware.insert_before 0, Rack::Lint

