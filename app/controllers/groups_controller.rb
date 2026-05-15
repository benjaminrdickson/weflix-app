class GroupsController < ApplicationController
  before_action :authenticate_user

  def index
    groups = current_user.groups.includes(:creator, :group_memberships, :group_watchlist_items)
    render json: groups.map { |g| group_summary_json(g) }
  end

  def create
    group = Group.new(name: params[:name], creator: current_user)
    if group.save
      group.group_memberships.create!(user: current_user)
      render json: group_summary_json(group), status: :created
    else
      render json: { errors: group.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def show
    group = find_member_group
    return unless group

    region = params[:region].presence || "US"
    members = group.members.includes(profile_picture_attachment: :blob)
    watchlist = group.group_watchlist_items.map { |item| item.tmdb_details(region).merge(watchlist_item_id: item.id) }

    pending_invitations = group.creator_id == current_user.id ?
      group.group_invitations.where(status: %w[pending accepted]).includes(:invitee) : []

    render json: {
      id:                  group.id,
      name:                group.name,
      creator_id:          group.creator_id,
      is_creator:          group.creator_id == current_user.id,
      members:             members.map { |m| user_json(m) },
      pending_invitations: pending_invitations.map { |inv|
        { invitation_id: inv.id, invitee: user_json(inv.invitee), status: inv.status }
      },
      watchlist:           watchlist
    }
  end

  def update
    group = Group.find(params[:id])
    return render json: { error: "Unauthorized" }, status: :unauthorized unless group.creator_id == current_user.id
    if group.update(name: params[:name])
      render json: group_summary_json(group)
    else
      render json: { errors: group.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    group = Group.find(params[:id])
    return render json: { error: "Unauthorized" }, status: :unauthorized unless group.creator_id == current_user.id
    group.destroy
    render json: { message: "Group deleted" }
  end

  private

  def find_member_group
    group = Group.find_by(id: params[:id])
    unless group && group.members.exists?(id: current_user.id)
      render json: { error: "Not found" }, status: :not_found
      return nil
    end
    group
  end

  def group_summary_json(group)
    {
      id:            group.id,
      name:          group.name,
      creator_id:    group.creator_id,
      is_creator:    group.creator_id == current_user.id,
      member_count:  group.group_memberships.size,
      matched_count: group.group_watchlist_items.size
    }
  end

  def user_json(user)
    {
      id:        user.id,
      name:      user.name,
      username:  user.username,
      image_url: user.profile_picture.attached? ? user.profile_picture.blob.url : user.image_url
    }
  end
end
