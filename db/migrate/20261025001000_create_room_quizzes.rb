class CreateRoomQuizzes < ActiveRecord::Migration[8.1]
  def change
    add_column :rooms, :quiz_genre_weights, :json, default: {}, null: false

    create_table :room_quizzes do |t|
      t.references :room, null: false, foreign_key: true
      t.references :started_by, null: false, foreign_key: { to_table: :users }
      t.string :status, null: false, default: "active"
      t.json :participant_ids, null: false, default: []
      t.json :candidates, null: false, default: []
      t.json :initial_genre_weights, null: false, default: {}
      t.json :skipped_movie_ids, null: false, default: []
      t.integer :current_movie_id
      t.integer :selected_movie_id
      t.timestamps
    end
    add_index :room_quizzes, :room_id, unique: true, where: "status = 'active'", name: "index_one_active_quiz_per_room"

    create_table :room_quiz_votes do |t|
      t.references :room_quiz, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.integer :tmdb_id, null: false
      t.string :choice, null: false
      t.timestamps
    end
    add_index :room_quiz_votes, [ :room_quiz_id, :user_id, :tmdb_id ], unique: true
    add_check_constraint :room_quiz_votes, "choice IN ('yes', 'no', 'unsure')", name: "room_quiz_votes_valid_choice"
  end
end
