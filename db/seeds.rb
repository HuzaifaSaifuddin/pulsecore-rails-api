# Two organizations with known, fixed logins (not randomized) so there's
# always a predictable set of credentials to log in and click around with.
# Appointments/admissions are seeded carefully rather than with fully random
# fields, since our validations run on every create!:
#
#   1. Appointments/admissions are scattered across distinct calendar days per
#      patient, and at most one admission per patient is ever left
#      arrived/admitted -- both by construction, not by relaxing a validation --
#      so they satisfy Appointment#no_conflicting_active_appointment and
#      Admission#no_conflicting_scheduled_admission_same_day /
#      #no_conflicting_occupying_admission instead of raising on create!.
#   2. org_admin gets no explicit FacilityMembership rows -- User#
#      accessible_facilities already grants every facility in the org to
#      org_admin with no membership needed, so seeding one would just be
#      redundant, unused data.
#
# PATIENTS_PER_ORG is deliberately small -- this is for routes being easy to
# GET during development, not a load/query-performance benchmark, so it's
# sized for `rails db:seed` to be fast and the data to be easy to browse.
#
# Organization/Facility records are find_or_create_by!. User records are
# find_or_initialize_by + explicit re-assignment on every run -- including
# password -- so the known seed credentials always work even if one got
# changed by hand during manual testing. None of that is ever destructive.
#
# Patient/Appointment/Admission are the exception, and only in development
# (guarded strictly on Rails.env.development? -- this must never run
# against real data): every run clears an organization's existing
# patients (and, via that, their appointments/admissions) and regenerates
# a fresh batch, so seeded appointment/admission dates are always relative
# to *today*, not whenever the database last got seeded. Outside
# development this stays non-destructive: generation is skipped entirely
# once an organization already has patients, so it's still safe to run
# `rails db:seed` more than once there.

SEED_PASSWORD = "pulsecore123"
PATIENTS_PER_ORG = 10

DOCTOR_NAMES = [ %w[Rohan Verma], %w[Meera Krishnan] ].freeze

def seed_user(email, organization:, role:, first_name:, last_name:, default_facility:)
  user = User.find_or_initialize_by(email: email)
  user.password = SEED_PASSWORD
  user.organization = organization
  user.role = role
  user.first_name = first_name
  user.last_name = last_name
  user.default_facility = default_facility
  user.save!
  user
end

def seed_organization(name, facility_names)
  puts "Creating #{name}"
  slug = name.downcase.delete(" ")

  organization = Organization.find_or_create_by!(name: name) do |org|
    org.email = "info@#{slug}.com"
    org.phone_number = "9800000000"
  end

  print "  Facilities "
  facilities = facility_names.map do |facility_name|
    facility = Facility.find_or_create_by!(organization: organization, name: facility_name)
    print "."
    facility
  end
  puts

  print "  Users "
  admin = seed_user("admin@#{slug}.com", organization: organization, role: "org_admin",
    first_name: "Priya", last_name: "Sharma", default_facility: facilities.first)
  print "."

  # One doctor per facility, paired index-for-index so a seeded
  # Appointment/Admission never assigns a doctor to a facility they don't
  # actually work at.
  doctors = facilities.each_with_index.map do |facility, i|
    first_name, last_name = DOCTOR_NAMES[i % DOCTOR_NAMES.size]
    doctor = seed_user("doctor#{i + 1}@#{slug}.com", organization: organization, role: "doctor",
      first_name: first_name, last_name: last_name, default_facility: facility)
    FacilityMembership.find_or_create_by!(user: doctor, facility: facility)
    print "."
    doctor
  end

  # Deliberately left with no default_facility: the receptionist is a member of every
  # facility, so login won't auto-pick one (that only happens with exactly one accessible) --
  # a ready-made subject for exercising the "choose a facility" step and PATCH /api/v1/me.
  receptionist = seed_user("reception@#{slug}.com", organization: organization, role: "receptionist",
    first_name: "Anjali", last_name: "Nair", default_facility: nil)
  facilities.each { |facility| FacilityMembership.find_or_create_by!(user: receptionist, facility: facility) }
  print "."
  puts

  if Rails.env.development?
    old_patient_count = organization.patients.count
    Admission.where(patient: organization.patients).delete_all
    Appointment.where(patient: organization.patients).delete_all
    # Not organization.patients.delete_all -- called on a has_many association
    # with no explicit `dependent:` option, that nullifies organization_id
    # instead of deleting rows, which then hits the NOT NULL constraint.
    # Patient.where(...).delete_all is a plain relation, always a real DELETE.
    Patient.where(organization: organization).delete_all
    puts "  Clearing previous patients (#{old_patient_count})"
  end

  if Rails.env.development? || organization.patients.none?
    facility_doctor_pairs = facilities.zip(doctors)

    print "  Patients "
    patients = Array.new(PATIENTS_PER_ORG) do
      patient = seed_patient(organization)
      print "."
      patient
    end
    puts

    print "  Appointments "
    patients.each do |patient|
      facility, doctor = facility_doctor_pairs.sample
      seed_appointments(patient, facility, doctor) { print "." }
    end
    puts

    print "  Admissions "
    patients.each do |patient|
      facility, doctor = facility_doctor_pairs.sample
      seed_admissions(patient, facility, doctor) { print "." }
    end
    puts
  end

  puts
  organization
end

def seed_patient(organization)
  has_email = rand < 0.7

  Patient.create!(
    organization: organization,
    first_name: Faker::Name.first_name,
    last_name: Faker::Name.last_name,
    date_of_birth: Faker::Date.birthday(min_age: 1, max_age: 95),
    gender: Patient.genders.keys.sample,
    phone_number: "9#{Faker::Number.number(digits: 9)}",
    email: has_email ? Faker::Internet.email : nil
  )
end

# A variable handful per patient, not exactly one -- a real facility's queue
# has patients with different amounts of history. Distinct calendar days per
# patient (sample without replacement) so no two ever land on the same day --
# that's what makes Appointment's one-active-appointment-per-patient-per-day
# validation a non-issue here rather than something to work around.
def seed_appointments(patient, facility, doctor)
  day_offsets = (-14..14).to_a.sample(rand(2..5))

  day_offsets.each do |offset|
    scheduled_start = seed_time(offset)
    status = offset.positive? ? %w[scheduled cancelled].sample : Appointment.statuses.keys.sample

    Appointment.create!(
      patient: patient,
      facility: facility,
      doctor: rand < 0.8 ? doctor : nil,
      status: status,
      scheduled_start: scheduled_start,
      scheduled_end: scheduled_start + 30.minutes
    )
    yield if block_given?
  end
end

# Same distinct-day approach as appointments, plus one extra constraint
# Admission has that Appointment doesn't: arrived/admitted means physically
# occupying a bed *right now*, so at most one seeded admission per patient
# is ever left in that state -- everything else is scheduled/discharged/
# cancelled, which Admission's occupancy check doesn't restrict at all.
def seed_admissions(patient, facility, doctor)
  day_offsets = (-14..14).to_a.sample(rand(1..3))
  occupying_used = false

  day_offsets.each do |offset|
    candidates = if offset.positive?
      %w[scheduled cancelled]
    else
      %w[scheduled discharged cancelled] + (occupying_used ? [] : Admission::OCCUPYING_STATUSES)
    end
    status = candidates.sample
    occupying_used ||= Admission::OCCUPYING_STATUSES.include?(status)
    admission_start = seed_time(offset)

    Admission.create!(
      patient: patient,
      facility: facility,
      doctor: rand < 0.8 ? doctor : nil,
      status: status,
      admission_start: admission_start
    )
    yield if block_given?
  end
end

def seed_time(day_offset)
  Time.zone.now.change(min: 0, sec: 0) + day_offset.days + rand(8..17).hours
end

organizations = [
  seed_organization("Apollo Hospitals", [ "Main Branch", "Satellite Clinic" ]),
  seed_organization("Fortis Healthcare", [ "Main Branch" ])
]

puts "Seed data created."
puts "Every user's password: #{SEED_PASSWORD}"
organizations.each do |organization|
  puts "\n#{organization.name}:"
  organization.users.order(:role).each do |user|
    puts "  #{user.email}  (#{user.role})"
  end
  appointment_count = Appointment.joins(:facility).where(facilities: { organization_id: organization.id }).count
  admission_count = Admission.joins(:facility).where(facilities: { organization_id: organization.id }).count
  puts "  #{organization.patients.count} patients, #{appointment_count} appointments, #{admission_count} admissions"
end
