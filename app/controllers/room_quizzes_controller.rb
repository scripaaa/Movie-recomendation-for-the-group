class RoomQuizzesController < ApplicationController
  before_action :set_room
  before_action :set_quiz, except: :create
  before_action :require_host, only: %i[ create finish ]

  def create
    quiz = @room.start_quiz!(Current.user)
    redirect_to room_quiz_path(@room, quiz), status: :see_other
  rescue RoomQuiz::EmptySelectionError
    redirect_to @room, alert: "Сначала подберите фильмы для комнаты, затем начните квиз.", status: :see_other
  end

  def show
    respond_to do |format|
      format.html do
        @participants = User.where(id: @quiz.participant_ids).order(:nickname)
        @votes = @quiz.round_votes.index_by(&:user_id)
        @own_vote = @votes[Current.user.id]
        @best_round = @quiz.best_round
      end
      format.json { render json: { version: @quiz.updated_at.utc.iso8601(6) } }
    end
  end

  def vote
    @quiz.vote!(user: Current.user, tmdb_id: params[:tmdb_id], choice: params[:choice])
    redirect_to room_quiz_path(@room, @quiz), status: :see_other
  rescue RoomQuiz::StaleVoteError, RoomQuiz::ClosedError
    redirect_to room_quiz_path(@room, @quiz), alert: "Этот раунд уже завершён. Показано текущее состояние квиза.", status: :see_other
  rescue ActiveRecord::RecordInvalid
    redirect_to room_quiz_path(@room, @quiz), alert: "Выберите «Нет», «Не знаю» или «Да».", status: :see_other
  end

  def finish
    @quiz.finish!
    redirect_to room_quiz_path(@room, @quiz), status: :see_other
  rescue RoomQuiz::ClosedError
    redirect_to room_quiz_path(@room, @quiz), alert: "В комнате уже начался новый квиз.", status: :see_other
  end

  private

  def set_room
    @room = Current.user.rooms.find(params[:room_id])
  end

  def set_quiz
    @quiz = @room.quizzes.find(params[:id])
  end

  def require_host
    head :forbidden unless @room.owner_id == Current.user.id
  end
end
