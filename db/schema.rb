# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 2026_05_12_040418) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum", null: false
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "favorites", force: :cascade do |t|
    t.integer "relationship_id"
    t.integer "api_movie_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "content_type", default: "movie", null: false
  end

  create_table "friendships", force: :cascade do |t|
    t.integer "sender_id", null: false
    t.integer "recipient_id", null: false
    t.boolean "confirmed", default: false, null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["sender_id", "recipient_id"], name: "index_friendships_on_sender_id_and_recipient_id", unique: true
  end

  create_table "group_invitations", force: :cascade do |t|
    t.integer "group_id", null: false
    t.integer "inviter_id", null: false
    t.integer "invitee_id", null: false
    t.string "status", default: "pending", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["group_id", "invitee_id"], name: "index_group_invitations_on_group_id_and_invitee_id", unique: true
  end

  create_table "group_likes", force: :cascade do |t|
    t.integer "group_id", null: false
    t.integer "user_id", null: false
    t.integer "api_movie_id", null: false
    t.string "content_type", default: "movie", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["group_id", "user_id", "api_movie_id", "content_type"], name: "index_group_likes_uniqueness", unique: true
  end

  create_table "group_memberships", force: :cascade do |t|
    t.integer "group_id", null: false
    t.integer "user_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["group_id", "user_id"], name: "index_group_memberships_on_group_id_and_user_id", unique: true
  end

  create_table "group_watchlist_items", force: :cascade do |t|
    t.integer "group_id", null: false
    t.integer "api_movie_id", null: false
    t.string "content_type", default: "movie", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["group_id", "api_movie_id", "content_type"], name: "index_group_watchlist_items_uniqueness", unique: true
  end

  create_table "groups", force: :cascade do |t|
    t.string "name", null: false
    t.integer "creator_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["creator_id"], name: "index_groups_on_creator_id"
  end

  create_table "likes", force: :cascade do |t|
    t.integer "user_id"
    t.integer "api_movie_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "content_type", default: "movie", null: false
  end

  create_table "passes", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "api_movie_id", null: false
    t.string "content_type", default: "movie", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["user_id", "api_movie_id", "content_type"], name: "index_passes_on_user_id_and_api_movie_id_and_content_type", unique: true
  end

  create_table "relationships", force: :cascade do |t|
    t.integer "sender_id"
    t.integer "recipient_id"
    t.boolean "confirmation", default: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  create_table "users", force: :cascade do |t|
    t.string "name"
    t.string "email"
    t.string "username"
    t.string "image_url"
    t.string "password_digest"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
end
