# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Rails **API-only** backend for PulseCore, a multi-tenant Hospital Management System. The React
SPA client lives in a sibling repo at `~/React/pulse_core` and is built in lockstep against the
same spec. This repo owns the API contract — response/error shapes are load-bearing for the SPA.

The full domain spec is `PulseCore_Rails_React_Port_Brief.md` (section refs like "§4" throughout
the code point at it). Read the relevant section before changing behavior in that area.

> The previous CLAUDE.md was a long-form mentoring journal (curriculum, checkpoints, decision
> log). It was cleared 2026-08-29; recover it from git history (`git show HEAD:CLAUDE.md` before
> that commit) if you need the rationale behind a past decision.

## Commands

```
bin/setup                      # install gems, prepare DB (pass --skip-server to not boot)
bin/rails db:seed              # idempotent; dev re-generates patients/appointments/admissions each run
bin/rails server               # or bin/dev
bundle exec rspec              # full suite
bundle exec rspec spec/requests/api/v1/appointments_spec.rb          # one file
bundle exec rspec spec/models/user_spec.rb:42                        # one example by line
bin/rubocop                    # lint (rubocop-rails-omakase + spec/ double-quote override)
bin/brakeman --no-pager        # security static analysis
bin/bundler-audit              # gem CVE scan
bin/ci                         # what CI runs: setup, rubocop, bundler-audit, brakeman
```

Note: **CI does not run RSpec** (see `config/ci.rb` / `.github/workflows/ci.yml`) — run it
locally before pushing. RSpec uses transactional fixtures and `maintain_test_schema!`, so a
schema change just needs `db:migrate` (test DB auto-syncs on next run).

Stack: Ruby 3.3.11 (mise), Rails 8.1, PostgreSQL 16+, Puma. Solid Queue/Cache/Cable are in the
Gemfile but not yet wired into app logic.

## Architecture

### Multi-tenancy is the security boundary (§4) — do not weaken

Every `/api/v1` read and write is filtered through a `visible_to(current_user)` scope. **There
is no admin/superuser bypass, anywhere, ever.** A record outside the caller's scope must
**404** (via `ActiveRecord::RecordNotFound` → `{ error: "Not found" }` in
`ApplicationController`), never 403, never a leak.

Two scope shapes:

- **Org-scoped** (`Organization`, `Facility`, `User`, `Patient`): visible if
  `organization_id == current_user.organization_id`.
- **Facility-scoped** (`Appointment`, `Admission`): visible if `facility_id` is in
  `current_user.accessible_facilities`.

`User#accessible_facilities` (`app/models/user.rb`): org_admin → every facility in the org (no
membership rows needed); everyone else → only their explicit `FacilityMembership` facilities.
The facility-id list is cached in `Rails.cache` for 1 hour, invalidated by `after_commit` hooks
on `User#role` changes and `FacilityMembership` create/destroy. If you add a path that changes
who can see what, make sure it busts `User.accessible_facilities_cache_key(user_id)`.

Cross-org association integrity is also enforced at the model layer: `Appointment`/`Admission`
validate that patient, facility, doctor, and `notes_updated_by` all share one organization;
`User` validates `default_facility` is in-org.

### Current Facility (§5)

Facility-scoped screens operate against `current_user.default_facility` — there is no
per-request facility param. `Api::V1::BaseController#require_current_facility!` returns **409**
(`{ error: "No current facility selected" }`) when it's unset; the SPA intercepts that to route
to a facility picker. It's auto-set only in the unambiguous case (user has none + exactly one
accessible facility) on login (`Users::SessionsController`) and after membership changes
(`User#assign_facility_memberships`); otherwise the user picks via `PATCH /api/v1/me`.

### Auth: cookie-session Devise, not JWT

Devise with only `:database_authenticatable, :recoverable, :validatable`. API-only Rails omits
session middleware, so `config/initializers/session_store.rb` adds `ActionDispatch::Cookies` +
`:cookie_store` back. The SPA must send `credentials: 'include'` and `Accept: application/json`
on every request. `config/initializers/cors.rb` allows an explicit origin list only
(`SPA_ORIGIN`, `SPA_PRODUCTION_ORIGIN`) — never a wildcard, because `credentials: true`.

- `Users::SessionsController` / `Users::PasswordsController` subclass Devise controllers and
  re-render as JSON; mounted at `/users/sign_in`, `/users/sign_out`, `/users/password`.
- `Users::SignupsController` (`POST /api/v1/signup`) is the **only unauthenticated app
  endpoint** and the **only way an Organization is created** — one atomic transaction creating
  Organization + a starter Facility + the org_admin User, then signs them in. `Organization`
  has no CRUD controller by design.
- `Devise.config.paranoid = true` — password-reset responses don't reveal whether an email
  exists.

### Controllers

`Api::V1::BaseController` → `authenticate_user!` + `require_org_admin!` (403) +
`require_current_facility!` (409) helpers. All concrete controllers are thin and follow one
shape: scope via `visible_to`, build through the tenant association
(`current_user.organization.patients.build`, `current_user.default_facility.appointments.build`
— tenant fields are never mass-assigned from params), render `{ resource: ... }` or
`{ resources: [...] }`, or `{ errors: [strings] }` with **422** (`:unprocessable_content`) on
validation failure.

Role gating: `facilities` and `users` writes are org_admin-only; `patients` and the booking
flow are open to any authenticated staff (front-desk work, not org administration).

Status workflows (`Appointment`, `Admission`) are **fixed-forward** state machines
(`NEXT_STATUS`/`PREVIOUS_STATUS` constants) driven by dedicated member actions —
`advance_status` / `revert_status` / `cancel` / `uncancel` — never a plain `status=` in
`update` params. The model transition methods return `false` for both a business-rule no-op and
a validation failure; `perform_transition` renders both as the standard 422 shape.

### Serializers

Hand-rolled POROs in `app/serializers/` (no gem — the exact JSON shape stays visible in this
repo). Subclass `ApplicationSerializer`, implement `as_json(*)`, use
`.render_collection(relation)` for lists. `Appointment`/`Admission` serializers nest full
`patient` and `doctor` objects, so their controllers `includes(:patient, doctor:
:facility_memberships)` to avoid N+1.

### Data model notes

- UUID primary keys everywhere (`config.generators` sets `primary_key_type: :uuid`; pgcrypto
  `gen_random_uuid()`). FK columns are UUID automatically via `t.references`.
- `role`, `gender`, `status` are string columns with Rails `enum` macros (not native PG enums).
  A bad enum value from params raises `ArgumentError`, caught in `ApplicationController` → 422.
- `Patient#mrn` is auto-generated (`P-000001`, per-org sequence, `organization.lock!` for
  concurrency) — never client-settable.
- `config.time_zone = "Asia/Kolkata"`. Use `Time.current` / `Date.current`, never
  `Time.now` / `Date.today`.

## Testing

RSpec (`spec/`), not Minitest. `factory_bot_rails`, no shoulda-matchers, no fixtures. Support:
`spec/support/authentication_helpers.rb` (`sign_in_as(user, password:)`),
`spec/support/shared_examples.rb` (facility-scoped 404 behavior),
`spec/support/query_helpers.rb`. `TimeHelpers` is included with an auto `travel_back`.
`rails_helper.rb` touches `Devise.mappings` before the suite to dodge a Rails 8 lazy-route /
Warden first-auth bug (local/test only; production uses `eager_load = true`).

Request specs under `spec/requests/api/v1/` are the contract tests — assert exact status codes
and body shapes, and the §4 cross-tenant 404 behavior for every action.

## Conventions

- Commit messages: subject line only — no body, no `Co-Authored-By` trailer.
- Do not reference the Django implementation in code comments or commit messages.
- Non-goals (§3), do not build: EMR, Billing, Pharmacy, Lab, Radiology, Inventory, ward/bed
  inpatient, Insurance, Staff Scheduling, a generic state-machine engine, a roles/permissions
  gem.
