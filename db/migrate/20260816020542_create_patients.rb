class CreatePatients < ActiveRecord::Migration[8.1]
  def change
    create_table :patients, id: :uuid do |t|
      t.references :organization, null: false, foreign_key: true, type: :uuid
      t.string :mrn
      t.string :first_name
      t.string :last_name
      t.date :date_of_birth
      t.string :gender
      t.string :phone_number
      t.string :email

      t.timestamps
    end
    add_index :patients, [ :mrn, :organization_id ], unique: true
  end
end
