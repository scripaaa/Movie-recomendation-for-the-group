class RoomQuiz < ApplicationRecord
  class EmptySelectionError < StandardError; end
  class ClosedError < StandardError; end
  class StaleVoteError < StandardError; end

  belongs_to :room
  belongs_to :started_by, class_name: "User"
  has_many :votes, class_name: "RoomQuizVote", dependent: :destroy

  enum :status, { active: "active", selected: "selected", exhausted: "exhausted", finished: "finished" }, validate: true

  def current_candidate
    candidate(current_movie_id)
  end

  def selected_candidate
    candidate(selected_movie_id)
  end

  def round_votes
    votes.where(tmdb_id: current_movie_id)
  end

  def completed_rounds
    yes_counts = votes.where(choice: "yes", tmdb_id: skipped_movie_ids).group(:tmdb_id).count
    skipped_movie_ids.map do |id|
      { candidate: candidate(id), yes_count: yes_counts.fetch(id, 0) }
    end
  end

  def best_round
    completed_rounds.select { |round| round[:yes_count].positive? }.max_by { |round| round[:yes_count] }
  end

  def ranked_candidates
    candidates.reject { |item| skipped_movie_ids.include?(item.fetch("movie").fetch("id")) }.sort_by do |item|
      movie = item.fetch("movie")
      ids = movie.fetch("genre_ids", []).map(&:to_s)
      adjustment = ids.empty? ? 0.0 : ids.sum { |id| room.quiz_genre_weights.fetch(id, 0.0) - initial_genre_weights.fetch(id, 0.0) } / ids.size
      [ -(item.fetch("score", 0.0) + adjustment * 2), -movie["vote_count"].to_i, movie.fetch("id") ]
    end
  end

  def vote!(user:, tmdb_id:, choice:)
    room.with_lock do
      reload
      raise ActiveRecord::RecordNotFound unless participant_ids.include?(user.id)

      # Retried requests must not apply a genre penalty or advance a round twice.
      unless votes.exists?(user: user, tmdb_id: tmdb_id)
        raise ClosedError unless active?
        raise StaleVoteError unless tmdb_id.to_s == current_movie_id.to_s

        votes.create!(user: user, tmdb_id: current_movie_id, choice: choice)
        penalize_genres! if choice == "no"
        if round_votes.count == participant_ids.size
          if round_votes.where(choice: "yes").count == participant_ids.size
            self.status = :selected
            self.selected_movie_id = current_movie_id
          else
            self.skipped_movie_ids = skipped_movie_ids + [ current_movie_id ]
            self.current_movie_id = ranked_candidates.first&.fetch("movie")&.fetch("id")
            self.status = :exhausted unless current_movie_id
          end
        end
        self.updated_at = Time.current
        save!
      end
    end
    self
  end

  def finish!
    room.with_lock do
      reload
      unless selected? || finished?
        raise ClosedError unless room.quizzes.order(id: :desc).first.id == id

        best = best_round
        update!(status: best ? :selected : :finished, selected_movie_id: best&.fetch(:candidate)&.fetch("movie")&.fetch("id"))
      end
    end
    self
  end

  private

  def candidate(tmdb_id)
    candidates.find { |item| item.fetch("movie").fetch("id") == tmdb_id }
  end

  def penalize_genres!
    weights = room.quiz_genre_weights.dup
    Array(current_candidate.fetch("movie")["genre_ids"]).map(&:to_s).uniq.each do |genre_id|
      weights[genre_id] = [ weights.fetch(genre_id, 0.0) - 0.25 / participant_ids.size, -1.0 ].max
    end
    room.update!(quiz_genre_weights: weights)
  end
end
