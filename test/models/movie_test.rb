require "test_helper"

class MovieTest < ActiveSupport::TestCase
  setup do
    @movie = Movie.create!(tmdb_id: 100, title: "Test movie")
  end

  test "average is absent without ratings" do
    assert_nil @movie.average_rating
  end

  test "average with one rating equals that score" do
    @movie.ratings.create!(user: users(:one), score: 7)
    assert_equal 7, @movie.average_rating
  end

  test "average includes all ratings and preserves fractions" do
    @movie.ratings.create!(user: users(:one), score: 7)
    @movie.ratings.create!(user: users(:two), score: 8)
    Movie.create!(tmdb_id: 101, title: "Another movie").ratings.create!(user: users(:one), score: 1)

    assert_equal BigDecimal("7.5"), @movie.average_rating
  end

  test "requires a title and a unique positive integer TMDB id" do
    movie = Movie.new(tmdb_id: 100, title: " ")
    assert_not movie.valid?
    assert movie.errors.added?(:tmdb_id, :taken, value: 100)
    assert movie.errors[:title].present?

    [ nil, 0, -1, 1.5 ].each do |id|
      movie.tmdb_id = id
      assert_not movie.valid?
      assert movie.errors[:tmdb_id].present?
    end
  end
end
