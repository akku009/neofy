class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch("MAILER_FROM", "noreply@neofy.com")
  layout false  # No layout — each mailer builds its own HTML

  private

  def neofy_email_wrapper(title:, &block)
    content = capture(&block) if block_given?
    # Inline styles for email client compatibility
  end
end
