class RecommendationsController < ApplicationController
  def show
    @requested = params[:commit].present? || params[:genre].present? || params[:duration].present? || params.key?(:exclude_watched)
    @recommendations = []
    return unless @requested

    @recommendations = MovieRecommendations.new(user: Current.user).call(
      genre: params[:genre], duration: params[:duration], exclude_watched: params[:exclude_watched] != "0"
    )
  rescue Tmdb::MovieSearch::ConfigurationError
    @error_message = "Для подбора фильмов нужно настроить TMDB API Read Access Token. Инструкция есть в README."
  rescue Tmdb::MovieSearch::Error
    @error_message = "Не удалось получить фильмы из TMDB. Попробуйте ещё раз позже."
  end
end
