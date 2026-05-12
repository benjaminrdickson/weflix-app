class CreateFriendships < ActiveRecord::Migration[6.1]
  def change
    create_table :friendships do |t|
      t.integer :sender_id, null: false
      t.integer :recipient_id, null: false
      t.boolean :confirmed, default: false, null: false

      t.timestamps
    end
    add_index :friendships, [:sender_id, :recipient_id], unique: true
  end
end
