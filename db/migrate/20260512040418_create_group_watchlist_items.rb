class CreateGroupWatchlistItems < ActiveRecord::Migration[6.1]
  def change
    create_table :group_watchlist_items do |t|
      t.integer :group_id,     null: false
      t.integer :api_movie_id, null: false
      t.string  :content_type, null: false, default: "movie"

      t.timestamps
    end
    add_index :group_watchlist_items, [:group_id, :api_movie_id, :content_type],
              unique: true, name: "index_group_watchlist_items_uniqueness"
  end
end
