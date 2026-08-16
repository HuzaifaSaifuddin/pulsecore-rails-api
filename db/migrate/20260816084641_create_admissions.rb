class CreateAdmissions < ActiveRecord::Migration[8.1]
  def change
    create_table :admissions, id: :uuid do |t|
      t.references :patient, null: false, foreign_key: true, type: :uuid
      t.references :facility, null: false, foreign_key: true, type: :uuid
      t.references :doctor, null: true, foreign_key: { to_table: :users }, type: :uuid
      t.string :status, null: false, default: "scheduled"
      t.datetime :admission_start, null: false
      t.datetime :admission_end
      t.text :notes
      t.references :notes_updated_by, null: true, foreign_key: { to_table: :users }, type: :uuid
      t.datetime :notes_updated_at

      t.timestamps
    end
    add_index :admissions, [ :facility_id, :admission_start ]
  end
end
