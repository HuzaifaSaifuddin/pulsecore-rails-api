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

Facility setup per seeded org: each doctor is a member of exactly one facility (and
has it as their current facility); the **receptionist is a member of every facility
and has no current facility set** — a ready-made account for exercising the
"choose a facility" step and `PATCH /api/v1/me`.

## API

All application endpoints are under `/api/v1` and require an authenticated session
except `POST /api/v1/signup`. Auth-related routes (`/users/sign_in`, `/users/sign_out`,
`/users/password`) are Devise-mounted at the top level.

* `POST /api/v1/signup` — the only way an Organization is created (atomic
  Organization + starter Facility + org_admin User), and the only unauthenticated
  endpoint.
* `GET /api/v1/me` — current user + current facility + accessible facilities. The SPA
  calls this on boot to decide login-vs-dashboard (the session cookie is `HttpOnly`).
* `PATCH /api/v1/me` — the user sets their own current facility to one of their
  accessible facilities.
* `facilities`, `users` — org-scoped; any staff can read, org_admin-only to write.
  `users` create/update also manage facility memberships (`facility_ids`).
* `patients` — org-scoped; any staff can read and write.
* `appointments`, `admissions` — scoped to the caller's current facility; include the
  status-workflow actions (`advance_status` / `revert_status` / `cancel` / `uncancel`).

`CLAUDE.md`'s "Actual API surface" section is the authoritative contract (exact request/
response/error shapes) — keep it in sync when changing endpoints.

### Auth model

Cookie-session via Devise (`database_authenticatable`), not JWT. The SPA must send
`credentials: 'include'` on every request and set `Accept: application/json`. On login,
if the user has exactly one accessible facility and no current facility, it's set
automatically; otherwise the SPA routes to the facility picker.

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
