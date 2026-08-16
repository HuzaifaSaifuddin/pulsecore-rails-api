# API-only applications omit browser session middleware by default.
# Restore cookie and session support for Devise's cookie-based authentication.

Rails.application.configure do
  config.middleware.use ActionDispatch::Cookies

  config.session_store :cookie_store, key: "_pulse_core_session"
  config.middleware.use config.session_store, config.session_options
end
