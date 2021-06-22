class CreateRelationships < ActiveRecord::Migration[6.1]
  def change
    create_table :relationships do |t|
      t.integer :sender_id
      t.integer :recipient_id
      t.boolean :confirmation

      t.timestamps
    end
  end
end
