class CreateMovieDomain < ActiveRecord::Migration[8.1]
  def change
    create_table :movies do |t|
      t.integer :tmdb_id, null: false
      t.string :title, null: false
      t.date :release_date
      t.timestamps
    end
    add_index :movies, :tmdb_id, unique: true
    add_check_constraint :movies, "tmdb_id > 0", name: "movies_positive_tmdb_id"

    create_table :ratings do |t|
      t.references :user, null: false, foreign_key: true
      t.references :movie, null: false, foreign_key: true
      t.integer :score, null: false
      t.timestamps
    end
    add_index :ratings, [ :user_id, :movie_id ], unique: true
    add_check_constraint :ratings, "score BETWEEN 1 AND 10", name: "ratings_score_range"

    create_table :rooms do |t|
      t.string :name, null: false
      t.references :owner, null: false, foreign_key: { to_table: :users }
      t.timestamps
    end

    create_table :memberships do |t|
      t.references :user, null: false, foreign_key: true
      t.references :room, null: false, foreign_key: true
      t.timestamps
    end
    add_index :memberships, [ :user_id, :room_id ], unique: true
  end
end
