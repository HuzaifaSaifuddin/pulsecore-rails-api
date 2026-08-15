---
type: reference
status: active
domain: Learning
---
# PulseCore — Rails API + React SPA Port Brief

> Part of [[Learning]] / [[Rails+React SPA Learning]]. This is the shared spec doc for that
> project — copy it verbatim into both `~/Ruby/rails/pulse_core` and `~/React/pulse_core` repo
> roots; each repo's master prompt reads it and focuses on its own relevant sections.

> **Purpose of this document**: PulseCore is an existing Django + server-rendered-HTML Hospital
> Management System (HMS). This brief captures its domain model, business rules, and UI theme so
> the same product can be rebuilt as a **Ruby on Rails API-only backend + React SPA frontend**,
> styled with Tailwind CSS to look and behave the same. Paste this whole file into a new Claude
> session (in a fresh Rails/React repo) as the starting brief — it is self-contained and does not
> assume access to the original Django codebase.

---

## 1. What PulseCore is

A **multi-tenant Hospital Management System**. The customer ("tenant") is a healthcare
organization that owns one or more hospitals/clinics.

**Initial scope is appointment + admission management only.** The following are explicitly
**future modules and must not be implemented now**: EMR, Billing, Pharmacy, Laboratory,
Radiology, Inventory, full Inpatient management, Insurance, Staff Scheduling. Avoid premature
abstraction for these, but leave reasonable extension points (e.g. nullable FKs added later
rather than stubbed out today).

---

## 2. Domain model

Every domain record uses a **UUID primary key** (non-sequential, so IDs can't be
guessed/enumerated across tenants) plus `created_at`/`updated_at` timestamps. In Rails: use
`id: :uuid` on every domain table (`enable_extension "pgcrypto"` or `"uuid-ossp"`), and rely on
Rails' built-in timestamps.

### Organization
Owns Facilities. Created together with the first admin user via signup, atomically, in one
transaction: Organization + a same-named starter Facility + an `org_admin` User, all created
together or not at all.

- `name` — string, unique
- `email` — string
- `phone_number` — string

### Facility
Belongs to exactly one Organization.

- `organization_id` — FK, required
- `name` — string
- Unique constraint on `(organization_id, name)`

### User (custom auth, **email as the login identifier**, not username)
Belongs to an Organization; may belong to **multiple Facilities** via a many-to-many join.

- `email` — unique, used for login
- `first_name`, `last_name` — required (a `full_name` helper falls back to email if both blank,
  for a bootstrap/system account edge case)
- `organization_id` — FK (nullable only for a bootstrap superuser-equivalent account; every real
  staff user has one)
- `role` — plain enum/string column, **not** a permissions/roles gem's table-backed roles:
  `org_admin`, `doctor`, `receptionist`. Deliberately a flat field so authorization stays simple
  and explicit (see §4) rather than building out a generic permissions system prematurely.
- `facilities` — many-to-many to Facility (which facilities this user can act at)
- `default_facility_id` — FK to Facility, nullable, "Current Facility" the user is presently
  working out of (see §5)
- Standard auth fields: password hash, `is_active`, etc.

`accessible_facilities(user)`: Org Admins can access **every facility in their organization**
without explicit membership; every other role only their explicit Facility memberships. This is
the single source of truth reused everywhere "which facilities can this user touch" matters
(nav facility switcher, booking forms, visibility scopes). Cache this per-request/per-user (e.g.
Rails low-level cache keyed `accessible_facilities:<user_id>`, invalidated on role change or
facility-membership change) — it's read on every authenticated request.

### Patient
Belongs to an Organization, **shared across all its Facilities** — deliberately **no Facility
FK**. A patient is the same person regardless of which facility they visit; which visit happened
where belongs on Appointment/Admission, not here.

- `organization_id` — FK, required
- `mrn` — Medical Record Number, string, **auto-generated on first save**, format `P-000001`
  (org-scoped sequential), never set manually, unique per `(organization_id, mrn)`
- `first_name`, `last_name`, `date_of_birth`, `gender` (enum: male/female/other), `phone_number`,
  `email` (optional)

### Appointment
A scheduled visit of a Patient at a Facility. Extension points intentionally **not** modeled yet:
`provider`/`department`/`room`/`encounter` — add as nullable FKs once those owning modules exist.

- `patient_id`, `facility_id` — FK, required
- `doctor_id` — FK to User, **optional**, nullable (not every appointment has a doctor pinned at
  booking time)
- `status` — enum, see workflow below, default `scheduled`
- `scheduled_start` — datetime, required
- `scheduled_end` — datetime, optional (not always known at booking time)
- `notes` — text, front-desk-level context only, **not a clinical record**
- `notes_updated_by_id` (FK to User, nullable), `notes_updated_at`
- Index on `(facility_id, scheduled_start)` — the list view filters by facility + day on every
  page load; this composite index lets Postgres satisfy both conditions in one lookup.

**Status workflow** — a **fixed forward-only path**, not a general workflow/state-machine engine:

```
Scheduled → Arrived → In Progress → Completed
```

Plus a side-branch: `Cancelled` (only reachable from `Scheduled`, and only `Scheduled` is
reachable back from it via "uncancel"). Cancelled is **not** part of the linear
advance/revert chain.

- `advance_status` — moves to next status in the fixed map. No-op (returns false) if already
  terminal, **or if the appointment's scheduled day is still in the future** (Arrived/In
  Progress/Completed represent something that actually happened — can't be true for a visit
  that hasn't occurred yet). No such guard going the other way — a late correction the next day
  is fine.
- `revert_status` — mirror, moves back one step. Blocked if doing so would re-open a second
  "active" appointment for the same patient same day (see conflict rule below).
- `cancel` — only from `Scheduled`.
- `uncancel` — only from `Cancelled`, blocked by the same same-day conflict rule.

**Business rule — one active appointment per patient per day**: `Scheduled`, `Arrived`, `In
Progress` count as "active"; `Completed`/`Cancelled` don't. A patient cannot have two active
appointments the same calendar day (in the org's local timezone) at any facility. Enforced at
validation time (Rails: model validation, not just a DB constraint — this is a same-day range
check, not a simple uniqueness constraint) on create **and** on any status transition that
re-enters an active state.

**Business rule — same-org integrity**: a Patient and Facility on the same Appointment must
belong to the same Organization (defense against a Patient from one tenant ending up booked at
another tenant's Facility).

### Admission
An inpatient stay of a Patient at a Facility — structurally a near-twin of Appointment, with a
longer-lived occupancy semantics. Extension points not modeled yet: `ward`/`bed`/`encounter`.

- Same shape as Appointment: `patient_id`, `facility_id`, `doctor_id` (optional), `status`,
  `admission_start`, `admission_end` (nullable, set on discharge), `notes`,
  `notes_updated_by_id`/`notes_updated_at`
- Index on `(facility_id, admission_start)`

**Status workflow**, same fixed-forward-path shape as Appointment, different terminal states:

```
Scheduled → Arrived → Admitted → Discharged
```

Plus the same `Cancelled` side-branch off `Scheduled` only.

**Business rule — occupancy, not just same-day**: `Arrived`/`Admitted` mean the patient is
*physically occupying a bed right now*. Unlike Appointment's same-day rule, a patient cannot have
a second Arrived/Admitted admission **on any day** while one is already ongoing — this is a
cross-day occupancy check, not a same-day one. `Scheduled` admissions still get a same-day
uniqueness check (mirroring Appointment) since a future plan hasn't started occupying anything
yet.

Same `advance_status`/`revert_status`/`cancel`/`uncancel` shape as Appointment, with the
occupancy check substituted for the active-appointment check where relevant.

---

## 3. Non-goals / explicitly future

Do not build now: EMR, Billing, Pharmacy, Laboratory, Radiology, Inventory, full Inpatient
(ward/bed management), Insurance, Staff Scheduling, a generic workflow/state-machine engine (the
fixed-path status model above is intentional and should **not** be generalized), a full
roles/permissions framework (the flat `role` enum is intentional).

---

## 4. Multi-tenancy & authorization — the security boundary

This is the most important section to port faithfully.

**Every tenant-scoped resource needs a `visible_to(current_user)`-equivalent scope**, applied
consistently to every index/show/update/destroy action, so that a guessed/enumerated ID for
another tenant's record 404s instead of leaking data. In Rails this maps naturally to **Pundit
policy scopes** (`Scope#resolve`) or plain ActiveRecord scopes called explicitly in every
controller action — pick one pattern and apply it everywhere, don't mix.

Two scoping levels exist in this domain:

- **Org-scoped** (Organization, Facility, User, Patient): visible if it belongs to
  `current_user.organization`. Any staff member can *see* any of their org's facilities/users
  (read-only); creating/editing is a separate, role-gated concern (org_admin only).
- **Facility-scoped** (Appointment, Admission): visible only if `facility_id` is in
  `current_user.accessible_facilities` — i.e., the org's full facility list for `org_admin`,
  explicit membership for everyone else.

**Deliberately no "admin/superuser bypass"** on these scopes. If you build an internal
support/ops tool later, it should be a *separate, explicitly audited* surface (e.g. impersonation
with logging) — never a standing blanket-access flag baked into the same scopes the client-facing
app uses. This was a considered decision in the original app, not an oversight — carry it
forward.

**Role checks** go through the plain `role` enum (`org_admin` / `doctor` / `receptionist`) — e.g.
a Pundit policy method `org_admin?` — not a generic permissions/roles table. Keep it that simple
here; this is deliberately not Rails' more general authorization gems' full capability.

---

## 5. "Current Facility" concept

`User.default_facility` is the single facility a user is presently "working out of." Every
facility-scoped screen (Appointments, Admissions) operates against this one facility — there is
**no per-action facility picker** inside those modules.

- If unset, gate access to facility-scoped routes/pages and redirect to a "choose your facility"
  step first, then bounce back to the original destination (`?next=` round-trip, or the SPA
  equivalent — redirect back to the originally-requested route after the pick).
- Auto-set on login **only** in the unambiguous case: if the user has exactly one accessible
  facility, set it automatically; otherwise force an explicit choice.
- Expose `current_facility` + the full switchable list (`accessible_facilities`) globally to the
  frontend (e.g. via a `/me` or `/session` API payload, or a React context provider populated at
  app boot) — the nav bar's facility switcher needs it on every screen.

---

## 6. Signup / auth flow

- Login identifier is **email**, not username.
- Signup creates **Organization + a same-named starter Facility + one `org_admin` User**,
  atomically, in a single transaction. This is the *only* way an Organization gets created.
- After that, additional staff (doctors, receptionists, more admins) are added by an `org_admin`
  from within the app, not via public signup.
- Standard forgot-password flow exists in the original app; port it as-is (email-based reset
  token flow).

---

## 7. UI theme — visual language to replicate in Tailwind + React

The original app is server-rendered with Tailwind CSS (no component library, no dark mode). Keep
the same restrained, functional, "hospital front-desk software" look — not flashy, information-
dense, fast to scan.

**Palette**: white cards on a light gray page background, gray-scale text hierarchy
(`text-gray-900` headings, `text-gray-600`/`text-gray-500` secondary), **blue-600 as the single
accent color** for primary actions and active states, plus semantic colors only for
status/flash messages: green for success, red for error/danger, blue for info. No other accent
colors — resist introducing a broader palette.

**Top nav bar** (persistent, only shown when authenticated): white background, bottom border,
horizontal flex layout — app name/logo on the far left, primary module links next to it
(Appointments, Admissions, Patients, and org-admin-only: Accounts, Facilities), and on the far
right: the **Current Facility switcher** (a `<select>` if the user has multiple accessible
facilities, submitting immediately on change; otherwise a plain read-only badge with the one
facility's name), the logged-in user's email, and a log-out action. Active/hover states are
`text-blue-600`.

**Flash/toast messages**: rounded, bordered, colored by type — `bg-green-50 text-green-800
border-green-200` for success, `bg-red-50 text-red-800 border-red-200` for error, `bg-blue-50
text-blue-800 border-blue-200` for info/other — rendered as a stack under the nav.

**List + detail split-pane pattern** (used for Appointments and Admissions list screens): a
two-column layout — left half is a table (patient / doctor / scheduled time / status columns,
white background, rounded, shadow, gray-100 header row, hover highlight, selected row tinted
`bg-blue-50`); right half is a persistent detail panel (`bg-white rounded shadow` card) that
updates **without a full page navigation** when a row is clicked — in the original this was a
`fetch()` swapping in a server-rendered HTML fragment; in the React port this is naturally just
local state / a route param driving which record's detail is shown in the right pane. Keep the
selected item, status filter, and selected date all reflected in the URL (query params or route
state) so the view is shareable/refreshable and "back" behaves sensibly — the original uses
`history.replaceState` for pane switches (not a new history entry per row click) and a full
navigation only for actual filter changes.

**Status tabs**: a segmented-control look — `bg-gray-100 rounded p-1` wrapper, each tab
`px-3 py-1.5 text-sm rounded`, active tab `bg-white shadow text-gray-900 font-medium`, inactive
`text-gray-600`.

**Date navigator** (Appointments/Admissions list header): previous/next day chevron buttons
(bordered gray icon buttons), a centered date label, a "Today" quick-jump button (highlighted
blue when the selected date *is* today), and a calendar-icon button that opens a native date
picker for jumping to an arbitrary date. All date changes are just re-filtering the same list —
same URL/query-param-driven approach as above.

**Primary action buttons**: solid `bg-blue-600 text-white px-4 py-2 rounded hover:bg-blue-700`
(e.g. "Book Appointment", "Admit Patient").

**Two-step booking flow**: booking an Appointment/Admission is **not** one form. Step one is a
patient search screen (find or create the patient first); step two is the actual
appointment/admission form, with the patient already selected and facility **always fixed to the
Current Facility** (never form-selectable — it's implied by context, not a field). Preserve this
two-step separation in the SPA (e.g. two routes, with the patient id carried via query param or
route state into step two) rather than collapsing it into a single combined form with an inline
patient-create modal — but a "create new patient inline, then continue" affordance from within
step one is fine and matches the original (`?next=` redirect-back pattern from a Patient-create
form).

---

## 8. Suggested Rails + React architecture mapping

These are recommendations, not requirements — adjust to taste, but they map the Django patterns
above onto idiomatic Rails/React equivalents:

| Django/original | Rails + React equivalent |
|---|---|
| `apps.core.models.BaseModel` (UUID PK + timestamps) | `id: :uuid` primary keys + Rails default timestamps; optionally a `Tenantable`/`UuidPrimaryKey` concern for shared behavior |
| Custom `AUTH_USER_MODEL`, email login | `has_secure_password` or Devise, email as the auth identifier, JWT or session-cookie auth for the API (session-cookie + `SameSite` is simplest if frontend and API share a domain; JWT if fully decoupled) |
| `QuerySet.visible_to(user)` per app | Pundit `Policy::Scope#resolve` per resource, applied in every controller's `index`/`show`/`update`/`destroy` |
| `OrgAdminRequiredMixin` | Pundit policy method, e.g. `AdmissionPolicy#create? = user.org_admin?` |
| `CurrentFacilityRequiredMixin` | A `before_action` concern in `ApplicationController` (API) checking `current_user.default_facility_id`, returning a distinguishable response (e.g. `409`/custom error code) the SPA's router intercepts to redirect to a "choose facility" screen |
| `accessible_facilities()` cached per-request | Memoized method on the User model + Rails cache (`Rails.cache.fetch("accessible_facilities:#{id}", expires_in: 5.minutes)`), invalidated via `after_commit` callbacks on role/membership changes |
| Server-rendered half list+detail with `fetch()` swap | React: list route renders a `<DetailPane selectedId={...} />` that fetches `/api/appointments/:id` on selection change; URL state via React Router search params |
| Django messages framework | A small toast/flash context provider in React, or a query param the SPA reads once on mount |
| `django-tailwind` | Tailwind installed directly into the React build (Vite + `@tailwindcss/vite`, or PostCSS) — same utility classes/palette, no component library needed |
| Two-step booking (`AppointmentPatientSearchView` → `AppointmentCreateView` with `?patient=`) | Two React routes: `/appointments/new/search` → `/appointments/new?patient=:id` |
| `advance_status`/`revert_status`/`cancel`/`uncancel` model methods | Keep these as **model-level instance methods on the Rails models** (not controller logic, not a service object) — same rationale as the original: single source of truth for "what's next," reusable from controllers, console, and tests without duplicating the status map |
| No workflow-engine gem | Don't reach for `aasm`/`state_machines` unless you outgrow the simple hash-based NEXT_STATUS/PREVIOUS_STATUS map — the original deliberately avoided a generic engine for a two-status-branch model this simple |

**API shape**: a JSON:API-ish or plain-JSON REST API (`/api/v1/...`) is enough — no GraphQL
needed for this scope. Serializers should respect the same `visible_to` scoping as a hard
boundary (never trust the frontend to filter).

**Suggested initial Rails resources**: `organizations` (create-on-signup only, no general CRUD
endpoint yet), `facilities`, `users` (staff management, org_admin-only writes), `patients`,
`appointments`, `admissions`, plus `sessions` (login/logout) and `password_resets`.

---

## 9. How to use this brief in a new session

1. Start a fresh Rails API + React (Vite) repo.
2. Paste this file into the new session as the founding brief.
3. Work through it in the same deliberate order the domain model is laid out here: Organization
   → Facility → User/auth → Patient → Appointment → Admission, getting each tenancy/authorization
   rule right before moving to the next resource — these rules compound (Appointment's
   visibility depends on User's `accessible_facilities`, which depends on Facility, which depends
   on Organization).
4. Treat §4 (multi-tenancy/authorization) as the one section that must not be simplified away —
   it's the actual security boundary of the app, not incidental plumbing.
5. Match the Tailwind theme in §7 file-for-file where reasonable (colors, spacing, the split-pane
   pattern) so the two apps are visually and behaviorally interchangeable to an end user.
