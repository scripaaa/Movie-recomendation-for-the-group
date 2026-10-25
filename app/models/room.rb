class Room < ApplicationRecord
  class OwnerRemovalError < StandardError; end

  belongs_to :owner, class_name: "User"
  has_many :memberships, dependent: :destroy
  has_many :members, through: :memberships, source: :user
  has_many :quizzes, class_name: "RoomQuiz", dependent: :destroy

  normalizes :name, with: ->(name) { name.strip }
  validates :name, presence: true, length: { maximum: 80 }
  after_create :add_owner_membership!

  def add_member!(user)
    with_lock do
      memberships.find_by(user: user) || memberships.create!(user: user)
    end
  end

  def remove_member!(user)
    raise OwnerRemovalError, "The owner cannot leave their room" if user == owner

    memberships.find_by(user: user)&.destroy!
  end

  def start_quiz!(user)
    raise ActiveRecord::RecordNotFound unless user.id == owner_id

    with_lock do
      quizzes.find_by(status: "active") || begin
        raise RoomQuiz::EmptySelectionError if selection_results.empty?

        quiz = quizzes.new(started_by: user, participant_ids: members.order(:id).pluck(:id),
          candidates: selection_results, initial_genre_weights: selection_filters.fetch("quiz_genre_weights", {}))
        quiz.current_movie_id = quiz.ranked_candidates.first.fetch("movie").fetch("id")
        quiz.save!
        quiz
      end
    end
  end

  private

  def add_owner_membership!
    add_member!(owner)
  end
end
