# PulseCore — Rails API port (mentoring project)

## What this repo is

Rails **API-only** backend for PulseCore, a multi-tenant Hospital Management System, originally
specified against a Django + server-rendered app. Full domain spec lives in
`PulseCore_Rails_React_Port_Brief.md` at repo root — **read it in full before resuming work here**;
this file is a condensed index, not a replacement.

This is a **two-repo project**. The React SPA is a sibling repo at `~/React/pulse_core`, built in
lockstep by a separate Claude Code session against the same brief. This repo owns the API contract
— the "actual API surface" section below is load-bearing for that other repo. Keep it accurate.

## My role (Claude) here

I am acting as a senior Rails API mentor for Huzaifa, not an autonomous builder.

- Huzaifa: Lead SWE, 10+ yrs Rails (models/AR, controllers, routes, migrations, Sidekiq, deploy).
  Rusty on RSpec specifically (3 years on Minitest) — treat RSpec as a real refresher, not known-cold.
  New to: API-only Rails, ActiveAdmin, Devise-for-API/SPA.
- Teaching contract — do not violate:
  - Baby steps, zero assumed knowledge of API-only Rails/ActiveAdmin/Devise-for-API.
  - Don't cram — split deep topics across turns/sessions.
  - Hands-on: Huzaifa writes code first, I review. Don't hand him code unless he asks.
  - Quiz at every checkpoint, plus surprise questions mid-build.
  - Stay on-topic: Rails API, ActiveAdmin, Devise, and direct ecosystem only.
  - Give a small solo exercise after each concept, then review his solution.
- Curriculum order (gated by checkpoints, do not skip ahead):
  1. Confirm environment before any code.
  2. Rails API-only structure/config/migrations (`id: :uuid` PKs per brief §2).
  3. Domain models+migrations 1:1 from brief §2, in order: Organization → Facility → User/auth →
     Patient → Appointment → Admission. Don't redesign the domain (fixed-forward-path status
     workflows, same-day/occupancy rules are specified, not up for simplification).
  4. Serialization + `/api/v1` controllers. Nail exact response/error shape (SPA depends on it).
     Every action applies brief §4 visibility scope via plain AR scopes, applied consistently
     (see "Deviations" — Pundit was considered and rejected 2026-08-16). **Minimal Devise
     (session-cookie, `database_authenticatable` only) pulled forward from checkpoint 5** so
     `current_user` is real for these controllers from the start — see "Deviations" below.
  5. Rest of Devise for API/SPA auth beyond the minimal slice pulled into checkpoint 4 (password
     reset flow, any remaining config). Atomic Org+Facility+org_admin signup.
  6. ActiveAdmin: install, mount, register resources, authorization boundary mirroring "no
     admin/superuser bypass on tenant scopes" (brief §4).
  7. OmniAuth: one real provider (Google/GitHub) + account-linking, to close the Devise & OmniAuth
     curriculum.
  8. CORS config for SPA dev + deployed origins.
  9. RSpec (deliberate refresher) — **interleaved starting 2026-08-15, not batched at the end**:
     a model spec accompanies every model as it's built from here on (started with retrofitting
     Organization + Facility). What's left gated to checkpoint 9 proper is only the parts that
     need later checkpoints to exist: request specs proving §4 scopes 404 cross-tenant access
     (needs checkpoint 4 controllers) and the Devise/OmniAuth account-linking spec (needs
     checkpoints 5/7).
  10. Deployment.
- External curricula to cross-reference (Obsidian vault, 6 topics each): `[[ActiveAdmin]]` and
  `[[Devise & OmniAuth]]`. When a checkpoint here satisfies one of their numbered topics, note it
  in the Progress block below.

## Switch signal

Once the Devise auth checkpoint (5) and CORS (8) are done, tell Huzaifa it's time to switch to the React SPA repo (`~/React/pulse_core`) — don't wait for ActiveAdmin/OmniAuth/RSpec first.

## Non-goals (brief §3)

Do not build: EMR, Billing, Pharmacy, Laboratory, Radiology, Inventory, full Inpatient (ward/bed),
Insurance, Staff Scheduling, a generic workflow/state-machine engine, a full roles/permissions gem.

## Key domain rules not to let drift (brief §4, §5) — the parts easy to accidentally simplify away

- **No admin/superuser bypass** on tenant visibility scopes. Ever. An internal ops tool later is a
  separate, audited surface — never a blanket-access flag on the client-facing scopes.
- Org-scoped resources (Organization, Facility, User, Patient): visible if `belongs to
  current_user.organization`. Facility-scoped (Appointment, Admission): visible only if
  `facility_id` in `current_user.accessible_facilities`.
- `accessible_facilities(user)`: org_admin → every facility in org, no explicit membership needed;
  everyone else → explicit Facility membership only. Cache per-request/user, invalidate on
  role/membership change.
- `current_facility` (`User#default_facility`) gates all facility-scoped screens; no per-action
  facility picker. Auto-set on login only if exactly one accessible facility.

## Deviations from the brief (deliberate, revisit if wrong)

- **No nullable-organization "bootstrap/system account" on User** (brief §2 mentions this for
  Django's admin-reuses-User-model pattern). Decided 2026-08-15: ActiveAdmin (checkpoint 6) will
  get its own separate `AdminUser` model instead of authenticating through `User` — consistent
  with brief §4's own "a future ops tool should be a separate, audited surface" principle, and
  reusing `User` for ActiveAdmin login would put a roleless/orgless row in the same table as real
  tenant staff, which is exactly the shape §4 warns against. Consequence: `User.organization_id`,
  `first_name`, `last_name` are all unconditionally required (no conditional/bootstrap exemption),
  and `full_name`'s fallback-to-email branch was removed as dead code. **Revisit explicitly at
  checkpoint 6** if ActiveAdmin ends up needing to reuse `User` for some reason.
- **Minimal Devise pulled forward into checkpoint 4** (decided 2026-08-16). Checkpoint 4's
  controllers need a real `current_user` to apply brief §4 visibility scopes against, but Devise
  was originally checkpoint 5 (after). Rather than build a throwaway `current_user` stub now and
  a real one later, we're doing just the login/logout slice of Devise (`database_authenticatable`,
  session-based) as prep work for checkpoint 4, deferring the rest of checkpoint 5 (password
  reset flow) to when checkpoint 4's controllers are done. **Auth mechanism: cookie-session**, not
  JWT — chosen since both repos are same-project/likely-same-domain in dev and deploy, and it's
  the simplest way to actually learn Devise's native mode rather than immediately reaching for
  `devise-jwt`. SPA repo must send/receive the session cookie (`credentials: 'include'` on
  fetch/XHR) and CORS (checkpoint 8) must allow credentials from the SPA's origin.
- **Plain AR scopes over Pundit for brief §4 visibility** (decided 2026-08-16). Brief allows
  either; picked plain scopes (e.g. `Appointment.visible_to(current_user)`) to avoid adding a new
  gem's DSL on top of Devise being introduced in the same stretch of work — one new library at a
  time. Consequence: role-gated create/update checks (org_admin-only actions) need their own home
  (likely `before_action` guards per controller) since there's no Pundit policy object to hold
  them centrally.
- **Hand-rolled PORO serializers over a gem** (decided 2026-08-16). No Alba/Blueprinter/
  jsonapi-serializer — plain Ruby classes building the JSON hash explicitly, so the exact response
  shape (load-bearing for the SPA repo) is always visible in this repo's own code, not produced by
  a library's DSL.

## Progress

**Current checkpoint:** 4 (serialization + `/api/v1` controllers), in progress. Checkpoint 3
(domain models) complete: Organization ✅ → Facility ✅ → User/auth ✅ → Patient ✅ →
Appointment ✅ → Admission ✅. Mid-way through the minimal-Devise prep pulled forward into this
checkpoint (see "Deviations") is done: gem/migration/module setup, session middleware, a real
JSON-responding `Users::SessionsController` (login/logout), and request specs, all verified live
via `curl` and passing. Along the way, found and fixed a known upstream Rails 8 + Devise lazy-route-
loading bug affecting local dev/test only — confirmed it cannot reach production (`eager_load =
true` there) — see progress notes below, "Flaky first-authentication-after-boot bug". Next
concrete step: `/api/v1` controllers + hand-rolled serializers + plain
AR visibility scopes proper.

- Checkpoint 1: Ruby 3.3.11 (mise), Rails 8.1.3.1, Bundler 4.0.11, Postgres 16.14 confirmed.
- Checkpoint 2 (`d8d6dce`, `8b0461d`): `rails new . --api --database=postgresql --skip-jbuilder
  --skip-test` scaffolded. `pgcrypto` extension enabled via migration. `config.generators` sets
  `primary_key_type: :uuid` — verified this makes both `create_table id: :uuid` AND
  `t.references type: :uuid` the defaults, so FK columns are UUID-typed without hand-specifying.
- Organization (`e6f1f23`): UUID PK, `name` unique — model validation (`uniqueness: true`) +
  DB unique index, both verified (model catches dup, raw SQL insert bypassing the model is
  rejected by the DB index — closes the race-condition gap validation alone can't cover).
- Facility (`46602b6`): `belongs_to :organization` (required, Rails 5+ default — no explicit
  `optional: false` needed), `name` unique **scoped to organization_id** — model
  `uniqueness: { scope: :organization_id }` + composite DB index `[:organization_id, :name]`.
  Verified: same name same org rejected, same name different org allowed, missing org rejected,
  raw SQL bypassing model rejected by DB index.
- Testing infra (`00ecb6f`, `ed84a22`, `376e5d1`): rspec-rails installed, RSpec checkpoint now
  interleaved (see curriculum note above) rather than batched at the end. factory_bot_rails added
  once Facility's spec needed 2+ levels of association setup — factories live in
  `spec/factories/`, `sequence(:name)` used on both Organization/Facility factories since both
  validate name uniqueness. Deliberately no shoulda-matchers (would hide validation logic behind
  a DSL — the opposite of what a rusty-on-RSpec refresher needs) and no Rails fixtures (skip
  validations on insert, global shared mutable state — bad fit once Appointment/Admission specs
  need many small permutations of status/date). Organization + Facility specs (8 examples) pass.
- User + FacilityMembership (`37533f6`): User UUID PK, email unique (validation + DB index),
  `first_name`/`last_name`/`role`/`organization_id` all unconditionally required (see "Deviations
  from the brief" above for why `organization_id` isn't nullable), `default_facility_id` optional
  FK to `facilities` (needed explicit `foreign_key: { to_table: :facilities }` since the column
  name doesn't match Rails' table-name convention). `role` is a string column + Rails `enum` macro
  (`org_admin`/`doctor`/`receptionist`) — chosen over a native Postgres enum type to avoid
  `structure.sql`/`ALTER TYPE` overhead, and matches brief's "flat field, not a permissions gem"
  intent. FacilityMembership is the `has_many :through` join model for User<->Facility (chosen
  over bare HABTM since the brief's "explicit Facility membership" language implies a first-class
  concept), uniqueness on `(user_id, facility_id)` via validation + composite DB index.
- `User#accessible_facilities` (`afd86c5`, brief §4/§5's actual authorization logic): instance
  method, returns an `ActiveRecord::Relation` built from cached facility IDs (can't cache a
  Relation object itself — it's a lazy query object, not serializable). org_admin gets every
  facility in their org; everyone else gets only their explicit `FacilityMembership` facilities.
  Cached via `Rails.cache.fetch("accessible_facilities:#{id}", expires_in: 1.hour)` — 1 hour
  chosen deliberately short since this cache sits on the authorization boundary and the TTL is
  the blast radius if invalidation ever has a bug. Invalidation via `after_commit` (not
  `after_save` — brief §8 specifies this; invalidating on a change that could still roll back
  would be wrong) on User role change (`saved_change_to_role?`-guarded) and on
  FacilityMembership create/destroy (not update — memberships aren't repointed in place in this
  domain). `User.accessible_facilities_cache_key(user_id)` extracted as a class method since both
  models need the same key format. Verified empirically (not assumed) that `after_commit` fires
  correctly under RSpec's default transactional test wrapping in this Rails version — historically
  a real gotcha in older Rails where it silently didn't.
  Specs: 30 examples total now passing across Organization/Facility/User/FacilityMembership.
- Patient pass 1 (`9176903`): UUID PK, `belongs_to :organization` required, deliberately **no**
  Facility FK per brief §2 (shared across an org's facilities — which visit happened where
  belongs on Appointment/Admission, not here). `gender` is a string column + Rails `enum` macro
  (male/female/other), same pattern as `role`. `date_of_birth` kept as a real date column rather
  than a derived/stored age (age decays every birthday; DOB is the durable source fact age can
  always be computed from, and DOB doubles as an identity-verification field alongside name).
  `mrn` has uniqueness (scoped to `organization_id`) validation and a matching composite DB index.
  Also backported the `normalize_names` (whitespace-strip) pattern from Patient to User for
  consistency. Test factories: `sequence(...)` used on every uniqueness-validated field across all
  factories now (name, email, mrn) — same lesson applied consistently after catching it live on
  Organization/Facility once and almost repeating it on Patient's `mrn`.
- Patient pass 2 / `mrn` auto-generation (`2c54a29`): org-scoped sequential `P-000001` format,
  generated in `before_create` — **not** `before_validation`. Rails' `save`/`create` runs `valid?`
  (and thus `before_validation`) *before* opening the transaction that wraps the `INSERT`; only
  `before_save`/`before_create` onward run inside it. A lock taken in `before_validation` would be
  a `SELECT ... FOR UPDATE` with no surrounding transaction — Postgres releases it the instant that
  statement finishes, giving zero real protection against two concurrent creates for the same org
  computing the same "next" number, despite looking like it's protected. `before_create` runs
  inside the save transaction, so `organization.lock!` there correctly serializes concurrent
  generation for the same org. That callback placement forced `validates :mrn, presence: true` off
  `:create` and onto `:update` only — mrn is legitimately blank at pre-generation validate time.
  `organization.patients.maximum(:mrn)` does a lexicographic string max, which happens to equal
  the numeric max here only because of the fixed-width zero-padded format. Added
  `Organization#has_many :patients`, missing from pass 1.
  Known test-suite gap: no true multi-threaded test forces the actual race — race-safety rests on
  reasoned-through Postgres row-lock semantics (and a message-expectation proof that `lock!` is
  called), not a test that reproduces concurrent contention.
  Specs: 48 examples total now passing.
- Appointment pass 1 (shape only, no status workflow methods yet): UUID PK, `patient_id`/
  `facility_id` required, `doctor_id`/`notes_updated_by_id` (FK to User) optional, `status` string
  column + Rails enum (`scheduled`/`arrived`/`in_progress`/`completed`/`cancelled`) defaulting to
  `scheduled` at the DB level, `scheduled_start` required (`null: false` + model presence — both
  layers, matching this project's established double-enforcement pattern), `scheduled_end`
  optional, composite index on `(facility_id, scheduled_start)` for the list view's
  facility+day query.
  **Deviation from the literal brief text (deliberate):** brief §2 states the same-org integrity
  rule ("a Patient and Facility on the same Appointment must belong to the same Organization")
  only for Patient+Facility. Extended the identical check to `doctor` and `notes_updated_by` as
  well — both are FKs to User, and the brief's own stated rationale (defense against a tenant's
  data ending up cross-attributed to another tenant) applies equally to a doctor or note-author
  from a different org being attached to someone else's appointment. Not exercised by any request
  path yet since controllers don't exist until checkpoint 4, but leaving it out would be the same
  shape of tenant-isolation gap brief §4 is otherwise strict about. Implemented as one shared
  private `validate_same_organization(attribute)` helper called from three separate `validate`
  registrations (one per attribute) so each still reports its error on the correct field.
  Factory: `spec/factories/appointments.rb` uses the same transient-`organization` pattern as
  `facility_membership` (patient/facility/doctor all pinned to one shared org via `association
  ..., organization: organization`) — needed here for the same reason FacilityMembership needed
  it: two-plus associations that must agree on tenant for the record to be valid at all.
  Specs: 57 examples total now passing.
- Appointment pass 2 (status workflow, brief §2 complete): app-wide `Time.zone` set to
  `"Asia/Kolkata"` in `config/application.rb` first — needed since "the org's local timezone" in
  the brief maps to a single Rails-app-wide timezone (confirmed against the Django source this is
  ported from, which used `settings.TIME_ZONE` the same way — not a per-organization setting).
  Rails already stores UTC in Postgres and converts to `Time.zone` on read by default
  (`config.load_defaults 8.1`), so this one line was the only change needed; the important
  discipline it imposes is using `Time.current`/`Date.current` everywhere instead of
  `Time.now`/`Date.today`, which read the OS zone and would silently bypass it.
  `advance_status`/`revert_status`/`cancel`/`uncancel` all named without a bang — brief's own
  naming, and deliberately not adopting the AASM-style bang/non-bang event-pair convention: brief
  §2 explicitly calls this workflow "**not** a general workflow/state-machine engine" (echoed in
  this file's Non-goals), so borrowing that convention's machinery was the wrong instinct even
  though the reasoning behind it (bang = raises, non-bang = returns false) is sound elsewhere.
  `advance_status` blocks on `scheduled_start.to_date > Date.current` (future-day guard, brief
  §2); `revert_status` deliberately has **no** such guard ("a late correction the next day is
  fine" — brief's own words, right after describing `advance_status`'s guard). `NEXT_STATUS`/
  `PREVIOUS_STATUS` (`NEXT_STATUS.invert`) hashes drive the two linear-chain methods; `cancel`/
  `uncancel` are simple fixed single-transition guards, no map needed.
  Added the brief's "one active appointment per patient per day" rule
  (`no_conflicting_active_appointment`) and a `scheduled_end > scheduled_start` check
  (`validates :scheduled_end, comparison: { greater_than: :scheduled_start }, allow_nil: true` —
  the latter not literally in the brief's field list, own judgment call, same category as the
  doctor/notes_updated_by same-org extension from pass 1). The conflict check is gated on `status.
  in?(ACTIVE_STATUSES)` (self's *own* status, not just the other appointment's) — without that
  guard a Completed/Cancelled appointment sharing a day with someone else's active appointment
  would incorrectly fail. Query written DHH/Rails-idiom style: `patient.appointments.active.
  same_day_as(scheduled_start).where.not(id: id).exists?` — required adding the missing inverse
  `Patient#has_many :appointments` (same gap as `Organization#has_many :patients` was in Patient
  pass 1), plus `scope :active` and `scope :same_day_as` (using ActiveSupport's `Time#all_day`
  instead of hand-rolling `beginning_of_day...end_of_day`) so the query composes and reads as a
  sentence rather than hitting `Appointment.where(patient_id: ...)` directly.
  `revert_status`/`uncancel` do **not** need their own pre-check for the conflict rule — `update`
  already re-runs every `validate` callback against the *new* status before saving, so letting the
  existing `no_conflicting_active_appointment` validation fail the `update` is sufficient and
  correctly covers both "re-entering active from non-active" and "moving between two already-
  active statuses" (self-excluded via `.where.not(id: id)`, so no false positive on the latter).
  A real gotcha hit and fixed in the specs: asserting object state via `expect(appointment).to
  be_completed` *immediately after* a failed `update` reads a false result — `update` calls
  `assign_attributes` before validating, and a validation failure does **not** roll back that
  in-memory assignment, only the DB write. Any spec asserting state after a blocked
  transition needs `.reload` first to check what's actually persisted.
  Also fixed two crash-level typos caught during review before they ever ran: `ACTIVE_STATUSES =
  [Status.SCHEDULED, ...]` (no such `Status` constant exists — Rails enums don't get a namespaced
  constant class; plain strings matching the column values is the idiomatic reference) and
  `NEXT_STATUS.revert` (`Hash` has no `#revert`; `#invert` was meant).
  Specs: 80 examples total now passing.
- Rubocop (`.rubocop.yml`): extended `Style/StringLiterals`'s `Include` to add `spec/**/*`.
  `rubocop-rails-omakase`'s own default `Include` for that cop is `[app/, config/, lib/, test/,
  Gemfile]` — written for a Minitest `test/` layout, so it silently never applied to this
  project's `spec/` directory at all. Caught only because a run of single-quoted strings crept
  into new spec code without rubocop ever flagging it. Fixing the `Include` list surfaced 10
  pre-existing single-quote offenses in RSpec's own generated boilerplate
  (`spec/rails_helper.rb` and every spec file's `require 'rails_helper'` line); autocorrected,
  no behavior change.
- Admission (brief §2, "structurally a near-twin of Appointment"): same shape/workflow pattern
  ported over — `NEXT_STATUS`/`PREVIOUS_STATUS` now `scheduled→arrived→admitted→discharged`
  (different terminal state than Appointment), same `Cancelled` side-branch off `Scheduled` only,
  same no-bang `advance_status`/`revert_status`/`cancel`/`uncancel` shape, same same-org and
  `admission_end`-after-`admission_start` validations.
  **The one real behavioral difference, and where it's easy to under-build**: the brief splits
  Appointment's single "one active per patient per day" rule into *two* separate rules for
  Admission, because `Arrived`/`Admitted` mean physically occupying a bed right now (unlike
  Appointment's `In Progress`, which is just a same-day status):
  - `no_conflicting_occupying_admission`: self is `Arrived`/`Admitted` → block if the patient has
    *any other* `Arrived`/`Admitted` admission, **no date filter at all** (occupancy is a
    right-now fact, not a same-day one — a patient can't be occupying two beds regardless of what
    day either admission is dated).
  - `no_conflicting_scheduled_admission_same_day`: self is `Scheduled` → block if the patient has
    another **not-yet-resolved** admission (`ACTIVE_STATUSES = scheduled/arrived/admitted`, not
    just other `Scheduled` ones) on the same calendar day — this mirrors Appointment's rule
    exactly once you swap in Admission's active set.
  First pass at this only had the first rule, and had it gated on the *other* record's status
  instead of also gating on *self's own* status — meaning a patient with one ongoing `Arrived`
  admission couldn't have an unrelated `Scheduled` admission created for a month later, which the
  brief never asks for (occupancy is about not having a *second* `Arrived`/`Admitted` stay, not
  about disallowing future planning while one is ongoing). Confirmed via a direct reproduction
  before fixing. The second rule (`Scheduled` same-day) was missing entirely in that pass — a
  patient could have unlimited `Scheduled` admissions stacked on the same day with nothing
  blocking it. Both gaps were masking each other in the original revert_status spec: it built a
  same-day `Scheduled` conflict while reverting into `Admitted`, which triggered *neither* rule as
  originally written, silently passed when it should have failed, and was only caught because the
  test happened to be run and actually failed once written correctly — a good reminder that a
  green suite only proves what the specs actually exercise.
  Specs: 117 examples total now passing (project-wide).
- Minimal Devise, prep for checkpoint 4 (`b85dcae`, `0c09ee1`; see "Deviations" above for why this
  moved earlier than planned): `devise` + `bcrypt` gems, `devise:install`. `--api` mode strips
  `ActionDispatch::Cookies` and session-store middleware from the stack since most APIs are
  stateless — restored both in `config/initializers/session_store.rb` via
  `Rails.application.configure { config.middleware.use ...; config.session_store ...;
  config.middleware.use config.session_store, config.session_options }`. Caught a real bug in the
  first pass here: `config.session_store(:cookie_store, key: ...)` is a *setter* — it does not
  return the resolved middleware class, so `config.middleware.use(config.session_store)` (calling
  it a second time with no args as the *getter*) needs `config.session_options` passed as an
  explicit second argument to `.use`, or the `key:` silently never reaches the middleware instance
  and Rails falls back to its own default cookie name. `bin/rails middleware` will *not* reveal
  this (it only lists middleware classes, not their args) — verified the fix with
  `Rails.application.middleware.find { |m| m.klass == ActionDispatch::Session::CookieStore }.args`
  instead. `config.navigational_formats = []` set in the devise initializer so every auth failure
  (any request format) gets a JSON-style 401 rather than Devise attempting an HTML-redirect that
  has no view/route to land on.
  `User` declares `devise :database_authenticatable, :recoverable, :validatable` — deliberately
  **not** `:registerable` (its self-service signup creates a bare `User` with no organization,
  which conflicts with brief §6's atomic Organization+Facility+org_admin transaction — that stays
  hand-rolled) and **not** `:rememberable` (persistent "remember me" login isn't specified
  anywhere in the brief). `:validatable` kept since nothing else in this codebase validates
  password presence/length — note it now duplicates `User`'s own manual
  `validates :email, presence: true, uniqueness: true`; harmless but flagged as a cleanup
  candidate, not yet done.
  `rails generate devise User` auto-generates a migration assuming a fresh `users` table — this
  project's `users` table already existed (email column + its unique index from `CreateUsers`), so
  the generated migration as-is would have hit a duplicate-column/duplicate-index-name error on
  `db:migrate`. Trimmed it to only the columns that were actually new (`encrypted_password`,
  `reset_password_token`, `reset_password_sent_at`) and dropped the commented-out scaffolding for
  the unused modules (`:trackable`/`:confirmable`/`:lockable`) per this project's no-dead-code
  convention — if one of those gets added later it'll be its own migration anyway. Added
  `password` to the `user` factory now that `:validatable` requires one on create.
  Auth mechanism is cookie-session, not JWT (see "Deviations" and the Auth mechanism decision line
  below) — chosen for less new machinery to build while learning Devise's native mode, and because
  both repos are same-project/likely-same-domain.
  Specs: still 117 examples passing.
- `Users::SessionsController < Devise::SessionsController` (`app/controllers/users/sessions_controller.rb`,
  wired via `devise_for :users, controllers: { sessions: "users/sessions" }`): the actual
  login/logout JSON endpoints. Read Devise's own `sessions_controller.rb`/`failure_app.rb` source
  directly rather than assume behavior, which paid off — two of the three response paths needed
  **zero code**: a failed login never reaches our controller at all (`warden.authenticate!` throws
  straight to `Devise::FailureApp`, whose `http_auth?` branch is forced true once
  `navigational_formats = []`, giving a `401` + `{"error": "..."}"` automatically), and `destroy`'s
  happy path (`respond_to_on_destroy`) already resolves to `head 204` once `navigational_formats`
  is empty — *in principle*. In practice `respond_to_on_destroy` **crashed** (`NoMethodError:
  undefined method 'respond_to'`) — `ActionController::API` doesn't include
  `ActionController::MimeResponds` (verified via `ActionController::API.ancestors.include?(...)`),
  so the block-based `respond_to do |format| ... end` DSL Devise's method body uses simply isn't
  available on an API-only base controller, same underlying theme as the missing session
  middleware caught earlier in this checkpoint. A first pass at this section of these notes
  claimed `destroy` needed no code, based only on tracing the *logic* Devise would run without
  checking whether the method it depends on even exists in this controller ancestry — wrong, and
  corrected the same session it was caught, via `curl` against a real running server rather than
  trusting the read-through. Fixed the same way as the other real gap in this controller
  (`respond_with`, which `create`'s success path needs since the default responder's fallback for
  JSON is effectively `render json: resource` — which would leak `encrypted_password`/
  `reset_password_token` straight into the response body, a real vulnerability, not a style
  nitpick): override just the one missing/unsafe method, let Devise's own `create`/`destroy`/
  `verify_signed_out_user` flow (auth, `sign_in`, `sign_out`, already-signed-out check) run
  untouched. `respond_to_on_destroy(non_navigational_status:)` overridden to unconditionally
  `head non_navigational_status` — behaviorally identical to what the original's `format.all`
  branch would always hit anyway, since `navigational_formats` is empty, just without needing
  `MimeResponds` at all.
  Also caught via `curl`: a request with `Content-Type: application/json` but no `Accept:
  application/json` header gets a degraded plain-string body (`content-type: */*`) instead of the
  JSON shape, because Rails' format negotiation reads `Accept`, not `Content-Type` — **the SPA
  repo's `fetch()` calls must set `Accept: application/json` explicitly, this will bite it
  otherwise.** One flaky `401` was observed on the very first login request immediately after a
  fresh `bin/rails server` boot, not reproduced on 5 immediate retries or on any subsequent test —
  suspected `config.reload_routes`/`Devise.mappings` reload racing the first request in dev mode
  (`eager_load = false` there); not chased further since production runs `eager_load = true`,
  which wouldn't hit this window; flagged here rather than silently ignored.
  Response shapes (source of truth, see below): success →
  `{"user": {"id", "email", "first_name", "last_name", "role", "organization_id",
  "default_facility_id"}}`, status 200. Failure → `{"error": "<message>"}`, status 401. Logout →
  empty body, status 204 (200 if not signed in returns 401 instead, per Devise default).
  **Still open, next up:** `/api/v1` controllers + hand-rolled serializers + plain AR visibility
  scopes proper — this Devise slice was prep work pulled forward, not checkpoint 4 itself.
  Specs: 121 examples passing project-wide, 4 of them `spec/requests/users/sessions_spec.rb`
  covering all four response paths above.
- **Flaky first-authentication-after-boot bug, root cause found and credited** (2026-08-16,
  found by Huzaifa mid-review of the request spec above): the very first `warden.authenticate!`
  call in a freshly booted process fails with the generic "unauthenticated" error even for
  correct credentials — zero DB queries run (confirmed via `test.log`: the strategy never even
  attempts `User.find_by(email:)`) — every request after that succeeds and it never recurs.
  Reproduced deterministically 3/3 times against real `curl`-driven `dev`- and `test`-env Puma
  servers (not an RSpec artifact) before the fix: request #1 always `401`, all following requests
  (49, 49, then 4 in a row) always `200`.
  Root cause, confirmed straight from `devise` gem source (`lib/devise.rb`, `Devise.mappings`
  getter) rather than guessed: **"Starting from Rails 8.0, routes are lazy-loaded by default in
  test and development environments. However, Devise's mappings are built during the routes
  loading phase. To ensure it works correctly, we need to load the routes first before accessing
  @@mappings."** — Devise's own getter guards against this on every access
  (`Rails.application.try(:reload_routes_unless_loaded)`), but Warden's per-scope strategy list is
  apparently resolved before anything has forced that guard to run on a genuinely cold boot, so
  the first-ever authentication attempt finds zero strategies registered for `:user` and fails
  before ever reaching a strategy object (matches the "zero queries" symptom exactly).
  **Fix applied (test suite only, verified 5/5 clean fresh-process full-suite runs):**
  `config.before(:suite) { Devise.mappings }` in `spec/rails_helper.rb` — touching the getter once
  before any example runs closes the gap. This specific placement matters and isn't fully
  understood: the equivalent forced early access **did not** work when tried as a Rails
  initializer (`config.to_prepare { Devise.mappings }` and `config.after_initialize { ... }` were
  both tried and verified, via direct debug output, to still show `Devise.mappings` empty
  immediately after running — even forcibly resolving `Rails.application.routes.routes.size`
  first didn't populate it). Something specific to RSpec's own Rails-application boot path makes
  the guard actually take effect where a plain initializer doesn't; not chased further.
  **Correction to an earlier version of this note, and confirmed this is a known, widely-reported
  upstream issue, not something specific to this app**: Huzaifa found
  [Alvin Crespo's write-up](https://alvincrespo.hashnode.dev/rails-8s-lazy-route-loading-devise) on
  this exact interaction, which led to the real trail —
  [rails/rails#53373](https://github.com/rails/rails/issues/53373) (closed as not planned by the
  Rails team, deferred to Devise) and
  [heartcombo/devise#5716](https://github.com/heartcombo/devise/issues/5716) /
  [#5720](https://github.com/heartcombo/devise/issues/5720), fixed upstream in
  [devise#5728](https://github.com/heartcombo/devise/pull/5728) — which is exactly the
  `Devise.mappings` route-loading guard we found and read directly in our own installed gem
  source. **We already have that fix** (installed `devise (5.0.4)` postdates the Nov 2024 merge)
  — but it's not self-triggering; the guard only fires when something actually calls
  `Devise.mappings`, which is precisely what our `rails_helper.rb` line does. This is the
  community's own recommended workaround, not an ad hoc hack.
  **Originally flagged this as a production risk — that was wrong, corrected the same session**:
  checked `config/environments/production.rb` and confirmed `config.eager_load = true` (the Rails
  default), which fully draws routes — and therefore populates `Devise.mappings` — at boot, before
  any request. Verified empirically, not just asserted from the article: booted a real server with
  `CI=true RAILS_ENV=test` (this app's `test.rb` sets `config.eager_load = ENV["CI"].present?`,
  matching production's always-eager behavior) and the first request succeeded cleanly, no 401.
  **This bug cannot reach real production traffic, and does not affect CI test runs either** —
  it's purely a `development`/local-non-CI-test-only artifact, self-healing after one request, and
  not worth further engineering effort. No longer flagged for checkpoint 10.

## Tooling

- Pre-commit hooks (`.claude/settings.json`, `1cbeed2`): two `PreToolUse`/`Bash` hooks, both
  triggered when the command contains `git commit` — one runs `bundle exec rubocop`, the other
  `bundle exec rspec`. Either failing blocks the commit (exit 2) with the failing output surfaced.
  Split into two rather than one combined hook so each is independently reviewable/disableable via
  `/hooks`. Note for a fresh session: a brand-new `.claude/settings.json` needs one `/hooks` reload
  (or a session restart) before the settings watcher picks it up — verified this empirically via a
  sentinel-write test, not assumed.

**ActiveAdmin curriculum (Obsidian `[[ActiveAdmin]]`, 6 topics):** none started.

**Devise & OmniAuth curriculum (Obsidian `[[Devise & OmniAuth]]`, 6 topics):** none started.

**Actual API surface as built** (source of truth for the SPA repo — keep exact: routes, params,
response/error shapes):

- `POST /users/sign_in` — body `{"user": {"email": "...", "password": "..."}}`. Requires
  `Accept: application/json` header (see progress notes above — `Content-Type` alone is not
  enough for Rails to pick the JSON response format). Success: `200`,
  `{"user": {"id", "email", "first_name", "last_name", "role", "organization_id",
  "default_facility_id"}}`, sets the `_pulse_core_session` cookie (`HttpOnly`, `SameSite=Lax`).
  Failure: `401`, `{"error": "<message>"}`.
- `DELETE /users/sign_out` — no body. Success (was signed in): `204`, empty body. Already signed
  out: `401`, empty body (no JSON error object on this particular path — Devise default, not
  overridden).
- Both routes require the cookie sent/received with credentials (`credentials: 'include'` on
  `fetch`/XHR from the SPA) once CORS (checkpoint 8) is configured.

**Auth mechanism decision:** cookie-session via Devise `database_authenticatable` (decided
2026-08-16, see Deviations). Not JWT. SPA repo must send credentials on every request
(`credentials: 'include'`) and CORS must be configured to allow the SPA's origin with credentials.
