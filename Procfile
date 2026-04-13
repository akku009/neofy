# Railway deployment configuration
release: {
  setDefaultEnvironment: "production"
}

# Build and start Rails application
web: cd backend && bundle exec puma -C config/puma.rb && bundle exec rails db:migrate
