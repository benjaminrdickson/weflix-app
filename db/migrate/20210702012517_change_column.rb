class ChangeColumn < ActiveRecord::Migration[6.1]
  def change
    change_column :relationships, :confirmation, :boolean, :default => false
  end
end
