# PulseCore

Rails API-only backend for PulseCore, a multi-tenant Hospital Management System. See
`CLAUDE.md` for the project's curriculum/progress notes and `PulseCore_Rails_React_Port_Brief.md`
for the full domain spec.

The React SPA lives in a sibling repo at `~/React/pulse_core` and is the client for this API.

## Requirements

* Ruby 3.3.11 (managed via mise)
* Rails 8.1.3.1
* PostgreSQL 16+

## Setup

```
bundle install
bin/rails db:create db:migrate
bin/rails db:seed
```

`db:seed` is safe to run more than once. Organization/Facility/User records are
upserted (passwords are reset to the default every run); Patient/Appointment/Admission
are regenerated on every run in development only, so seeded dates stay relative to
today.

## Seed logins

Every seeded user's password is `pulsecore123`. Two organizations are seeded, each
with an org_admin, one doctor per facility, and a receptionist, e.g.:

* `admin@apollohospitals.com` (org_admin)
* `doctor1@apollohospitals.com` / `doctor2@apollohospitals.com` (doctor)
* `reception@apollohospitals.com` (receptionist)

Fortis Healthcare is seeded the same way at `@fortishealthcare.com`. Run `bin/rails
db:seed` to see the full generated list, including per-organization patient/
appointment/admission counts.

## Running tests

```
bundle exec rspec
```

## Running the server

```
bin/rails server
```

The API is CORS-configured for a browser SPA running at `SPA_ORIGIN` (defaults to
`http://localhost:5173`). Auth is cookie-session based (Devise), so the SPA must send
requests with `credentials: 'include'`.

## Environment variables

* `SPA_ORIGIN` — allowed CORS origin for local development (default `http://localhost:5173`)
* `SPA_PRODUCTION_ORIGIN` — allowed CORS origin in production (unset until deployment)
