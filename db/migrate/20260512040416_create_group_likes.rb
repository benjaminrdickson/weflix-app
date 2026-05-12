class CreateGroupLikes < ActiveRecord::Migration[6.1]
  def change
    create_table :group_likes do |t|
      t.integer :group_id,     null: false
      t.integer :user_id,      null: false
      t.integer :api_movie_id, null: false
      t.string  :content_type, null: false, default: "movie"

      t.timestamps
    end
    add_index :group_likes, [:group_id, :user_id, :api_movie_id, :content_type],
              unique: true, name: "index_group_likes_uniqueness"
  end
end
