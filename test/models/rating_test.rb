require "test_helper"

class RatingTest < ActiveSupport::TestCase
  setup do
    @movie = Movie.create!(tmdb_id: 100, title: "Test movie")
  end

  test "accepts integer scores including both boundaries" do
    [ 1, 5, 10 ].each do |score|
      assert Rating.new(user: users(:one), movie: @movie, score: score).valid?
    end
  end

  test "rejects missing fractional and out of range scores" do
    [ nil, 0, 11, 4.5 ].each do |score|
      rating = Rating.new(user: users(:one), movie: @movie, score: score)
      assert_not rating.valid?
      assert rating.errors[:score].present?
    end
  end

  test "allows updating a score but rejects a second rating for the same pair" do
    rating = @movie.ratings.create!(user: users(:one), score: 5)
    rating.update!(score: 9)
    assert_equal 9, rating.reload.score
    assert_not Rating.new(user: users(:one), movie: @movie, score: 7).valid?
    assert Rating.new(user: users(:two), movie: @movie, score: 7).valid?
    other_movie = Movie.create!(tmdb_id: 101, title: "Another movie")
    assert Rating.new(user: users(:one), movie: other_movie, score: 7).valid?
  end

  test "database rejects duplicate ratings and out of range scores" do
    rating = @movie.ratings.create!(user: users(:one), score: 5)
    assert_raises(ActiveRecord::RecordNotUnique) do
      Rating.insert_all!([ { user_id: rating.user_id, movie_id: @movie.id, score: 6 } ])
    end
    assert_raises(ActiveRecord::StatementInvalid) { rating.update_column(:score, 11) }
  end
end
