class Movie < ApplicationRecord
  has_many :ratings, dependent: :destroy

  validates :tmdb_id, presence: true, uniqueness: true, numericality: { only_integer: true, greater_than: 0 }
  validates :title, presence: true

  def average_rating
    ratings.average(:score)
  end
end
