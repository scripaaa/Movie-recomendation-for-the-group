class MoviesController < ApplicationController
  def index
    @query = params[:query].to_s.strip
    movie_search = Tmdb::MovieSearch.new

    if @query.present?
      @movies = movie_search.search(@query)
      @section_title = "Результаты поиска"
    else
      @movies = movie_search.popular
      @section_title = "Популярные сейчас"
    end
  rescue Tmdb::MovieSearch::ConfigurationError
    @error_message = "Для поиска нужно настроить TMDB API Read Access Token. Инструкция есть в README."
  rescue Tmdb::MovieSearch::AuthenticationError
    @error_message = "TMDB отклонил токен. Проверьте, что задан именно API Read Access Token без слова Bearer, затем перезапустите Rails."
  rescue Tmdb::MovieSearch::Error => error
    Rails.logger.warn("TMDB movie search failed: #{error.message}")
    @error_message = "Не удалось связаться с TMDB. Попробуйте ещё раз чуть позже."
  end

  def show
    @movie = Tmdb::MovieSearch.new.details(params[:tmdb_id])
    @rating = Current.user.ratings.joins(:movie).find_by(movies: { tmdb_id: params[:tmdb_id] })
  rescue Tmdb::MovieSearch::ConfigurationError
    @error_message = "Для просмотра фильма нужно настроить TMDB API Read Access Token. Инструкция есть в README."
  rescue Tmdb::MovieSearch::AuthenticationError
    @error_message = "TMDB отклонил токен. Проверьте, что задан именно API Read Access Token без слова Bearer, затем перезапустите Rails."
  rescue Tmdb::MovieSearch::NotFoundError
    @error_message = "Фильм не найден в каталоге TMDB."
  rescue Tmdb::MovieSearch::Error => error
    Rails.logger.warn("TMDB movie details failed: #{error.message}")
    @error_message = "Не удалось загрузить информацию о фильме. Попробуйте ещё раз чуть позже."
  end
end
