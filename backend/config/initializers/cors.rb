Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins ENV.fetch("FRONTEND_URL", "http://localhost:5173"),
             /\Ahttps?:\/\/.*\.neofy\.com\z/

    resource "*",
      headers:     :any,
      methods:     %i[get post put patch delete options head],
      credentials: false,
      max_age:     86_400,
      expose:      %w[Authorization]
  end
end
