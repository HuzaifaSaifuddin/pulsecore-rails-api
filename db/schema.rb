# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_08_15_191054) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pgcrypto"

  create_table "facilities", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name"
    t.uuid "organization_id", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id", "name"], name: "index_facilities_on_organization_id_and_name", unique: true
    t.index ["organization_id"], name: "index_facilities_on_organization_id"
  end

  create_table "facility_memberships", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.uuid "facility_id", null: false
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.index ["facility_id"], name: "index_facility_memberships_on_facility_id"
    t.index ["user_id", "facility_id"], name: "index_facility_memberships_on_user_id_and_facility_id", unique: true
    t.index ["user_id"], name: "index_facility_memberships_on_user_id"
  end

  create_table "organizations", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email"
    t.string "name"
    t.string "phone_number"
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_organizations_on_name", unique: true
  end

  create_table "users", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.uuid "default_facility_id"
    t.string "email"
    t.string "first_name"
    t.string "last_name"
    t.uuid "organization_id", null: false
    t.string "role"
    t.datetime "updated_at", null: false
    t.index ["default_facility_id"], name: "index_users_on_default_facility_id"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["organization_id"], name: "index_users_on_organization_id"
  end

  add_foreign_key "facilities", "organizations"
  add_foreign_key "facility_memberships", "facilities"
  add_foreign_key "facility_memberships", "users"
  add_foreign_key "users", "facilities", column: "default_facility_id"
  add_foreign_key "users", "organizations"
end
