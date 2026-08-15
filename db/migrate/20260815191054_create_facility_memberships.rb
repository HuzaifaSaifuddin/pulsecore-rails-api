class CreateFacilityMemberships < ActiveRecord::Migration[8.1]
  def change
    create_table :facility_memberships, id: :uuid do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.references :facility, null: false, foreign_key: true, type: :uuid

      t.timestamps
    end
    add_index :facility_memberships, [:user_id, :facility_id], unique: true
  end
end
