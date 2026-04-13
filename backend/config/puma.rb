# Puma configuration for Railway deployment

# Port binding for Railway
port ENV.fetch("PORT", 3000)

# Environment
environment ENV.fetch("RAILS_ENV", "production")

# Threads
threads ENV.fetch("RAILS_MAX_THREADS", 5), ENV.fetch("RAILS_MAX_THREADS", 5)

# Workers
workers ENV.fetch("WEB_CONCURRENCY", 1)

# PID file
pidfile ENV.fetch("PIDFILE", "tmp/pids/server.pid")

# Preload application
preload_app!

# Plugin for systemd
plugin :systemd if ENV["RAILS_ENV"] == "production"
