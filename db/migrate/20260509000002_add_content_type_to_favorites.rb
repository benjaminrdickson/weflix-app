class AddContentTypeToFavorites < ActiveRecord::Migration[6.1]
  def change
    add_column :favorites, :content_type, :string, default: "movie", null: false
  end
end
