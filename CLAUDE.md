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
  9. RSpec (deliberate refresher): model specs for status-transition/validation rules (same-day
     conflict, occupancy conflict, fixed-path transitions — highest value); request specs proving
     §4 scopes 404 cross-tenant access; Devise/OmniAuth account-linking spec (existing email,
     first-time OAuth).
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

## Progress

**Current checkpoint:** 1 (environment) — confirmed 2026-08-15: Ruby 3.3.11 (mise), Rails 8.1.3.1,
Bundler 4.0.11, Postgres 16.14 (running, accepting connections). No Rails app generated yet.

**ActiveAdmin curriculum (Obsidian `[[ActiveAdmin]]`, 6 topics):** none started.

**Devise & OmniAuth curriculum (Obsidian `[[Devise & OmniAuth]]`, 6 topics):** none started.

**Actual API surface as built** (source of truth for the SPA repo — keep exact: routes, params,
response/error shapes):

_(none yet — first entries land at checkpoint 4)_

**Auth mechanism decision:** not yet made (checkpoint 5). SPA repo must match whatever is chosen
here (token vs cookie-session).
