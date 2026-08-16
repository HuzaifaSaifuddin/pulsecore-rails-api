class CreateAppointments < ActiveRecord::Migration[8.1]
  def change
    create_table :appointments, id: :uuid do |t|
      t.references :patient, null: false, foreign_key: true, type: :uuid
      t.references :facility, null: false, foreign_key: true, type: :uuid
      t.references :doctor, null: true, foreign_key: { to_table: :users }, type: :uuid
      t.string :status, null: false, default: "scheduled"
      t.datetime :scheduled_start, null: false
      t.datetime :scheduled_end
      t.text :notes
      t.references :notes_updated_by, null: true, foreign_key: { to_table: :users }, type: :uuid
      t.datetime :notes_updated_at

      t.timestamps
    end
    add_index :appointments, [ :facility_id, :scheduled_start ]
  end
end
