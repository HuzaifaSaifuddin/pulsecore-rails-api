class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users, id: :uuid do |t|
      t.string :email
      t.string :first_name
      t.string :last_name
      t.references :organization, null: false, foreign_key: true, type: :uuid
      t.string :role
      t.references :default_facility, null: true, foreign_key: { to_table: :facilities }, type: :uuid

      t.timestamps
    end
    add_index :users, :email, unique: true
  end
end
