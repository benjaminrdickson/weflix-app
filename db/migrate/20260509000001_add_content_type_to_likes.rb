class AddContentTypeToLikes < ActiveRecord::Migration[6.1]
  def change
    add_column :likes, :content_type, :string, default: "movie", null: false
  end
end
