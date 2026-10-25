class RoomInvitationsController < ApplicationController
  before_action :set_room

  def show
    redirect_to @room if @room.members.exists?(Current.user.id)
  end

  def create
    @room.add_member!(Current.user)
    redirect_to @room, notice: "Вы вступили в комнату.", status: :see_other
  end

  private

  def set_room
    @room = Room.find_signed(params[:token], purpose: :room_invitation)
    raise ActiveRecord::RecordNotFound unless @room
  end
end
