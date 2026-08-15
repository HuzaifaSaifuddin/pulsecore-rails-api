class CreateOrganizations < ActiveRecord::Migration[8.1]
  def change
    create_table :organizations, id: :uuid do |t|
      t.string :name
      t.string :email
      t.string :phone_number

      t.timestamps
    end
    add_index :organizations, :name, unique: true
  end
end
