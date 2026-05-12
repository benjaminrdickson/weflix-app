class CreatePushTokens < ActiveRecord::Migration[6.1]
  def change
    create_table :push_tokens do |t|
      t.integer :user_id, null: false
      t.string  :token, null: false
      t.string  :platform, null: false

      t.timestamps
    end
    add_index :push_tokens, :user_id, unique: true
    add_index :push_tokens, :token, unique: true
  end
end
