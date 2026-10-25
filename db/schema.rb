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

ActiveRecord::Schema[8.1].define(version: 2026_10_25_001000) do
  create_table "memberships", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "room_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["room_id"], name: "index_memberships_on_room_id"
    t.index ["user_id", "room_id"], name: "index_memberships_on_user_id_and_room_id", unique: true
    t.index ["user_id"], name: "index_memberships_on_user_id"
  end

  create_table "movies", force: :cascade do |t|
    t.integer "tmdb_id", null: false
    t.string "title", null: false
    t.date "release_date"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.json "genre_ids"
    t.index ["tmdb_id"], name: "index_movies_on_tmdb_id", unique: true
    t.check_constraint "tmdb_id > 0", name: "movies_positive_tmdb_id"
  end

  create_table "ratings", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "movie_id", null: false
    t.integer "score", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["movie_id"], name: "index_ratings_on_movie_id"
    t.index ["user_id", "movie_id"], name: "index_ratings_on_user_id_and_movie_id", unique: true
    t.index ["user_id"], name: "index_ratings_on_user_id"
    t.check_constraint "score BETWEEN 1 AND 10", name: "ratings_score_range"
  end

  create_table "room_quiz_votes", force: :cascade do |t|
    t.integer "room_quiz_id", null: false
    t.integer "user_id", null: false
    t.integer "tmdb_id", null: false
    t.string "choice", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["room_quiz_id", "user_id", "tmdb_id"], name: "index_room_quiz_votes_on_room_quiz_id_and_user_id_and_tmdb_id", unique: true
    t.index ["room_quiz_id"], name: "index_room_quiz_votes_on_room_quiz_id"
    t.index ["user_id"], name: "index_room_quiz_votes_on_user_id"
    t.check_constraint "choice IN ('yes', 'no', 'unsure')", name: "room_quiz_votes_valid_choice"
  end

  create_table "room_quizzes", force: :cascade do |t|
    t.integer "room_id", null: false
    t.integer "started_by_id", null: false
    t.string "status", default: "active", null: false
    t.json "participant_ids", default: [], null: false
    t.json "candidates", default: [], null: false
    t.json "initial_genre_weights", default: {}, null: false
    t.json "skipped_movie_ids", default: [], null: false
    t.integer "current_movie_id"
    t.integer "selected_movie_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["room_id"], name: "index_one_active_quiz_per_room", unique: true, where: "status = 'active'"
    t.index ["room_id"], name: "index_room_quizzes_on_room_id"
    t.index ["started_by_id"], name: "index_room_quizzes_on_started_by_id"
  end

  create_table "rooms", force: :cascade do |t|
    t.string "name", null: false
    t.integer "owner_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.json "selection_filters", default: {}, null: false
    t.json "selection_results", default: [], null: false
    t.datetime "selection_generated_at"
    t.json "quiz_genre_weights", default: {}, null: false
    t.index ["owner_id"], name: "index_rooms_on_owner_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "nickname", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
    t.index ["nickname"], name: "index_users_on_nickname", unique: true
  end

  add_foreign_key "memberships", "rooms"
  add_foreign_key "memberships", "users"
  add_foreign_key "ratings", "movies"
  add_foreign_key "ratings", "users"
  add_foreign_key "room_quiz_votes", "room_quizzes"
  add_foreign_key "room_quiz_votes", "users"
  add_foreign_key "room_quizzes", "rooms"
  add_foreign_key "room_quizzes", "users", column: "started_by_id"
  add_foreign_key "rooms", "users", column: "owner_id"
  add_foreign_key "sessions", "users"
end
