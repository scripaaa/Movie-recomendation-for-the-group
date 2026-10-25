class RoomQuizVote < ApplicationRecord
  CHOICES = { "no" => "Нет", "unsure" => "Не знаю", "yes" => "Да" }.freeze

  belongs_to :room_quiz
  belongs_to :user

  validates :choice, inclusion: { in: CHOICES.keys }
  validates :tmdb_id, numericality: { only_integer: true, greater_than: 0 }
  validates :user_id, uniqueness: { scope: [ :room_quiz_id, :tmdb_id ] }
end
