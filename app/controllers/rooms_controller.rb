class RoomsController < ApplicationController
  def index
  end

  def new
  end

  def show
    @selection_path = params[:id].present? ? selection_room_path(params[:id]) : current_room_selection_path
  end

  def selection
    @room_path = params[:id].present? ? room_path(params[:id]) : current_room_path
  end
end
