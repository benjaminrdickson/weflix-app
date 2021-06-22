class CreateFavorites < ActiveRecord::Migration[6.1]
  def change
    create_table :favorites do |t|
      t.integer :relationship_id
      t.integer :api_movie_id

      t.timestamps
    end
  end
end
