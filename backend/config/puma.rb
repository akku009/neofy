# ── Puma production configuration ────────────────────────────────────────────
# Neofy uses Puma in cluster mode (multiple worker processes + threads per worker).
# This provides both concurrency (threads) and parallelism (workers/processes),
# which is critical for a multi-tenant SaaS with background I/O.

# Max threads per worker.  Keep threads ≤ DB pool size.
max_threads = ENV.fetch("PUMA_MAX_THREADS", 5).to_i
min_threads = ENV.fetch("PUMA_MIN_THREADS", 5).to_i
threads min_threads, max_threads

# Number of worker processes.
# Rule of thumb: 2 × CPU cores for I/O-heavy Rails apps.
# Temporarily disabled for deployment debugging
workers 0

# Port / socket
# Render uses PORT env var, even in production
port ENV.fetch("PORT", 3000)

# PID file (used by systemd for process management)
pidfile ENV.fetch("PIDFILE", "tmp/pids/server.pid")

# State file (needed for phased restart: `pumactl phased-restart`)
state_path ENV.fetch("PUMA_STATE", "tmp/pids/puma.state")

# Activate control app for zero-downtime restarts
activate_control_app

# Pre-load the application in the master process.
# Workers then fork, sharing the code — reduces boot time and memory.
# Temporarily disabled to debug deployment issues
# preload_app!

# Re-establish DB connections in each worker after fork
on_worker_boot do
  ActiveRecord::Base.establish_connection if defined?(ActiveRecord)
end

# Gracefully close connections when a worker is shutting down
on_worker_shutdown do
  ActiveRecord::Base.connection_pool.disconnect! if defined?(ActiveRecord)
end

# Log worker events in production
on_worker_fork   { |_| Rails.logger.info("[Puma] Worker forked") }
after_worker_fork { |_| Rails.logger.info("[Puma] Worker ready") }

# Plugin for systemd watchdog / sd_notify (tells systemd the app is ready)
plugin :systemd if ENV["RAILS_ENV"] == "production" || ENV["RACK_ENV"] == "production"
