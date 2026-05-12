class CreateNotificationPreferences < ActiveRecord::Migration[6.1]
  def change
    create_table :notification_preferences do |t|
      t.integer :user_id, null: false
      t.boolean :friend_requests,          default: true, null: false
      t.boolean :friend_request_accepted,  default: true, null: false
      t.boolean :partner_invitations,      default: true, null: false
      t.boolean :partner_watchlist_matches, default: true, null: false
      t.boolean :group_invitations,        default: true, null: false
      t.boolean :group_watchlist_matches,  default: true, null: false
      t.boolean :group_join_requests,      default: true, null: false

      t.timestamps
    end
    add_index :notification_preferences, :user_id, unique: true
  end
end
