require "test_helper"

class MovieRecommendationsTest < ActiveSupport::TestCase
  class Catalog
    attr_reader :calls, :detail_calls

    def initialize(movies)
      @movies = movies
      @calls = []
      @detail_calls = []
    end

    def discover(**filters)
      @calls << filters
      @movies
    end

    def details(id)
      @detail_calls << id
      { "genres" => [ { "id" => 878 } ] }
    end
  end

  def candidate(id, genres, vote_average: 7, vote_count: 100)
    { "id" => id, "title" => "Movie #{id}", "genre_ids" => genres,
      "vote_average" => vote_average, "vote_count" => vote_count }
  end

  def rate(id, genres, score, user: users(:one))
    movie = Movie.create!(tmdb_id: id, title: "Rated #{id}", genre_ids: genres)
    movie.ratings.create!(user: user, score: score)
    movie
  end

  test "likes raise matching genres and dislikes lower them" do
    rate(1, [ 878 ], 10)
    rate(2, [ 35 ], 1)
    client = Catalog.new([ candidate(3, [ 35 ]), candidate(4, [ 18 ]), candidate(5, [ 878 ]) ])
    results = MovieRecommendations.new(user: users(:one), client: client).call
    assert_equal [ 5, 4, 3 ], results.map { |result| result.movie["id"] }
    assert_includes results.first.reason, "высоко оценили"
    assert_equal 3, client.calls.size
    assert_equal [ 878 ], client.calls.last[:genre_ids]
  end

  test "excludes only current user's rated films and can include them on request" do
    rate(1, [], 8)
    rate(2, [], 9, user: users(:two))
    client = Catalog.new([ candidate(1, []), candidate(2, []) ])
    service = MovieRecommendations.new(user: users(:one), client: client)
    assert_equal [ 2 ], service.call.map { |result| result.movie["id"] }
    assert_equal [ 1, 2 ], service.call(exclude_watched: false).map { |result| result.movie["id"] }
  end

  test "cold start ranks by public quality and removes duplicate candidates" do
    client = Catalog.new([ candidate(1, [], vote_average: 6), candidate(2, [], vote_average: 9) ])
    results = MovieRecommendations.new(user: users(:one), client: client).call
    assert_equal [ 2, 1 ], results.map { |result| result.movie["id"] }
    assert_includes results.first.reason, "Популярный"
  end

  test "passes duration and explicit genre filters and limits results" do
    client = Catalog.new([ candidate(1, [ 35 ]), candidate(2, [ 878 ]), candidate(3, [ 35 ]) ])
    results = MovieRecommendations.new(user: users(:one), client: client).call(genre: "comedy", duration: "90", limit: 1)
    assert_equal [ 1 ], results.map { |result| result.movie["id"] }
    assert_equal({ genre_ids: [ 35 ], duration: 90, page: 1 }, client.calls.first)
  end

  test "ignores unsupported filters" do
    client = Catalog.new([])
    assert_empty MovieRecommendations.new(user: users(:one), client: client).call(genre: "unknown", duration: "-10")
    assert_nil client.calls.first[:duration]
    assert_empty client.calls.first[:genre_ids]
  end

  test "backfills old movies once and uses their genres immediately" do
    movie = rate(1, nil, 10)
    client = Catalog.new([ candidate(2, [ 35 ]), candidate(3, [ 878 ]) ])
    service = MovieRecommendations.new(user: users(:one), client: client)
    assert_equal 3, service.call.first.movie["id"]
    assert_equal [ 878 ], movie.reload.genre_ids
    service.call
    assert_equal [ "1" ], client.detail_calls
  end

  test "another user's ratings do not affect preferences" do
    rate(1, [ 35 ], 10, user: users(:two))
    client = Catalog.new([ candidate(2, [ 35 ]), candidate(3, [ 878 ]) ])
    assert_equal [ 2, 3 ], MovieRecommendations.new(user: users(:one), client: client).call.map { |result| result.movie["id"] }
    assert_equal 2, client.calls.size
  end

  test "group preferences give every member equal weight regardless of rating count" do
    rate(1, [ 878 ], 10)
    rate(2, [ 878 ], 10)
    rate(3, [ 878 ], 1, user: users(:two))
    client = Catalog.new([ candidate(4, [ 878 ]), candidate(5, [ 18 ]) ])
    results = MovieRecommendations.new(users: [ users(:one), users(:two) ], client: client).call
    assert_in_delta results.first.score, results.last.score, 0.0001
    assert_equal 2, client.calls.size
  end

  test "group recommendations use both members and ignore outsiders" do
    rate(1, [ 878 ], 10)
    rate(2, [ 35 ], 10, user: users(:two))
    outsider = User.create!(nickname: "outsider", email_address: "outsider@example.com", password: "password123")
    rate(3, [ 18 ], 10, user: outsider)
    client = Catalog.new([ candidate(4, [ 878 ]), candidate(5, [ 35 ]), candidate(6, [ 18 ]) ])
    results = MovieRecommendations.new(users: [ users(:one), users(:two) ], client: client).call
    assert_equal [ 4, 5, 6 ], results.map { |result| result.movie["id"] }
    assert_in_delta results[0].score, results[1].score, 0.0001
    assert_operator results[1].score, :>, results[2].score
    assert_includes results.first.reason, "участников комнаты"
  end

  test "group excludes films rated by any member and can include them on request" do
    rate(1, [], 8)
    rate(2, [], 9, user: users(:two))
    client = Catalog.new([ candidate(1, []), candidate(2, []), candidate(3, []) ])
    service = MovieRecommendations.new(users: [ users(:one), users(:two) ], client: client)
    assert_equal [ 3 ], service.call.map { |result| result.movie["id"] }
    assert_equal [ 1, 2, 3 ], service.call(exclude_watched: false).map { |result| result.movie["id"] }
  end

  test "group backfills each shared movie only once and applies genres to every rating" do
    movie = rate(1, nil, 10)
    movie.ratings.create!(user: users(:two), score: 1)
    client = Catalog.new([ candidate(2, [ 878 ]), candidate(3, [ 18 ]) ])
    results = MovieRecommendations.new(users: [ users(:one), users(:two) ], client: client).call
    assert_equal [ "1" ], client.detail_calls
    assert_in_delta results.first.score, results.last.score, 0.0001
  end

  test "a group without ratings can get a public quality ranking" do
    client = Catalog.new([ candidate(1, [], vote_average: 6), candidate(2, [], vote_average: 9) ])
    results = MovieRecommendations.new(users: [ users(:one), users(:two) ], client: client).call
    assert_equal [ 2, 1 ], results.map { |result| result.movie["id"] }
    assert_includes results.first.reason, "вашей компании"
  end

  test "room quiz penalties lower matching candidates without changing personal recommendations" do
    client = Catalog.new([ candidate(1, [ 878 ]), candidate(2, [ 35 ]) ])
    adjustments = { "878" => -0.25 }
    group_results = MovieRecommendations.new(users: [ users(:one), users(:two) ], client: client).call(genre_adjustments: adjustments)
    personal_results = MovieRecommendations.new(user: users(:one), client: client).call(genre_adjustments: adjustments)
    assert_equal [ 2, 1 ], group_results.map { |result| result.movie.fetch("id") }
    assert_equal [ 1, 2 ], personal_results.map { |result| result.movie.fetch("id") }
  end
end
