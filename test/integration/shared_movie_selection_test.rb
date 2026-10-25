require "test_helper"
require "uri"

class SharedMovieSelectionTest < ActionDispatch::IntegrationTest
  class Catalog
    attr_reader :discover_calls

    def initialize
      @discover_calls = []
      @movies = [
        { "id" => 101, "title" => "Космос", "genre_ids" => [ 878 ] },
        { "id" => 102, "title" => "Комедия", "genre_ids" => [ 35 ] },
        { "id" => 201, "title" => "Совместное приключение", "genre_ids" => [ 878, 35 ] }
      ].map { |movie| movie.merge("vote_average" => 8, "vote_count" => 200, "release_date" => "2020-01-01") }
    end

    def search(query)
      @movies
    end

    def details(id)
      movie = @movies.find { |item| item.fetch("id") == id.to_i }
      movie.merge("genres" => movie.fetch("genre_ids").map { |genre_id| { "id" => genre_id, "name" => "Жанр" } })
    end

    def discover(**filters)
      @discover_calls << filters
      @movies
    end
  end

  test "two users register rate films join the same room and open a shared recommendation" do
    catalog = Catalog.new
    original = Tmdb::MovieSearch.method(:new)
    Tmdb::MovieSearch.define_singleton_method(:new) { catalog }
    owner = open_session
    guest = open_session

    owner.post registration_path, params: { user: registration("cinema_owner") }
    owner.assert_redirected_to root_path
    owner.follow_redirect!
    owner.assert_response :success
    owner.get movies_path, params: { query: "Космос" }
    owner.assert_select "a[href='#{movie_path(101)}']"
    owner.get movie_path(101)
    owner.assert_response :success
    owner.put movie_rating_path(101), params: { rating: { score: 10 } }
    owner.assert_redirected_to movie_path(101)
    owner.post rooms_path, params: { room: { name: "Кино вдвоём" } }
    room = Room.find_by!(name: "Кино вдвоём")
    owner.assert_redirected_to room_path(room)
    owner.follow_redirect!
    invitation_url = Nokogiri::HTML5(owner.response.body).at_css("#invitation-link")["value"]
    invitation_path = URI(invitation_url).request_uri

    guest.get invitation_path
    guest.assert_redirected_to new_session_path
    guest.get new_registration_path
    guest.assert_response :success
    guest.post registration_path, params: { user: registration("cinema_guest") }
    guest.assert_redirected_to invitation_path
    guest.follow_redirect!
    guest.assert_select "h1", text: "Кино вдвоём"
    assert_equal 1, room.members.count
    guest.post invitation_path
    guest.assert_redirected_to room_path(room)
    guest.follow_redirect!
    guest.assert_select "ul[aria-label='Участники комнаты'] li", count: 2
    guest.get movies_path, params: { query: "Комедия" }
    guest.assert_select "a[href='#{movie_path(102)}']"
    guest.get movie_path(102)
    guest.put movie_rating_path(102), params: { rating: { score: 10 } }
    guest.assert_redirected_to movie_path(102)
    guest.get rooms_path
    guest.assert_select "a[href='#{room_path(room)}']", text: "Кино вдвоём"
    guest.get root_path
    guest.assert_select "ul[aria-label='Мои комнаты'] a", text: "Кино вдвоём"

    owner.get room_path(room)
    owner.assert_select "ul[aria-label='Участники комнаты'] li", count: 2
    owner.post selection_room_path(room), params: { genre: "", duration: "120", exclude_watched: "1" }
    owner.assert_redirected_to selection_room_path(room)
    owner.follow_redirect!
    owner.assert_select "a[href='#{movie_path(201)}']"
    owner.assert_select "a[href='#{movie_path(101)}']", count: 0
    owner.assert_select "a[href='#{movie_path(102)}']", count: 0
    assert_equal [ 201 ], room.reload.selection_results.map { |result| result.fetch("movie").fetch("id") }
    assert_equal "120", room.selection_filters.fetch("duration")
    assert room.selection_generated_at.present?
    assert_equal 120, catalog.discover_calls.first.fetch(:duration)

    calls_before_reading = catalog.discover_calls.size
    guest.get selection_room_path(room)
    guest.assert_response :success
    guest.assert_select "a[href='#{movie_path(201)}']"
    guest.assert_select "select[name='duration'] option[selected][value='120']"
    owner.get selection_room_path(room)
    owner.assert_select "a[href='#{movie_path(201)}']"
    assert_equal calls_before_reading, catalog.discover_calls.size

    guest.get movie_path(201)
    guest.assert_select "h1", text: "Совместное приключение"
    guest.put movie_rating_path(201), params: { rating: { score: 9 } }
    guest.get ratings_path
    guest.assert_select "a[href='#{movie_path(201)}']", text: "Совместное приключение"
    owner.get ratings_path
    owner.assert_select "a[href='#{movie_path(201)}']", count: 0
  ensure
    Tmdb::MovieSearch.define_singleton_method(:new, original) if original
  end

  test "an empty selection can be shared and regenerated including rated movies" do
    catalog = Catalog.new
    original = Tmdb::MovieSearch.method(:new)
    Tmdb::MovieSearch.define_singleton_method(:new) { catalog }
    room = Room.create!(name: "All watched", owner: users(:one))
    [ 101, 102, 201 ].each do |id|
      movie = Movie.create!(tmdb_id: id, title: "Watched #{id}", genre_ids: [])
      movie.ratings.create!(user: users(:one), score: 8)
    end
    sign_in_as users(:one)
    post selection_room_path(room), params: { exclude_watched: "1" }
    assert_redirected_to selection_room_path(room)
    follow_redirect!
    assert_select "p", text: /Подходящих фильмов не найдено/
    assert room.reload.selection_generated_at.present?
    assert_empty room.selection_results

    post selection_room_path(room), params: { exclude_watched: "0" }
    follow_redirect!
    assert_equal 3, room.reload.selection_results.size
    assert_select "input[type='checkbox'][name='exclude_watched'][checked]", count: 0
  ensure
    Tmdb::MovieSearch.define_singleton_method(:new, original) if original
  end

  private

  def registration(nickname)
    { nickname: nickname, email_address: "#{nickname}@example.com", password: "password123", password_confirmation: "password123" }
  end
end
