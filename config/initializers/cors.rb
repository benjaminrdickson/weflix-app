# Be sure to restart your server when you modify this file.

# Avoid CORS issues when API is called from the frontend app.
# Handle Cross-Origin Resource Sharing (CORS) in order to accept cross-origin AJAX requests.

# Read more: https://github.com/cyu/rack-cors

allowed_origins = if Rails.env.production?
  ENV.fetch("FRONTEND_URL", "").split(",").map(&:strip).reject(&:empty?)
else
  ["localhost:8081", "localhost:3000", "http://localhost:8081", "http://localhost:3000"]
end

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins(*allowed_origins)

    resource '*',
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options, :head]
  end
end
