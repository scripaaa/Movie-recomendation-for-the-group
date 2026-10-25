require "test_helper"

class RoomInvitationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @room = Room.create!(name: "Friends cinema", owner: users(:one))
    @invitation_path = room_invitation_path(@room.signed_id(purpose: :room_invitation))
    sign_in_as users(:two)
  end

  test "previewing an invitation does not join and accepting it adds one membership" do
    assert_no_difference "Membership.count" do
      get @invitation_path
    end
    assert_response :success
    assert_select "h1", text: @room.name
    assert_select "form[action='#{@invitation_path}'][method='post'] button", text: "Вступить в комнату"

    assert_difference "Membership.count", 1 do
      post @invitation_path
    end
    assert_redirected_to room_path(@room)
    follow_redirect!
    assert_select "ul[aria-label='Участники комнаты'] li", count: 2
    assert_no_difference "Membership.count" do
      post @invitation_path
    end
    get @invitation_path
    assert_redirected_to room_path(@room)
  end

  test "login returns the invited user to the invitation" do
    sign_out
    get @invitation_path
    assert_redirected_to new_session_path
    post session_path, params: { email_address: users(:two).email_address, password: "password" }
    assert_redirected_to @invitation_path
    follow_redirect!
    assert_response :success
    assert_not @room.members.exists?(users(:two).id)
  end

  test "invalid signatures other purposes and deleted rooms cannot be used to join" do
    invalid_tokens = [ @room.id.to_s, @room.signed_id(purpose: :other), @room.signed_id(purpose: :room_invitation) + "tampered" ]
    @room.destroy!
    invalid_tokens << @invitation_path.split("/").last
    invalid_tokens.each do |token|
      assert_no_difference "Membership.count" do
        post room_invitation_path(token)
      end
      assert_response :not_found
    end
  end
end
