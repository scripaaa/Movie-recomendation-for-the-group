class RatingsController < ApplicationController
  def index
    @ratings = Current.user.ratings.includes(:movie).order(updated_at: :desc, id: :desc)
  end

  def update
    Movie.transaction do
      movie = Movie.find_by(tmdb_id: params[:tmdb_id])
      unless movie
        details = Tmdb::MovieSearch.new.details(params[:tmdb_id])
        movie = Movie.create_or_find_by!(tmdb_id: params[:tmdb_id]) do |record|
          record.title = details.fetch("title")
          record.release_date = details["release_date"].presence
          record.genre_ids = details.fetch("genres", []).map { |genre| genre.fetch("id") }
        end
      end

      movie.with_lock do
        rating = Current.user.ratings.find_or_initialize_by(movie: movie)
        rating.update!(score: params.dig(:rating, :score))
      end
    end
    redirect_to movie_path(params[:tmdb_id]), notice: "Оценка сохранена.", status: :see_other
  rescue ActiveRecord::RecordInvalid
    redirect_to movie_path(params[:tmdb_id]), alert: "Выберите целую оценку от 1 до 10.", status: :see_other
  rescue Tmdb::MovieSearch::Error
    redirect_to movie_path(params[:tmdb_id]), alert: "Не удалось загрузить фильм. Попробуйте сохранить оценку позже.", status: :see_other
  end
end
