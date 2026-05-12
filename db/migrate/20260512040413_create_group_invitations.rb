class CreateGroupInvitations < ActiveRecord::Migration[6.1]
  def change
    create_table :group_invitations do |t|
      t.integer :group_id,   null: false
      t.integer :inviter_id, null: false
      t.integer :invitee_id, null: false
      t.string  :status,     null: false, default: "pending"

      t.timestamps
    end
    add_index :group_invitations, [:group_id, :invitee_id], unique: true
  end
end
