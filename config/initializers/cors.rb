# Cookie-session auth (Devise database_authenticatable) means the SPA sends credentials on every
# cross-origin request, which requires an explicit allow-list of origins here -- `origins "*"` is
# rejected by browsers once Access-Control-Allow-Credentials is true, so this can never be a
# wildcard. SPA_ORIGIN defaults to Vite's own default dev port (the SPA repo hasn't been
# scaffolded yet, so this is Vite's stock default, not a confirmed value -- update once it picks
# a real one). SPA_PRODUCTION_ORIGIN is unset until checkpoint 10 (deployment) exists.
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins [
      ENV.fetch("SPA_ORIGIN", "http://localhost:5173"),
      ENV["SPA_PRODUCTION_ORIGIN"]
    ].compact

    resource "*",
      headers: :any,
      methods: %i[get post put patch delete options],
      credentials: true
  end
end
