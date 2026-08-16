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
     Every action applies brief §4 visibility scope — pick Pundit `Policy::Scope#resolve` OR plain
     AR scopes, applied consistently, don't mix.
  5. Devise adapted for API/SPA auth (token vs cookie-session — explain the choice, record it here
     since SPA repo must match). Email as login identifier. Atomic Org+Facility+org_admin signup.
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

## Progress

**Current checkpoint:** 3 (domain models), complete. Order per brief §2: Organization ✅ →
Facility ✅ → User/auth ✅ → Patient ✅ → Appointment ✅ → Admission ✅. Checkpoint 4
(serialization + `/api/v1` controllers) is next.

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

_(none yet — first entries land at checkpoint 4)_

**Auth mechanism decision:** not yet made (checkpoint 5). SPA repo must match whatever is chosen
here (token vs cookie-session).
