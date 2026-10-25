class ProfilesController < ApplicationController
  def show
    @user = Current.user
    @ratings_count = @user.ratings.count
    @average_rating = @user.ratings.average(:score)
    @recent_ratings = @user.ratings.includes(:movie).order(updated_at: :desc, id: :desc).limit(3)
    @rooms_count = @user.rooms.count
    @recent_rooms = @user.rooms.order(created_at: :desc, id: :desc).limit(3)
  end
end
