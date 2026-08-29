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
  6. ~~ActiveAdmin~~ — **DESCOPED from this repo 2026-08-29** (Huzaifa's call). ActiveAdmin is a
     server-rendered HTML engine and every path to running it inside an `--api` app is a
     workaround (asset pipeline, `ActionController::Base` rendering, AA 4.x still beta on Rails
     8.1). Moving to a separate standard (non-API) Rails app, `pulse_core_rails`, built later
     against the same brief — Stimulus + other out-of-the-box Rails, ActiveAdmin, and optionally
     extending Devise there where none of it needs a workaround.
  7. ~~OmniAuth~~ — **DESCOPED from this repo 2026-08-29** (same call, same reason). Moves to
     `pulse_core_rails` as the optional Devise extension work.
  8. CORS config for SPA dev + deployed origins.
  9. RSpec (deliberate refresher) — **interleaved starting 2026-08-15, not batched at the end**:
     a model spec accompanies every model as it's built from here on (started with retrofitting
     Organization + Facility). **DONE 2026-08-29.** The final gated piece — a formal pass over
     the §4 cross-tenant/cross-facility 404 behavior across every `/api/v1` action — is complete
     (see last Progress entry). The Devise/OmniAuth account-linking spec was dropped with
     checkpoint 7.
  10. Deployment.
- External curricula to cross-reference (Obsidian vault, 6 topics each): `[[ActiveAdmin]]` and
  `[[Devise & OmniAuth]]`. **As of 2026-08-29 neither is executed in this repo** — `[[ActiveAdmin]]`
  in full and the OmniAuth half of `[[Devise & OmniAuth]]` move to the `pulse_core_rails` standard
  app (see checkpoints 6/7 above). The Devise slice this repo did build (checkpoints 4/5) still
  satisfies the non-OmniAuth topics of `[[Devise & OmniAuth]]`.

## Switch signal

Once the Devise auth checkpoint (5) and CORS (8) are done, tell Huzaifa it's time to switch to the React SPA repo (`~/React/pulse_core`) — don't wait for ActiveAdmin/OmniAuth/RSpec first. **Already switched (2026-08-19).** ActiveAdmin + OmniAuth have since been descoped entirely (2026-08-29) — see curriculum 6/7.

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
  and `full_name`'s fallback-to-email branch was removed as dead code. Originally flagged to
  **revisit at checkpoint 6** if ActiveAdmin needed to reuse `User` — moot now that ActiveAdmin
  is descoped from this repo (2026-08-29, see curriculum 6). The decision stands on its own
  merits: `User` is strictly tenant staff, no bootstrap/system row, no revisit trigger left here.
  The separate `AdminUser` model is now `pulse_core_rails`'s concern, not this repo's.
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

**Current checkpoint:** **this repo's API surface is effectively complete. Checkpoints 4, 5, 8
done and the SPA switch happened 2026-08-19. As of 2026-08-29 ActiveAdmin (6) and OmniAuth (7)
are descoped entirely — moved to a future standard-Rails app `pulse_core_rails` (see curriculum
6/7). **Checkpoint 9 closed 2026-08-29** — the formal §4 request-spec pass (see the last
Progress entry). The only thing left open here is checkpoint 10 (deployment). Ongoing work is
SPA-driven API additions like the `/me` endpoint and nested serializers below.**
Checkpoint 4: `/api/v1` controllers done for every resource that gets one at this checkpoint —
Facility/User/Patient (org-scoped, `visible_to`) and Appointment/Admission (facility-scoped,
`accessible_facilities`, plus their workflow actions). `Organization` deliberately has no
controller — brief §8 lists it as "create-on-signup only, no general CRUD endpoint yet"; it only
gets created via the atomic Org+Facility+org_admin transaction (checkpoint 5).
Checkpoint 5: minimal-Devise prep (session middleware, `Users::SessionsController`), atomic
signup (`Users::SignupsController`), and password reset (`Users::PasswordsController`,
`config.paranoid = true`) all done.
Checkpoint 8: CORS done (`rack-cors`, explicit origin allow-list via `SPA_ORIGIN`/
`SPA_PRODUCTION_ORIGIN` env vars — never a wildcard, since cookie-session auth needs
`Access-Control-Allow-Credentials`).
Checkpoint 3 (domain models) complete: Organization ✅ → Facility ✅ → User/auth ✅ → Patient ✅
→ Appointment ✅ → Admission ✅. Along the way, found and fixed a known upstream Rails 8 +
Devise lazy-route-loading bug affecting local dev/test only — confirmed it cannot reach
production (`eager_load = true` there) — see progress notes below, "Flaky
first-authentication-after-boot bug".
Descoped 2026-08-29 (Huzaifa's call — every route to running a server-rendered HTML engine
inside an `--api` app is a workaround, and this repo's job is the SPA's API contract): ActiveAdmin
(6) and OmniAuth (7), both relocated to a future standard (non-API) Rails app `pulse_core_rails`
to be built against the same brief, where Stimulus / out-of-the-box Rails / ActiveAdmin / optional
Devise extension all fit without fighting the framework.
Still open here: only deployment (10). Checkpoint 9's formal §4 request-spec pass was completed
2026-08-29 (see last Progress entry). The Devise/OmniAuth account-linking spec is dropped with
checkpoint 7.

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
- `Api::V1::FacilitiesController#index` (checkpoint 4 proper, first `/api/v1` controller) —
  establishes the pattern every future `/api/v1` controller follows:
  - `Api::V1::BaseController < ApplicationController` with `before_action :authenticate_user!`
    — every `/api/v1` controller inherits from this rather than repeating the auth check.
    Created now (not deferred) since every future controller needs it — not premature, a certain
    near-term requirement.
  - Brief §4 visibility scope implemented as a named model scope, matching the brief's own
    `visible_to(current_user)` language directly: `Facility.scope :visible_to, ->(user) {
    where(organization_id: user.organization_id) }`. Org-scoped resources (Organization, User,
    Patient) get the identical pattern; facility-scoped ones (Appointment, Admission) will need
    `accessible_facilities` instead once built.
  - Hand-rolled serializer convention: `app/serializers/facility_serializer.rb`, a plain Ruby
    class (`FacilitySerializer.new(facility).as_json`) — no gem, per the earlier decision.
    Controller renders `{ facilities: [...] }` (plural key wrapping an array), matching the
    singular `{ user: {...} }` convention `Users::SessionsController` already established.
  - Verified live via `curl` against seeded cross-tenant data before writing the request spec:
    Apollo's org_admin correctly got exactly Apollo's 2 facilities, not Fortis's; unauthenticated
    request got the same `401`/`{"error": ...}` shape `Users::SessionsController` already
    produces (Devise's `authenticate_user!` reuses the same `FailureApp` path, no new code
    needed for that half).
  - `spec/support/authentication_helpers.rb` added (`sign_in_as(user, password:)`, posts to
    `/users/sign_in`) — every future request spec needing an authenticated request reuses this
    instead of repeating the raw POST. Required uncommenting
    `Rails.root.glob('spec/support/**/*.rb')...` in `rails_helper.rb`, off by default.
  - `ApplicationSerializer` base class added (`self.render_collection(records)` — maps a
    collection through `new(record).as_json`) rather than a separate `FacilitiesSerializer`
    plural class — one serializer class per model stays the norm (matches Rails convention,
    `FacilitySerializer < ApplicationSerializer`), the collection-wrapping logic only needs to
    exist once. Justified now (not premature) since the identical `index` shape is confirmed
    needed by every other org-scoped resource about to be built.
  - `create`/`update` added same session, at Huzaifa's request to build out full CRUD before
    committing (also caught a real gap: the `visible_to` scope had shipped with no model spec —
    fixed, see `spec/models/facility_spec.rb`). This introduced three new precedents every future
    write action follows:
    - **Role-gating** (brief §4: create/edit is org_admin-only, a distinct concern from
      visibility scoping): `Api::V1::BaseController#require_org_admin!` (403 `{"error":
      "Forbidden"}` if not org_admin) — a shared private method other controllers opt into via
      `before_action :require_org_admin!, only: [...]`, not applied globally.
    - **New validation-error shape**: `{"errors": ["Name can't be blank", ...]}` — plural key,
      array of `errors.full_messages` strings, status `422` (`:unprocessable_content` — the
      current Rack/Rails status symbol; `:unprocessable_entity` is deprecated, caught via an
      actual deprecation warning in the spec run and fixed immediately rather than left as
      noise). Deliberately distinct from the singular `{"error": "<message>"}` shape used for
      auth/permission/not-found failures (one message, not a list) — that distinction is now the
      standing convention for every future controller.
    - **404 over 403 for cross-tenant writes**: `update` looks up the record via
      `Facility.visible_to(current_user).find(params[:id])`, so a wrong-org ID 404s
      (`ActiveRecord::RecordNotFound`) rather than 403ing — same anti-enumeration reasoning as
      `index`'s scope, brief §4's explicit goal. Needed a new `rescue_from
      ActiveRecord::RecordNotFound` on `ApplicationController` (nothing previously converted
      that exception into a JSON response at all).
    - `organization_id` is never accepted from client params on `create` (built via
      `current_user.organization.facilities.build(...)`) or `update` (`facility_params` only
      permits `:name`) — verified live via `curl` that a smuggled `organization_id` in the
      request body is silently ignored, not just "would be validated away."
    All four behaviors (create success/forbidden/validation-error, update success/cross-org-404/
    forbidden/organization_id-smuggling-ignored) verified live via `curl` against seeded data
    before the request specs were written, same discipline as `index`.
  Specs: 131 examples passing project-wide.
- `Api::V1::UsersController` (`index`/`create`, checkpoint 4 proper). Same pattern as Facility
  (`User.visible_to`, role-gated `create` only, same error shapes) with a few User-specific calls
  worth recording:
  - **`create` here is deliberately *not* signup** — brief §6 makes Organization creation only
    happen via the (not-yet-built) atomic Org+Facility+org_admin transaction; this is "an
    org_admin adds a staff member to their own org." `organization` comes from
    `current_user.organization`, never client params, same principle as Facility.
  - The org_admin supplies the new staff member's initial password directly in the request —
    brief doesn't specify an invite/reset-token flow for staff creation, and building one now
    would mean depending on the password-reset flow (checkpoint 5 remainder, not built yet).
    Revisit if an invite-style flow turns out to be wanted instead.
  - `UserSerializer` (id/email/first_name/last_name/role/organization_id/default_facility_id —
    never `encrypted_password`/`reset_password_token`) became the single source of truth for
    "what a user looks like over the wire" — `Users::SessionsController` refactored to use it
    too instead of its own private `user_json`, removing the duplication that would otherwise
    exist between the two.
  - Caught and fixed a real gotcha before it ever shipped: Rails' `enum` macro raises
    `ArgumentError` for an unrecognized value (e.g. `role: "superadmin"`) rather than a normal
    validation error — without handling it, a bad enum value from a client would `500` instead
    of cleanly `422`ing. Added `rescue_from ArgumentError` to `ApplicationController`
    (app-wide, not just this controller — `Patient#gender` and `Appointment`/`Admission#status`
    will hit the identical gotcha once those controllers exist), rendering the same `{"errors":
    [...]}` shape as a normal validation failure. Verified live via `curl` before writing the
    spec for it.
  - `index` open to any authenticated org member (brief §4 groups User with Facility under
    "any staff can read, org_admin-only to write"), verified live that a `doctor` role can list
    users but not create one.
  Specs: 138 examples passing project-wide.
- `Api::V1::PatientsController` (`index`/`create`/`update`, checkpoint 4 proper). Same
  `visible_to` scope, serializer, and error-shape pattern as Facility/User, with one deliberate
  divergence: **`create`/`update` are not gated behind `require_org_admin!`.** Brief §7's
  two-step booking flow ("find or create the patient first") describes core day-to-day
  front-desk/clinical work — a receptionist or doctor creating/correcting a patient record is
  routine, not an org-structure administrative change like adding staff or facilities, so any
  authenticated org member can do it. `mrn` is never in permitted params (auto-generated by
  `Patient#generate_mrn`) — verified live via `curl` that a client-supplied `mrn: "P-999999"`
  is silently ignored in favor of the real sequential value, same for a smuggled
  `organization_id`. `update` uses the same `visible_to(...).find` cross-org-404 pattern as
  Facility.
  Specs: 146 examples passing project-wide.
- `Api::V1::AppointmentsController` (`index`/`create`/`update`, checkpoint 4 proper) — first
  **facility-scoped** resource, first real use of `accessible_facilities` and brief §5's
  "current facility" concept. Deliberately built as a two-pass split (shape now, the
  `advance_status`/`revert_status`/`cancel`/`uncancel` workflow actions as a follow-up pass),
  mirroring how the `Appointment` model itself was originally built.
  - `Appointment.visible_to` scope: `where(facility_id: user.accessible_facilities)` — same
    method name as the org-scoped resources' `visible_to`, deliberately, even though the
    underlying mechanism differs (facility membership vs. org membership) — keeps controller
    code identical in shape regardless of resource type; each model owns getting its own
    scoping right.
  - **`require_current_facility!`** added to `Api::V1::BaseController` (brief §5/§8): `index`/
    `create` 409 with `{"error": "No current facility selected"}` if
    `current_user.default_facility_id` is blank — the distinguishable response brief §8
    suggests the SPA's router should intercept to redirect to a "choose facility" step.
    `update` does *not* require it — editing an already-accessible record via `visible_to` is
    independent of which facility is "current."
  - `create`'s `facility` is always `current_user.default_facility`, never client-selectable —
    brief §7 states this explicitly for the booking flow ("facility always fixed to the
    Current Facility"). `index` scopes to the current facility *and* a `?date=` param
    (defaulting to `Date.current`) — matches the model's own `(facility_id, scheduled_start)`
    composite index and the brief's description of the list view.
  - `update` only permits `:doctor_id, :scheduled_start, :scheduled_end, :notes` — `status` is
    deliberately not in the permitted list at all (verified live via `curl`: a `status` value in
    the request body is silently dropped, not validated away) since status changes go through
    the dedicated workflow actions, not a plain update.
  - Notes attribution: `notes_updated_by`/`notes_updated_at` are stamped server-side (from
    `current_user`/`Time.current`) whenever `notes_changed?` after assignment, on both `create`
    and `update` — not something the model itself can know (`current_user` is controller-layer
    knowledge), and not naively "was the param present" (which would misfire on a no-op update
    setting notes to their existing value).
  - **Real bug caught and fixed via `curl` before any spec was written**: `Facility` had no
    `has_many :appointments` (or `:admissions`) — `current_user.default_facility.appointments`
    raised `NoMethodError`. Same category of missing-inverse-association gap this repo's history
    already hit twice before (`Organization#has_many :patients`,
    `Patient#has_many :appointments`) — added both inverses to `Facility` (the `:admissions`
    one pre-emptively, since `Api::V1::AdmissionsController` will need the identical shape).
  - **Real RSpec-testing gotcha caught while writing the date-filter spec**: `get path, params:
    {...}, as: :json` does **not** send `params` as a query string — confirmed straight from
    `action_dispatch/testing/integration.rb`: when `method == :get && as == :json && params`,
    Rails silently rewrites the request into a `POST` with an `X-Http-Method-Override: GET`
    header and a JSON body instead, which 400'd against this route. Fixed by dropping `as:
    :json` for that GET and setting `headers: { "Accept" => "application/json" }` directly —
    worth remembering for any future GET-with-query-params spec.
  - Also caught and fixed in my own first draft of the request spec, not the app code: two
    `let!` appointments landing on the same patient/same day, tripping
    `no_conflicting_active_appointment` — same category of mistake as the seed-data work
    earlier this session, now hit a second time in test-writing specifically. Fixed with a
    second `other_patient` fixture rather than relaxing anything.
  Specs: 156 examples passing project-wide.
- `Api::V1::AppointmentsController` pass 2 — the `advance_status`/`revert_status`/`cancel`/
  `uncancel` workflow actions, closing out the two-pass split from earlier. Member routes
  (`POST /api/v1/appointments/:id/advance_status` etc.), each just looking the record up via
  `Appointment.visible_to(current_user).find(...)` (same cross-facility-404 protection as
  `update`) and calling the matching model method.
  - The four model methods return `false` for two genuinely different reasons that look
    identical from the controller: a plain business-rule no-op (terminal state, or
    `advance_status`'s future-day guard) that never touches `.errors` at all, versus a real
    validation failure from the underlying `update` (e.g. a same-day conflict) that does.
    Rather than inventing a third status code to distinguish them, both render the same `422`
    `{"errors": [...]}` shape as every other validation failure in this API —
    `errors.full_messages.presence || ["Unable to #{action}"]` falls back to a generic message
    only when the no-op case left `.errors` empty.
  - One shared private `perform_transition(action)` calls `appointment.public_send(action)` —
    four nearly-identical 6-line action bodies (find, call, branch, render) was repetitive
    enough to warrant this, unlike three merely-similar lines elsewhere in this codebase.
  - All six real scenarios (advance succeeds, future-date no-op, cancel succeeds, double-cancel
    no-op, uncancel succeeds, revert succeeds) verified live via `curl` against seeded data
    before any spec was written, same discipline as every other controller this checkpoint.
  This closes out `Appointment`'s `/api/v1` surface — `Admission` (structurally a near-twin,
  same `visible_to`/`require_current_facility!`/workflow-action pattern, different terminal
  states and the extra occupancy-conflict rule) is next.
  Specs: 165 examples passing project-wide.
- `Api::V1::AdmissionsController` — same pattern as `Appointment` end to end (`visible_to` via
  `accessible_facilities`, `require_current_facility!` on `index`/`create`, notes stamping, the
  four workflow actions sharing `perform_transition`), built in one pass this time rather than
  two, now that the pattern is well-established. Only real difference worth recording: verified
  live via `curl`, then in the request spec, that the occupancy-conflict rule
  (`no_conflicting_occupying_admission`) actually surfaces correctly through `advance_status` —
  a *new* admission can always be created as `scheduled` even while the patient already has one
  arrived/admitted (occupancy only restricts a *second* arrived/admitted, not future planning,
  per the domain rule), but advancing that second one into `arrived` while the first is still
  occupying is correctly blocked. First attempt at that spec used a future-dated second admission
  and got a false pass for the wrong reason — `advance_status`'s own future-day guard fired
  first (a no-op, not a validation failure), never reaching the occupancy check at all. Fixed by
  dating it in the past instead, which reaches the real validation.
  This closes out checkpoint 4's `/api/v1` controllers for every resource that gets one here
  (`Organization` deliberately excluded — brief §8, create-on-signup only, checkpoint 5).
  Specs: 178 examples passing project-wide.
- `Users::SignupsController#create` (checkpoint 5 proper) — the atomic Org+Facility+org_admin
  signup transaction from brief §6, and the **only unauthenticated endpoint in the whole API**.
  `ActiveRecord::Base.transaction` wraps three sequential `create!` calls (Organization, then a
  same-named starter Facility, then the org_admin User with `default_facility` set to that
  facility); any failure raises `ActiveRecord::RecordInvalid`, rolling back everything already
  created in that request — verified live via `curl` and in specs, not just assumed: a duplicate
  admin email (failing on the *third* create) correctly rolls back the organization and facility
  that had already been successfully inserted moments earlier. `sign_in(user)` after a successful
  create, matching the auto-login UX a signup flow should have.
  Lives at `app/controllers/users/signups_controller.rb` (`Users::SignupsController`), grouped
  with `Users::SessionsController` since both are unauthenticated, `User`-identity-related,
  Devise-adjacent concerns — but routed at `/api/v1/signup`, not `/users/signup`, since nothing
  Devise-related forces this one under `/users/...` the way `devise_for` does for sessions, and
  every other endpoint in this API lives under `/api/v1`. Wiring this up caught a real routing
  gotcha: `resource :signup, controller: "users/signups"` inside `namespace :api do namespace
  :v1 do ... end end` resolves *relative to the current namespace* — Rails silently looked for
  `Api::V1::Users::SignupsController`, which doesn't exist. Needed a leading slash,
  `controller: "/users/signups"`, to get an absolute reference to the real class.
  Also adds `OrganizationSerializer` — `Organization` never had one before since it never had a
  controller of its own (still doesn't — see below).
  Specs: 183 examples passing project-wide.
- `Users::PasswordsController` (`create`/`update`, checkpoint 5 remainder — the last piece of
  checkpoint 5) — lives alongside `Sessions`/`Signups`, subclasses `Devise::PasswordsController`,
  same override-only-what's-missing approach as `SessionsController`: `create`/`update` reuse
  Devise's own `send_reset_password_instructions`/`reset_password_by_token`/`successfully_sent?`/
  `sign_in_after_reset_password?` machinery unmodified, only supplying the final JSON render step.
  Routed at Devise's own default `/users/password` (not `/api/v1`) — unlike `Signups`, this
  controller IS wired through `devise_for`'s `controllers:` hash, same as `Sessions`, so nothing
  about it is hand-rolled routing; the `/users/...` vs `/api/v1/...` split is consistently "is
  this Devise-routed" now, not arbitrary.
  **Enabled `config.paranoid = true`** (was commented out, off by default) — a hospital app's
  forgot-password endpoint is exactly the kind of place email-enumeration matters, and it's a
  one-line config change to close (Devise's `successfully_sent?` helper clears any "email not
  found" error and always reports success when paranoid is on). Verified live: identical
  response body for a registered vs unregistered email. **Caveat worth being honest about, not
  glossed over**: this only closes *content-based* enumeration — a registered email still takes
  measurably longer (real DB write + mail delivery) than an unregistered one (near-instant
  no-op), visible in the server timing logs during manual testing. A timing-based enumeration
  vector still exists; Devise's paranoid mode doesn't close that, and neither does this
  controller. Not chased further — flagging honestly rather than overclaiming the guarantee.
  Specs: 189 examples passing project-wide.
- CORS (checkpoint 8) — `rack-cors` gem, `config/initializers/cors.rb`. `origins` is an explicit
  allow-list, never `"*"` — browsers reject a wildcard origin once
  `Access-Control-Allow-Credentials` is true, and cookie-session auth means the SPA sends
  credentials on every request. `SPA_ORIGIN` env var (defaults to `http://localhost:5173`, Vite's
  own stock default) for dev; `SPA_PRODUCTION_ORIGIN` (unset for now) for checkpoint 10. Verified
  live via `curl`: preflight `OPTIONS` from the allowed origin correctly echoes that exact origin
  back with `Access-Control-Allow-Credentials: true`; a disallowed origin gets `200` with no
  `Access-Control-Allow-Origin` header at all (correct — CORS rejection happens client-side in
  the browser based on the header's absence, not a server-side 403).
  **`~/React/pulse_core` has not been scaffolded yet** (only its `CLAUDE.md`/brief exist, no
  `package.json`) — `5173` is Vite's documented default, not a confirmed value from that repo.
  Whoever scaffolds it needs to either keep the default or update `SPA_ORIGIN` here to match.
  Specs: 191 examples passing project-wide.
  **Checkpoints 5 and 8 are both done as of this entry — the "Switch signal" section above says
  it's time to tell Huzaifa to move to the SPA repo now, not wait for ActiveAdmin/OmniAuth/RSpec
  first.**
- `Api::V1::MeController#show` (2026-08-19, requested from the SPA-repo side once that session
  started building against this API and hit brief §5's "expose current_facility + the full
  switchable list via a /me or /session payload" — the SPA was reduced to using
  `GET /api/v1/facilities`'s 200-vs-401 as a crude session probe with no real user payload
  before this existed). `resource :me, only: [:show], controller: "me"` — same gotcha as
  `resource :signup` before it: Rails pluralizes a singular `resource`'s default controller
  lookup (`Api::V1::MesController`), so the explicit `controller:` override is required, not
  optional. Reuses `UserSerializer`/`FacilitySerializer`/`User#accessible_facilities` as-is, no
  new serialization logic — `current_facility` is `nil` when `default_facility_id` is unset
  (guarded, not assumed non-nil). No new authorization concern: `Api::V1::BaseController`'s
  existing `authenticate_user!` is sufficient, this is "who am I," not a new visibility scope.
  Specs: 194 examples passing project-wide.
- Nested `patient`/`doctor` on Appointment/Admission serializers (2026-08-28, requested from the
  SPA-repo side — its list+detail split-pane screen needs patient name/MRN/gender/DOB/phone and
  doctor name per row, and there's no `GET /api/v1/patients/:id` or `/users/:id` show endpoint to
  resolve the FKs without pulling the whole org collection and joining client-side). Decision:
  **replace** the raw `patient_id`/`doctor_id` scalars with nested objects rather than adding them
  alongside — Huzaifa's call, "how production-grade would do it": don't leak bare FKs, expose the
  relationship as the resource. `facility_id` and `notes_updated_by_id` deliberately **kept** as
  scalars — facility is always the current facility the SPA already holds from `/me`, and the
  note-author has no display requirement yet (flag: nest `notes_updated_by` the same way if that
  changes — one line). Serializers compose by plain Ruby — `AppointmentSerializer` calls
  `PatientSerializer`/`UserSerializer` (nil-guarded for the optional doctor), so each resource's
  wire shape still lives in exactly one file (the payoff of hand-rolled POROs over a gem's
  `has_one`-in-serializer DSL). N+1 avoided at the controller layer, not the serializer: only
  `index` iterates a collection, so only `index` gets `.includes(:patient, :doctor)`; the
  single-record actions (`create`/`update`/the four transitions) are 2 extra constant queries, not
  N+1, left alone. `spec/support/query_helpers.rb` added (`count_queries { }` — subscribes to
  `sql.active_record`, filters SCHEMA + txn-control noise) so a request spec can assert query count
  stays flat as rows are added — this test fails if someone drops the `.includes` later.
  Specs: 198 examples passing project-wide (+4: nested-object shape + flat-query-count, per
  resource).
- **Scope decision — ActiveAdmin + OmniAuth descoped from this repo (2026-08-29, Huzaifa's
  call).** Rationale: this repo is `rails new --api`, and every route to running ActiveAdmin (a
  server-rendered HTML engine) inside it is a workaround — re-adding an asset pipeline,
  `ActionController::Base`-style view rendering, and AA 4.x still being beta on Rails 8.1. Rather
  than carry that debt, ActiveAdmin (checkpoint 6) in full and OmniAuth (checkpoint 7) move to a
  new **standard (non-API) Rails app, `pulse_core_rails`**, to be built later against the same
  brief — the intended home for Stimulus, Hotwire/Turbo, other out-of-the-box Rails, ActiveAdmin
  with its own `AdminUser` Devise scope, and optionally extending Devise (OmniAuth provider +
  account-linking) — none of which needs a workaround there. No code was written for 6/7 in this
  repo, so nothing to remove; the API contract and `/api/v1` surface are unaffected. What stays
  open here is only checkpoint 10 (deployment). See curriculum 6/7 and the Progress header for
  the full note.
- **Checkpoint 9 closed — formal §4 request-spec pass (2026-08-29).** Audited every `/api/v1`
  action against brief §4's "a guessed/enumerated ID for another tenant's record 404s, applied
  consistently to every action." Found and filled three gaps; suite went 198 → 213 examples,
  all green, rubocop clean:
  - **Transition-action isolation.** `advance_status`/`update` already proved the cross-facility
    404 per resource, but `revert_status`/`cancel`/`uncancel` on Appointment and Admission had
    no such test (same `visible_to(current_user).find` path, untested). Added
    `spec/support/shared_examples.rb` with `"a facility-scoped transition action"` — one shared
    example parameterized by action name, `it_behaves_like`'d for all four transitions in a
    `"facility-scoped isolation (brief §4)"` describe block in both specs. The old inline
    `advance_status` 404 tests were folded into that block (net: no duplication). Shared example
    fits here because every case is structurally identical (same setup, same 404 assertion,
    only the action string varies) — unlike the transition-*guard* tests ("Unable to cancel"
    etc.), which differ in starting status, expected message, and sometimes status code, and
    would need so many params that writing them out is clearer.
  - **The positive half of the facility scope.** Every facility-scoped request spec used a plain
    `doctor` with one explicit `FacilityMembership`, so only the "membership required" path was
    proven. Added an `"org_admin visibility without explicit facility membership (brief §4/§5)"`
    block to both specs: an `org_admin` with **no** membership successfully advances an
    appointment/admission at a facility other than their default — proving
    `User#accessible_facilities`'s org_admin branch (`organization.facilities`) actually reaches
    the controller.
  - **Write-path 401.** Every controller only had an unauthenticated test on its `index`. Added
    a `"when not signed in" → :unauthorized` test on a write path (`create`, or a transition)
    for all five resource specs — guards against a future `skip_before_action` or an
    out-of-namespace route silently exposing a write, since `authenticate_user!` is only
    inherited from `Api::V1::BaseController`, not restated per controller. (Authentication, not
    strictly §4 visibility — but part of closing the checkpoint "for good".)
  - Admission also gained the `revert_status` request describe block it never had (happy path +
    already-at-initial guard), matching Appointment's coverage.
  Specs: 213 examples passing project-wide.

## Tooling

- Pre-commit hooks (`.claude/settings.json`, `1cbeed2`): two `PreToolUse`/`Bash` hooks, both
  triggered when the command contains `git commit` — one runs `bundle exec rubocop`, the other
  `bundle exec rspec`. Either failing blocks the commit (exit 2) with the failing output surfaced.
  Split into two rather than one combined hook so each is independently reviewable/disableable via
  `/hooks`. Note for a fresh session: a brand-new `.claude/settings.json` needs one `/hooks` reload
  (or a session restart) before the settings watcher picks it up — verified this empirically via a
  sentinel-write test, not assumed.
- `db/seeds.rb`: two known organizations (Apollo Hospitals, Fortis Healthcare) with fixed
  logins (`admin@`/`doctor1@`/`doctor2@`/`reception@<org-slug>.com`, password `pulsecore123`
  for all), so there's always a predictable set of credentials and cross-tenant data to test
  checkpoint 4's visibility scopes against. `faker` gem added (`:development` group only, not
  `:test` — spec factories deliberately stay plain-sequence). Organization/Facility are
  `find_or_create_by!`; User records are `find_or_initialize_by` + explicit re-assignment
  (including password) on every run, so seed credentials never drift even if changed by hand
  during manual testing. Patient/Appointment/Admission are cleared and freshly regenerated on
  every run **in development only** (`Rails.env.development?`-gated — never destructive outside
  dev), so seeded visit dates stay relative to "today" instead of whenever the DB was first
  seeded; outside development that generation is skipped entirely once an org already has
  patients, so it's still safe to rerun there. Appointments/admissions are constructed (not
  randomly assigned) to satisfy the models' own conflict validations rather than working around
  them: distinct calendar days per patient, and at most one admission per patient ever left
  arrived/admitted. One real bug caught and fixed here: `organization.patients.delete_all`
  (called on the `has_many` association, no `dependent:` option declared) defaults to
  *nullifying* `organization_id` rather than deleting rows, which hit the `NOT NULL` constraint —
  `Patient.where(organization: organization).delete_all` (a plain relation, not an association
  proxy) is the fix; always a real `DELETE` regardless of `dependent:` config.

**ActiveAdmin curriculum (Obsidian `[[ActiveAdmin]]`, 6 topics):** not executed in this repo —
relocated 2026-08-29 to the future `pulse_core_rails` standard-Rails app (an `--api` app is the
wrong host for it). Topic 1 ("what it is") was covered verbally in the 2026-08-29 session before
the descope decision; nothing built.

**Devise & OmniAuth curriculum (Obsidian `[[Devise & OmniAuth]]`, 6 topics):** the Devise topics
(sessions, database_authenticatable, recoverable, API/SPA cookie-session config, paranoid mode)
are satisfied by checkpoints 4/5 in this repo. The OmniAuth topic (provider + account-linking) is
relocated with ActiveAdmin to `pulse_core_rails`, as optional Devise-extension work.

**Actual API surface as built** (source of truth for the SPA repo — keep exact: routes, params,
response/error shapes):

- `POST /api/v1/signup` — the **only unauthenticated** endpoint in this API, and the only way an
  Organization ever gets created. Body: `{"organization": {"name", "email", "phone_number"},
  "user": {"email", "password", "first_name", "last_name"}}` — no `role` accepted (always
  `org_admin`), no facility fields (the starter facility is always same-named as the
  organization). Success: `201`, `{"user": {...}, "organization": {...}, "facility": {...}}`
  (each shaped like that resource's own `GET` response elsewhere in this doc) — also signs the
  new admin in (`_pulse_core_session` cookie set, same as `POST /users/sign_in`). Validation
  failure on *any* of the three creates: `422`, `{"errors": [...]}`, and nothing is persisted —
  atomic, verified live.
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
- `POST /users/password` — body `{"user": {"email": "..."}}`. No authentication needed. Always
  `200`, `{"message": "If that email is registered, password reset instructions have been
  sent."}` — **identical regardless of whether the email is actually registered**
  (`config.paranoid = true`, intentional anti-enumeration). Sends a reset-token email when the
  email is registered; no observable difference in the response either way (though a real vs.
  fake email does take measurably different server time — a timing side-channel this doesn't
  close, see progress notes).
- `PATCH /users/password` — body `{"user": {"reset_password_token", "password",
  "password_confirmation"}}`. No authentication needed (the token itself is the credential).
  Success: `200`, `{"user": {...}}` (same shape as `GET /api/v1/users`'s items), and signs the
  user in (`_pulse_core_session` cookie set). Invalid/expired/already-used token, or a
  password/confirmation mismatch: `422`, `{"errors": [...]}`.
- CORS: allowed origins are `SPA_ORIGIN` (env var, defaults to `http://localhost:5173`) and
  `SPA_PRODUCTION_ORIGIN` (env var, unset until checkpoint 10). Credentials allowed
  (`Access-Control-Allow-Credentials: true`), all standard methods, all headers. **The SPA repo
  must send `credentials: 'include'` on every `fetch`/XHR call** — without it, the browser won't
  send/accept the session cookie cross-origin regardless of how permissive this config is.
- `GET /api/v1/me` — brief §5's "who is currently authenticated, and what's their facility
  situation" payload. The SPA calls this on boot (and after login) to decide whether to show the
  login form or go straight to the dashboard, since the session cookie is `HttpOnly` and
  invisible to JS. Success: `200`, `{"user": {...}}` (same shape as `GET /api/v1/users` items),
  plus `"current_facility"` (the full facility object for `default_facility_id`, or `null` if
  unset) and `"accessible_facilities"` (every facility from `User#accessible_facilities`, same
  shape as `GET /api/v1/facilities` items — the full switchable list, not just the current one).
  Unauthenticated: `401`, `{"error": "<message>"}`, same shape as every other unauthenticated
  response.
- `GET /api/v1/facilities` — requires an authenticated session (same cookie as above). Success:
  `200`, `{"facilities": [{"id", "name", "organization_id"}, ...]}` — every facility belonging to
  `current_user.organization`, org-scoped per brief §4 (any role can read, not just org_admin).
  Unauthenticated: `401`, `{"error": "<message>"}` (identical shape to the sign-in failure path).
- `POST /api/v1/facilities` — body `{"facility": {"name": "..."}}`. org_admin only.
  `organization_id` is always `current_user.organization`, never client-supplied — any
  `organization_id` in the body is silently ignored, not validated against. Success: `201`,
  `{"facility": {"id", "name", "organization_id"}}`. Validation failure: `422`, `{"errors":
  ["<message>", ...]}` — plural key, array of full messages, distinct from the singular
  `{"error": "<message>"}` shape used for auth/permission/not-found failures. Non-org_admin: `403`,
  `{"error": "Forbidden"}`.
- `PATCH /api/v1/facilities/:id` — same body/response/error shapes as `POST` above. org_admin
  only, and only for a facility in `current_user.organization` — a wrong-org `:id` gets `404`,
  `{"error": "Not found"}` (not `403` — anti-enumeration, same reasoning as `index`'s scope).
- `GET /api/v1/users` — requires an authenticated session, any role. Success: `200`,
  `{"users": [{"id", "email", "first_name", "last_name", "role", "organization_id",
  "default_facility_id"}, ...]}` — every user in `current_user.organization`, never
  `encrypted_password`/`reset_password_token`. Unauthenticated: `401`, `{"error": "<message>"}`.
- `POST /api/v1/users` — body `{"user": {"email", "password", "first_name", "last_name",
  "role"}}`. org_admin only — this is "add a staff member to my own org," not signup;
  `organization_id` is always `current_user.organization`, not client-supplied. Success: `201`,
  `{"user": {...}}` (same shape as `GET`). Validation failure (incl. an unrecognized `role`
  value): `422`, `{"errors": [...]}`. Non-org_admin: `403`, `{"error": "Forbidden"}`.
- `GET /api/v1/patients` — requires an authenticated session, any role. Success: `200`,
  `{"patients": [{"id", "mrn", "first_name", "last_name", "date_of_birth", "gender",
  "phone_number", "email", "organization_id"}, ...]}` — every patient in
  `current_user.organization`. Unauthenticated: `401`, `{"error": "<message>"}`.
- `POST /api/v1/patients` — body `{"patient": {"first_name", "last_name", "date_of_birth",
  "gender", "phone_number", "email"}}`. **Any authenticated org member, not just org_admin**
  (deliberate divergence from Facility/User — see progress notes). `organization_id` always
  `current_user.organization`; `mrn` is always server-generated, never accepted from the client
  even if present in the body. Success: `201`, `{"patient": {...}}` (same shape as `GET`).
  Validation failure: `422`, `{"errors": [...]}`.
- `PATCH /api/v1/patients/:id` — same body/response/error shapes as `POST` above, same
  any-authenticated-org-member access. Wrong-org `:id`: `404`, `{"error": "Not found"}`.
- `GET /api/v1/appointments` — optional `?date=YYYY-MM-DD` query param (defaults to today).
  Requires `current_user.default_facility_id` set — if absent: `409`, `{"error": "No current
  facility selected"}`. Success: `200`, `{"appointments": [{"id", "patient", "facility_id",
  "doctor", "status", "scheduled_start", "scheduled_end", "notes", "notes_updated_by_id",
  "notes_updated_at"}, ...]}` — every appointment at `current_user.default_facility` on that
  date. `"patient"` is the full nested object (same shape as a `GET /api/v1/patients` item);
  `"doctor"` is the full nested user object (same shape as a `GET /api/v1/users` item) or `null`
  when unset. The raw `patient_id`/`doctor_id` scalars are **not** in the payload — nested objects
  replace them (`facility_id` and `notes_updated_by_id` stay as scalars: facility is always the
  current facility the SPA already has, note-author has no display need yet). Controller eager-loads
  `includes(:patient, :doctor)` so the list is not N+1. Unauthenticated: `401`, `{"error":
  "<message>"}`.
- `POST /api/v1/appointments` — body `{"appointment": {"patient_id", "doctor_id", "scheduled_start",
  "scheduled_end", "notes"}}`. Any authenticated org member (same reasoning as Patient — routine
  clinical work, not admin-gated). Same `409` current-facility requirement as `GET`.
  `facility_id` is always `current_user.default_facility`, never client-supplied. Success: `201`,
  `{"appointment": {...}}` (same shape as `GET`). Validation failure (incl. cross-org patient,
  same-day conflict): `422`, `{"errors": [...]}`.
- `PATCH /api/v1/appointments/:id` — body `{"appointment": {"doctor_id", "scheduled_start",
  "scheduled_end", "notes"}}` — **`status` is not accepted here**, silently dropped even if
  present in the body; status changes go through the four actions below instead. No
  current-facility requirement (unlike `GET`/`POST`) — only requires the record be in
  `current_user.accessible_facilities`. A facility the user can't access: `404`, `{"error": "Not
  found"}`.
- `POST /api/v1/appointments/:id/advance_status`, `.../revert_status`, `.../cancel`,
  `.../uncancel` — no body needed. Same `visible_to`-scoped lookup as `PATCH` (wrong-facility
  `:id`: `404`). Success: `200`, `{"appointment": {...}}` (same shape as `GET`). If the
  transition isn't currently allowed (wrong status, or `advance_status`'s future-day guard):
  `422`, `{"errors": ["Unable to advance status"]}` (message varies per action) — same shape as
  a normal validation failure, even though no field was actually invalid.
- `GET`/`POST`/`PATCH /api/v1/admissions[/:id]` and `POST .../advance_status`,
  `.../revert_status`, `.../cancel`, `.../uncancel` — identical shapes to the `appointments`
  endpoints above with `appointment`/`appointments` swapped for `admission`/`admissions` and
  `scheduled_start`/`scheduled_end` swapped for `admission_start`/`admission_end`. One extra
  failure mode `advance_status` can hit here that `Appointment` doesn't: `422`,
  `{"errors": ["... conflicts with another arrived or admitted admission -- discharge or cancel
  that one first."]}` if advancing into `arrived`/`admitted` while the patient already has
  another admission occupying a bed.

**Auth mechanism decision:** cookie-session via Devise `database_authenticatable` (decided
2026-08-16, see Deviations). Not JWT. SPA repo must send credentials on every request
(`credentials: 'include'`) and CORS must be configured to allow the SPA's origin with credentials.

`README.md` written (2026-08-17): setup, `bin/rails db:seed` usage, known seed logins, running
tests, CORS env vars.
