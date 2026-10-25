require "test_helper"

class RoomTest < ActiveSupport::TestCase
  setup do
    @room = Room.create!(name: "Friday movies", owner: users(:one))
  end

  test "creation includes the owner as a member" do
    assert_equal [ users(:one) ], @room.members.to_a
  end

  test "owner membership failure rolls back room creation" do
    room = Room.new(name: "Failed room", owner: users(:one))
    def room.add_member!(user)
      raise ActiveRecord::RecordInvalid.new(Membership.new)
    end

    assert_no_difference [ "Room.count", "Membership.count" ] do
      assert_raises(ActiveRecord::RecordInvalid) { room.save! }
    end
  end

  test "adds a member and returns existing membership on repeat" do
    membership = nil
    assert_difference "Membership.count", 1 do
      membership = @room.add_member!(users(:two))
    end
    assert_no_difference "Membership.count" do
      assert_equal membership, @room.add_member!(users(:two))
      assert_equal @room.memberships.find_by!(user: users(:one)), @room.add_member!(users(:one))
    end
  end

  test "removes a member and tolerates repeated removal" do
    @room.add_member!(users(:two))
    assert_difference "Membership.count", -1 do
      @room.remove_member!(users(:two))
    end
    assert_nil @room.remove_member!(users(:two))
  end

  test "cannot remove the owner" do
    assert_no_difference "Membership.count" do
      assert_raises(Room::OwnerRemovalError) { @room.remove_member!(users(:one)) }
    end
    assert_includes @room.members, users(:one)
  end

  test "destroying a room removes its memberships" do
    @room.add_member!(users(:two))
    assert_difference "Membership.count", -2 do
      @room.destroy!
    end
    assert User.exists?(users(:one).id)
  end
end
