require "test_helper"

class RatingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:one)
    @details = { "id" => 123, "title" => "Test movie", "release_date" => "2020-01-02" }
  end

  def with_tmdb(details = @details)
    client = Object.new
    client.define_singleton_method(:details) { |_id| details }
    client.define_singleton_method(:discover) { |**_filters| [ details.merge("genre_ids" => [ 878 ], "vote_average" => 8, "vote_count" => 100) ] }
    with_tmdb_client(client) { yield }
  end

  def with_tmdb_client(client)
    original = Tmdb::MovieSearch.method(:new)
    Tmdb::MovieSearch.define_singleton_method(:new) { client }
    yield
  ensure
    Tmdb::MovieSearch.define_singleton_method(:new, original)
  end

  test "saving the first rating imports movie details from TMDB" do
    with_tmdb do
      assert_difference [ "Movie.count", "Rating.count" ], 1 do
        put movie_rating_path(123), params: { rating: { score: 8, user_id: users(:two).id } }
      end
    end
    assert_redirected_to movie_path(123)
    assert_equal "Оценка сохранена.", flash[:notice]
    rating = users(:one).ratings.last
    assert_equal 8, rating.score
    assert_equal "Test movie", rating.movie.title
    assert_equal Date.new(2020, 1, 2), rating.movie.release_date
    assert_empty users(:two).ratings
  end

  test "changes own rating without changing another user's rating" do
    movie = Movie.create!(tmdb_id: 123, title: "Test movie")
    own = movie.ratings.create!(user: users(:one), score: 5)
    other = movie.ratings.create!(user: users(:two), score: 9)
    assert_no_difference [ "Movie.count", "Rating.count" ] do
      put movie_rating_path(123), params: { rating: { score: 7 } }
    end
    assert_equal 7, own.reload.score
    assert_equal 9, other.reload.score
  end

  test "invalid scores preserve existing rating" do
    movie = Movie.create!(tmdb_id: 123, title: "Test movie")
    rating = movie.ratings.create!(user: users(:one), score: 5)
    [ nil, 0, 11, "4.5", "abc" ].each do |score|
      assert_no_difference "Rating.count" do
        put movie_rating_path(123), params: { rating: { score: score } }
      end
      assert_redirected_to movie_path(123)
      assert flash[:alert].present?
      assert_equal 5, rating.reload.score
    end
  end

  test "invalid first rating rolls back movie import" do
    with_tmdb do
      assert_no_difference [ "Movie.count", "Rating.count" ] do
        put movie_rating_path(123), params: { rating: { score: 11 } }
      end
    end
    assert flash[:alert].present?
  end

  test "TMDB failure does not save records" do
    client = Object.new
    def client.details(id)
      raise Tmdb::MovieSearch::Error, "Unavailable"
    end
    with_tmdb_client(client) do
      assert_no_difference [ "Movie.count", "Rating.count" ] do
        put movie_rating_path(123), params: { rating: { score: 8 } }
      end
    end
    assert_redirected_to movie_path(123)
    assert flash[:alert].present?
  end

  test "movie page selects the saved score and submits to the real endpoint" do
    movie = Movie.create!(tmdb_id: 123, title: "Test movie")
    movie.ratings.create!(user: users(:one), score: 8)
    with_tmdb { get movie_path(123) }
    assert_response :success
    assert_select "form[action='#{movie_rating_path(123)}']" do
      assert_select "input[name='rating[score]'][value='8'][checked]"
      assert_select "button[disabled]", count: 0
    end
    assert_select "[data-controller*='pending-action']", count: 0
  end

  test "ratings list includes only the signed in user's movies" do
    own_movie = Movie.create!(tmdb_id: 123, title: "My movie")
    other_movie = Movie.create!(tmdb_id: 456, title: "Other movie")
    own_movie.ratings.create!(user: users(:one), score: 8)
    other_movie.ratings.create!(user: users(:two), score: 2)
    get ratings_path
    assert_response :success
    assert_select "a[href='#{movie_path(123)}']", text: "My movie"
    assert_select "a[href='#{movie_path(456)}']", count: 0
    assert_includes response.body, "Ваша оценка: 8 / 10"
  end

  test "ratings list shows an empty state before first rating" do
    get ratings_path
    assert_response :success
    assert_includes response.body, "Какие фильмы вам нравятся?"
  end

  test "recommendation form submission renders real movie results" do
    with_tmdb do
      get recommendations_path, params: { genre: "science_fiction", duration: "120", exclude_watched: "1" }
    end
    assert_response :success
    assert_select "a[href='#{movie_path(123)}']"
    assert_includes response.body, "Test movie"
    assert_select "select[name='genre'] option[selected][value='science_fiction']"
  end

  test "recommendations show a helpful message when TMDB fails" do
    client = Object.new
    def client.discover(**filters)
      raise Tmdb::MovieSearch::Error, "Unavailable"
    end
    with_tmdb_client(client) { get recommendations_path, params: { exclude_watched: "1" } }
    assert_response :success
    assert_select "[role='alert']", text: /Не удалось получить фильмы/
  end

  test "unauthenticated visitors cannot save ratings" do
    sign_out
    assert_no_difference [ "Movie.count", "Rating.count" ] do
      put movie_rating_path(123), params: { rating: { score: 8 } }
    end
    assert_redirected_to new_session_path
  end
end
