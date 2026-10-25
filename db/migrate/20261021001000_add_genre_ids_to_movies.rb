class AddGenreIdsToMovies < ActiveRecord::Migration[8.1]
  def change
    add_column :movies, :genre_ids, :json
  end
end
