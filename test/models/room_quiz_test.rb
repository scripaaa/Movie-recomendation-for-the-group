require "test_helper"

class RoomQuizTest < ActiveSupport::TestCase
  setup do
    @room = Room.create!(name: "Quiz room", owner: users(:one))
    @room.add_member!(users(:two))
    @room.update!(selection_results: [ candidate(101, [ 878 ], 1.0), candidate(102, [ 878 ], 0.95), candidate(103, [ 35 ], 0.9) ])
    @quiz = @room.start_quiz!(users(:one))
  end

  test "starting twice resumes the active quiz with a stable list and participant snapshot" do
    assert_no_difference "RoomQuiz.count" do
      assert_equal @quiz, @room.start_quiz!(users(:one))
    end
    assert_equal [ users(:one).id, users(:two).id ].sort, @quiz.participant_ids.sort
    assert_equal 101, @quiz.current_movie_id
    @room.update!(selection_results: [])
    assert_equal 3, @quiz.reload.candidates.size
  end

  test "unanimous yes selects the movie only after every participant voted" do
    assert_no_difference "Rating.count" do
      vote(users(:one), "yes")
      assert @quiz.active?
      vote(users(:two), "yes")
    end
    assert @quiz.selected?
    assert_equal 101, @quiz.selected_movie_id
    assert_empty @room.reload.quiz_genre_weights
  end

  test "no penalizes only the room's genres and changes the next movie" do
    other_room = Room.create!(name: "Other room", owner: users(:one))
    vote(users(:one), "no")
    assert_equal 101, @quiz.current_movie_id
    assert_in_delta(-0.125, @room.reload.quiz_genre_weights.fetch("878"))
    vote(users(:two), "unsure")
    assert_equal [ 101 ], @quiz.skipped_movie_ids
    assert_equal 103, @quiz.current_movie_id
    assert_empty other_room.reload.quiz_genre_weights
    assert_empty Rating.all
  end

  test "unsure preserves weights and advances only when everyone has answered" do
    vote(users(:one), "unsure")
    assert_equal 101, @quiz.current_movie_id
    vote(users(:two), "unsure")
    assert_equal 102, @quiz.current_movie_id
    assert_empty @room.reload.quiz_genre_weights
    assert_nil @quiz.best_round
  end

  test "repeated votes cannot change answers penalize twice or skip another round" do
    vote(users(:one), "no")
    weights = @room.reload.quiz_genre_weights
    @quiz.vote!(user: users(:one), tmdb_id: 101, choice: "yes")
    assert_equal "no", @quiz.votes.find_by!(user: users(:one)).choice
    assert_equal weights, @room.reload.quiz_genre_weights
    vote(users(:two), "no")
    weights = @room.reload.quiz_genre_weights
    current_id = @quiz.current_movie_id
    assert_no_difference "RoomQuizVote.count" do
      @quiz.vote!(user: users(:one), tmdb_id: 101, choice: "no")
    end
    assert_equal current_id, @quiz.current_movie_id
    assert_equal weights, @room.reload.quiz_genre_weights
  end

  test "future movies invalid choices and people outside the roster cannot affect the quiz" do
    outsider = User.create!(nickname: "quiz_outsider", email_address: "quiz_outsider@example.com", password: "password123")
    assert_no_difference "RoomQuizVote.count" do
      assert_raises(RoomQuiz::StaleVoteError) { @quiz.vote!(user: users(:one), tmdb_id: 102, choice: "no") }
      assert_raises(ActiveRecord::RecordInvalid) { @quiz.vote!(user: users(:one), tmdb_id: 101, choice: "invalid") }
      assert_raises(ActiveRecord::RecordNotFound) { @quiz.vote!(user: outsider, tmdb_id: 101, choice: "yes") }
    end
    assert_empty @room.reload.quiz_genre_weights
    assert_equal 101, @quiz.reload.current_movie_id
  end

  test "host selection uses completed rounds and leaves an unfinished round out" do
    vote(users(:one), "yes")
    vote(users(:two), "no")
    vote(users(:one), "yes")
    @quiz.finish!
    assert @quiz.selected?
    assert_equal 101, @quiz.selected_movie_id
    assert_raises(RoomQuiz::ClosedError) { vote(users(:two), "yes") }
  end

  test "seven rounds with nine people preserve the first six-yes leader and cap penalties" do
    @quiz.finish!
    7.times do |index|
      person = User.create!(nickname: "quiz_member_#{index}", email_address: "quiz_member_#{index}@example.com", password: "password123")
      @room.add_member!(person)
    end
    @room.update!(selection_results: (201..207).map { |id| candidate(id, [ 878 ], 1.0) })
    quiz = @room.start_quiz!(users(:one))
    first_movie_id = quiz.current_movie_id
    participants = @room.members.order(:id).to_a
    [ 6, 5, 6, 4, 3, 5, 2 ].each do |yes_count|
      movie_id = quiz.current_movie_id
      participants.each_with_index do |person, index|
        quiz.vote!(user: person, tmdb_id: movie_id, choice: index < yes_count ? "yes" : "no")
      end
      assert_not quiz.selected?
    end
    assert quiz.exhausted?
    assert_equal 7, quiz.skipped_movie_ids.size
    assert_equal 6, quiz.best_round.fetch(:yes_count)
    assert_equal first_movie_id, quiz.best_round.fetch(:candidate).fetch("movie").fetch("id")
    quiz.finish!
    assert quiz.selected?
    assert_equal first_movie_id, quiz.selected_movie_id
    assert_operator @room.reload.quiz_genre_weights.fetch("878"), :>=, -1.0
  end

  test "finishing without a positive completed round selects nothing" do
    vote(users(:one), "yes")
    @quiz.finish!
    assert @quiz.finished?
    assert_nil @quiz.selected_candidate
  end

  test "an exhausted old quiz cannot replace a newer quiz" do
    3.times do
      vote(users(:one), "unsure")
      vote(users(:two), "unsure")
    end
    assert @quiz.exhausted?
    newer = @room.start_quiz!(users(:one))
    assert_raises(RoomQuiz::ClosedError) { @quiz.finish! }
    assert newer.reload.active?
  end

  test "saved penalties are not counted twice when starting from an updated selection" do
    @quiz.finish!
    @room.update!(quiz_genre_weights: { "878" => -0.5 }, selection_filters: { "quiz_genre_weights" => { "878" => -0.5 } })
    quiz = @room.start_quiz!(users(:one))
    assert_equal 101, quiz.current_movie_id
  end

  test "destroying the room removes its quizzes and votes" do
    vote(users(:one), "no")
    assert_difference "RoomQuiz.count", -1 do
      assert_difference "RoomQuizVote.count", -1 do
        @room.destroy!
      end
    end
  end

  private

  def vote(user, choice)
    @quiz.vote!(user: user, tmdb_id: @quiz.current_movie_id, choice: choice)
  end

  def candidate(id, genres, score)
    { "movie" => { "id" => id, "title" => "Film #{id}", "genre_ids" => genres, "vote_count" => 100 }, "score" => score, "reason" => "Test" }
  end
end
