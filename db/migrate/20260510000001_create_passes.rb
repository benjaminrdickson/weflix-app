class CreatePasses < ActiveRecord::Migration[6.1]
  def change
    create_table :passes do |t|
      t.integer :user_id, null: false
      t.integer :api_movie_id, null: false
      t.string :content_type, default: "movie", null: false
      t.timestamps
    end
    add_index :passes, [:user_id, :api_movie_id, :content_type], unique: true
  end
end
