class GroupWatchlistItemsController < ApplicationController
  before_action :authenticate_user

  def destroy
    group = Group.find_by(id: params[:group_id])
    return render json: { error: "Not found" }, status: :not_found unless group&.members&.exists?(id: current_user.id)

    item = group.group_watchlist_items.find_by(id: params[:id])
    return render json: { error: "Not found" }, status: :not_found unless item

    item.destroy
    render json: { message: "Removed from watchlist" }
  end
end
