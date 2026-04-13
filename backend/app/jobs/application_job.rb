class ApplicationJob < ActiveJob::Base
  # Discard jobs that fail due to a missing record — no point retrying.
  discard_on ActiveRecord::RecordNotFound

  # Retry transient failures (network, DB locks) up to 3 times with exponential backoff.
  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  # Log job lifecycle for observability.
  before_perform { |job| Rails.logger.info("[Job] Starting #{job.class.name} (#{job.job_id})") }
  after_perform  { |job| Rails.logger.info("[Job] Completed #{job.class.name} (#{job.job_id})") }
end
