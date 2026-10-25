class RoomsController < ApplicationController
  before_action :set_room, only: %i[ show selection create_selection ]

  def index
    @rooms = Current.user.rooms.includes(:owner).order(created_at: :desc, id: :desc)
  end

  def new
    @room = Current.user.owned_rooms.new
  end

  def create
    @room = Current.user.owned_rooms.new(params.require(:room).permit(:name))
    if @room.save
      redirect_to @room, notice: "Комната создана. Пригласите друзей по ссылке."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @latest_quiz = @room.quizzes.order(id: :desc).first
    @members = @room.members.order(:nickname)
    @invitation_url = room_invitation_url(@room.signed_id(purpose: :room_invitation))
  end

  def selection
    @latest_quiz = @room.quizzes.order(id: :desc).first
  end

  def create_selection
    filters = params.permit(:genre, :duration, :exclude_watched).to_h
    results = MovieRecommendations.new(users: @room.members).call(
      genre: filters["genre"], duration: filters["duration"], exclude_watched: filters["exclude_watched"] != "0",
      genre_adjustments: @room.quiz_genre_weights
    )
    filters["quiz_genre_weights"] = @room.quiz_genre_weights
    @room.update!(selection_filters: filters, selection_results: results.map(&:to_h), selection_generated_at: Time.current)
    redirect_to selection_room_path(@room), status: :see_other
  rescue Tmdb::MovieSearch::ConfigurationError
    redirect_to @room, alert: "Для подбора фильмов нужно настроить TMDB API Read Access Token. Инструкция есть в README.", status: :see_other
  rescue Tmdb::MovieSearch::Error
    redirect_to @room, alert: "Не удалось получить фильмы из TMDB. Попробуйте ещё раз позже.", status: :see_other
  end

  def current
    redirect_to latest_room || rooms_path
  end

  def current_selection
    room = latest_room
    redirect_to room ? selection_room_path(room) : rooms_path
  end

  private

  def set_room
    @room = Current.user.rooms.find(params[:id])
  end

  def latest_room
    Current.user.rooms.order(created_at: :desc, id: :desc).first
  end
end
