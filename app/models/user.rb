class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :ratings, dependent: :destroy
  has_many :rated_movies, through: :ratings, source: :movie
  has_many :owned_rooms, class_name: "Room", foreign_key: :owner_id, inverse_of: :owner, dependent: :destroy
  has_many :memberships, dependent: :destroy
  has_many :rooms, through: :memberships
  has_many :room_quiz_votes, dependent: :destroy
  has_many :started_room_quizzes, class_name: "RoomQuiz", foreign_key: :started_by_id, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }
  normalizes :nickname, with: ->(nickname) { nickname.strip.downcase }

  validates :email_address, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :nickname, presence: true, uniqueness: true
  validates :password, presence: true, confirmation: true, length: { minimum: 8 }, on: :create
end
