require "test_helper"

class RoomsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @room = Room.create!(name: "Friday movies", owner: users(:one))
    sign_in_as users(:one)
  end

  test "creating a room saves its owner and shows an invitation and the owner as a member" do
    get new_room_path
    assert_response :success
    assert_select "form[action='#{rooms_path}'][method='post']"

    assert_difference [ "Room.count", "Membership.count" ], 1 do
      post rooms_path, params: { room: { name: "  Our cinema  ", owner_id: users(:two).id } }
    end
    room = Room.order(:id).last
    assert_equal "Our cinema", room.name
    assert_equal users(:one), room.owner
    assert_equal [ users(:one) ], room.members.to_a
    assert_redirected_to room_path(room)
    follow_redirect!
    assert_select "h1", text: "Our cinema"
    assert_select "ul[aria-label='Участники комнаты'] li", count: 1
    assert_select "input#invitation-link[value='#{room_invitation_url(room.signed_id(purpose: :room_invitation))}']"
    assert_select "form[action='#{selection_room_path(room)}'][method='post']"
    assert_select "[data-controller*='pending-action']", count: 0
  end

  test "invalid names do not create rooms or memberships" do
    [ "   ", "a" * 81 ].each do |name|
      assert_no_difference [ "Room.count", "Membership.count" ] do
        post rooms_path, params: { room: { name: name } }
      end
      assert_response :unprocessable_entity
      assert_select "[role='alert']", text: /Введите название/
    end
  end

  test "the list and profile show only rooms the user belongs to" do
    other_room = Room.create!(name: "Private room", owner: users(:two))
    get rooms_path
    assert_response :success
    assert_select "a[href='#{room_path(@room)}']", text: @room.name
    assert_select "a[href='#{room_path(other_room)}']", count: 0
    get root_path
    assert_response :success
    assert_select "ul[aria-label='Мои комнаты'] a[href='#{room_path(@room)}']"
    assert_select "a[href='#{room_path(other_room)}']", count: 0
  end

  test "nonmembers cannot read a room or its selection or generate recommendations" do
    sign_in_as users(:two)
    get room_path(@room)
    assert_response :not_found
    get selection_room_path(@room)
    assert_response :not_found
    post selection_room_path(@room), params: { genre: "comedy" }
    assert_response :not_found
    assert_nil @room.reload.selection_generated_at
  end

  test "legacy links redirect to a real room or the room list" do
    get current_room_path
    assert_redirected_to room_path(@room)
    get current_room_selection_path
    assert_redirected_to selection_room_path(@room)
    sign_in_as users(:two)
    get current_room_path
    assert_redirected_to rooms_path
    get current_room_selection_path
    assert_redirected_to rooms_path
  end

  test "a failed refresh preserves the shared selection" do
    @room.update!(selection_results: [ { movie: { id: 123, title: "Saved movie" }, reason: "Saved reason" } ],
      selection_filters: { genre: "comedy" }, selection_generated_at: 1.hour.ago)
    snapshot = @room.attributes.slice("selection_results", "selection_filters", "selection_generated_at")
    client = Object.new
    def client.discover(**filters)
      raise Tmdb::MovieSearch::Error, "Unavailable"
    end
    original = Tmdb::MovieSearch.method(:new)
    Tmdb::MovieSearch.define_singleton_method(:new) { client }

    post selection_room_path(@room), params: { genre: "drama" }
    assert_redirected_to room_path(@room)
    assert_equal snapshot, @room.reload.attributes.slice(*snapshot.keys)
    follow_redirect!
    assert_select "[role='alert']", text: /Не удалось получить фильмы/
    assert_select "a[href='#{movie_path(123)}']"
  ensure
    Tmdb::MovieSearch.define_singleton_method(:new, original) if original
  end

  test "room actions require authentication" do
    sign_out
    get rooms_path
    assert_redirected_to new_session_path
    assert_no_difference "Room.count" do
      post rooms_path, params: { room: { name: "No session" } }
    end
    assert_redirected_to new_session_path
    post selection_room_path(@room)
    assert_redirected_to new_session_path
  end
end
