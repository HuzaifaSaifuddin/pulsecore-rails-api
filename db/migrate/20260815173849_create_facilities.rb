class CreateFacilities < ActiveRecord::Migration[8.1]
  def change
    create_table :facilities, id: :uuid do |t|
      t.string :name
      t.references :organization, null: false, foreign_key: true, type: :uuid

      t.timestamps
    end
    add_index :facilities, [ :organization_id, :name ], unique: true
  end
end
