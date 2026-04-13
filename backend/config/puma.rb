# Minimal Puma configuration for deployment debugging

# Port binding for Render
port ENV.fetch("PORT", 3000)

# Environment
environment ENV.fetch("RAILS_ENV", "production")

# Threads
threads ENV.fetch("RAILS_MAX_THREADS", 5), ENV.fetch("RAILS_MAX_THREADS", 5)

# PID file
pidfile ENV.fetch("PIDFILE", "tmp/pids/server.pid")

# Plugin for systemd
plugin :systemd if ENV["RAILS_ENV"] == "production"
