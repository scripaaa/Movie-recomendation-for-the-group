require "test_helper"

class RoomQuizFlowTest < ActionDispatch::IntegrationTest
  test "two independent accounts vote through synchronized rounds and select the same movie without TMDB" do
    room = Room.create!(name: "Quiz together", owner: users(:one))
    room.add_member!(users(:two))
    room.update!(selection_results: [
      candidate(101, "Космическая экспедиция", 878, 1.0),
      candidate(102, "Звёздный путь", 878, 0.95),
      candidate(103, "Летние приключения", 35, 0.9)
    ])
    original = Tmdb::MovieSearch.method(:new)
    Tmdb::MovieSearch.define_singleton_method(:new) { raise "Quiz must use the saved selection" }
    host = open_session
    guest = open_session
    host.post session_path, params: { email_address: users(:one).email_address, password: "password" }
    guest.post session_path, params: { email_address: users(:two).email_address, password: "password" }

    host.get room_path(room)
    host.assert_select "form[action='#{room_quizzes_path(room)}'] button", text: "Начать квиз"
    host.post room_quizzes_path(room)
    quiz = room.quizzes.last
    host.follow_redirect!
    host.assert_select "h2", text: "Космическая экспедиция"
    guest.get room_path(room)
    guest.assert_select "a[href='#{room_quiz_path(room, quiz)}']", text: "Перейти в квиз"
    guest.get room_quiz_path(room, quiz)
    guest.assert_select "h2", text: "Космическая экспедиция"
    guest.get room_quiz_path(room, quiz, format: :json)
    initial_version = guest.response.parsed_body.fetch("version")

    host.post vote_room_quiz_path(room, quiz), params: { tmdb_id: 101, choice: "no" }
    guest.get room_quiz_path(room, quiz, format: :json)
    assert_not_equal initial_version, guest.response.parsed_body.fetch("version")
    guest.get room_quiz_path(room, quiz)
    guest.assert_select "ul[aria-label='Голоса участников'] li", text: /#{users(:one).nickname} · Нет/
    guest.post vote_room_quiz_path(room, quiz), params: { tmdb_id: 101, choice: "unsure" }
    guest.follow_redirect!
    guest.assert_select "h2", text: "Летние приключения"
    host.get room_quiz_path(room, quiz)
    host.assert_select "h2", text: "Летние приключения"

    host.post vote_room_quiz_path(room, quiz), params: { tmdb_id: 103, choice: "yes" }
    guest.post vote_room_quiz_path(room, quiz), params: { tmdb_id: 103, choice: "yes" }
    guest.follow_redirect!
    guest.assert_select "h1", text: "Фильм выбран!"
    guest.assert_select "section[aria-label='Выбранный фильм'] h2", text: "Летние приключения"
    host.get room_quiz_path(room, quiz)
    host.assert_select "section[aria-label='Выбранный фильм'] h2", text: "Летние приключения"
    host.get room_path(room)
    host.assert_select "a[href='#{room_quiz_path(room, quiz)}']", text: "Выбранный фильм →"
    assert_empty Rating.all
  ensure
    Tmdb::MovieSearch.define_singleton_method(:new, original) if original
  end

  private

  def candidate(id, title, genre, score)
    { "movie" => { "id" => id, "title" => title, "genre_ids" => [ genre ] }, "score" => score, "reason" => "Test" }
  end
end
