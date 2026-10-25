require "test_helper"

class RoomQuizzesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @room = Room.create!(name: "Quiz room", owner: users(:one))
    @room.add_member!(users(:two))
    @room.update!(selection_results: [ { "movie" => { "id" => 101, "title" => "Quiz movie", "genre_ids" => [ 878 ] }, "score" => 1, "reason" => "Test" } ])
    sign_in_as users(:one)
  end

  test "host can start and participants can see and vote on a shared card" do
    get room_path(@room)
    assert_select "form[action='#{room_quizzes_path(@room)}'] button", text: "Начать квиз"
    assert_difference "RoomQuiz.count", 1 do
      post room_quizzes_path(@room)
    end
    quiz = @room.quizzes.last
    assert_redirected_to room_quiz_path(@room, quiz)
    follow_redirect!
    assert_select "h2", text: "Quiz movie"
    assert_select "div[aria-label='Ваш голос'] form", count: 3
    assert_select "form[action='#{finish_room_quiz_path(@room, quiz)}']"
    post vote_room_quiz_path(@room, quiz), params: { tmdb_id: 101, choice: "yes", user_id: users(:two).id }
    follow_redirect!
    assert_select "[role='status']", text: /Ваш ответ: «Да»/
    assert_select "div[aria-label='Ваш голос']", count: 0
    assert_equal users(:one).id, quiz.votes.sole.user_id

    sign_in_as users(:two)
    get room_quiz_path(@room, quiz)
    assert_select "div[aria-label='Ваш голос'] form", count: 3
    assert_select "form[action='#{finish_room_quiz_path(@room, quiz)}']", count: 0
    post vote_room_quiz_path(@room, quiz), params: { tmdb_id: 101, choice: "yes" }
    follow_redirect!
    assert_select "h1", text: "Фильм выбран!"
    assert_select "section[aria-label='Выбранный фильм'] a[href='#{movie_path(101)}']"
  end

  test "only the room owner can start and finish" do
    quiz = @room.start_quiz!(users(:one))
    sign_in_as users(:two)
    assert_no_difference "RoomQuiz.count" do
      post room_quizzes_path(@room)
    end
    assert_response :forbidden
    post finish_room_quiz_path(@room, quiz)
    assert_response :forbidden
    assert quiz.reload.active?
  end

  test "nonmembers and mismatched room ids cannot access any quiz action" do
    quiz = @room.start_quiz!(users(:one))
    outsider_room = Room.create!(name: "Other room", owner: users(:two))
    sign_in_as users(:two)
    get room_quiz_path(outsider_room, quiz)
    assert_response :not_found
    @room.remove_member!(users(:two))
    get room_quiz_path(@room, quiz)
    assert_response :not_found
    get room_quiz_path(@room, quiz, format: :json)
    assert_response :not_found
    post room_quizzes_path(@room)
    assert_response :not_found
    post vote_room_quiz_path(@room, quiz), params: { tmdb_id: 101, choice: "yes" }
    assert_response :not_found
    post finish_room_quiz_path(@room, quiz)
    assert_response :not_found
    assert_empty quiz.votes
  end

  test "late joiners can watch but cannot vote in an existing quiz" do
    @room.remove_member!(users(:two))
    quiz = @room.start_quiz!(users(:one))
    @room.add_member!(users(:two))
    sign_in_as users(:two)
    get room_quiz_path(@room, quiz)
    assert_response :success
    assert_select "div[aria-label='Ваш голос']", count: 0
    assert_includes response.body, "Вы вступили в комнату после запуска квиза"
    post vote_room_quiz_path(@room, quiz), params: { tmdb_id: 101, choice: "yes" }
    assert_response :not_found
  end

  test "polling reports a new version after a vote and requires authentication" do
    quiz = @room.start_quiz!(users(:one))
    get room_quiz_path(@room, quiz, format: :json)
    before_version = response.parsed_body.fetch("version")
    travel 1.second do
      post vote_room_quiz_path(@room, quiz), params: { tmdb_id: 101, choice: "unsure" }
    end
    get room_quiz_path(@room, quiz, format: :json)
    assert_not_equal before_version, response.parsed_body.fetch("version")
    sign_out
    get room_quiz_path(@room, quiz, format: :json)
    assert_redirected_to new_session_path
  end

  test "host gets a helpful message when there is no selection" do
    @room.update!(selection_results: [])
    assert_no_difference "RoomQuiz.count" do
      post room_quizzes_path(@room)
    end
    assert_redirected_to room_path(@room)
    follow_redirect!
    assert_select "[role='alert']", text: /Сначала подберите фильмы/
  end

  test "invalid choice cannot save a vote or change genre weights" do
    quiz = @room.start_quiz!(users(:one))
    assert_no_difference "RoomQuizVote.count" do
      post vote_room_quiz_path(@room, quiz), params: { tmdb_id: 101, choice: "invalid" }
    end
    follow_redirect!
    assert_select "[role='alert']", text: /Выберите «Нет»/
    assert_empty @room.reload.quiz_genre_weights
  end
end
