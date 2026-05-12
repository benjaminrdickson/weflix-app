class GroupInvitationsController < ApplicationController
  before_action :authenticate_user

  def create
    group = Group.find_by(id: params[:group_id])
    return render json: { error: "Not found" }, status: :not_found unless group&.members&.exists?(id: current_user.id)

    invitee = User.find_by(id: params[:invitee_id])
    return render json: { error: "User not found" }, status: :not_found unless invitee

    friendship = Friendship.find_by(sender_id: current_user.id, recipient_id: invitee.id) ||
                 Friendship.find_by(sender_id: invitee.id, recipient_id: current_user.id)
    return render json: { error: "You can only invite friends" }, status: :forbidden unless friendship&.confirmed

    return render json: { error: "User is already a member" }, status: :unprocessable_entity if group.members.exists?(id: invitee.id)

    invitation = group.group_invitations.find_or_initialize_by(invitee: invitee)
    return render json: { error: "Invitation already sent" }, status: :unprocessable_entity if invitation.persisted?

    invitation.inviter = current_user
    if invitation.save
      NotificationService.deliver(
        users:   invitee,
        type:    "group_invitation",
        message: "#{current_user.name} invited you to join #{group.name}"
      )
      creator = User.find_by(id: group.creator_id)
      if creator && creator.id != current_user.id
        NotificationService.deliver(
          users:   creator,
          type:    "group_join_request",
          message: "#{current_user.name} invited #{invitee.name} to #{group.name} — awaiting your approval"
        )
      end
      render json: { invitation_id: invitation.id }, status: :created
    else
      render json: { errors: invitation.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    group = Group.find_by(id: params[:group_id])
    return render json: { error: "Unauthorized" }, status: :unauthorized unless group&.creator_id == current_user.id

    invitation = group.group_invitations.find_by(id: params[:invitation_id])
    return render json: { error: "Not found" }, status: :not_found unless invitation

    approved = params[:approved].to_s == "true"
    invitation.status = approved ? "approved" : "rejected"

    if invitation.save
      if approved
        group.group_memberships.create!(user: invitation.invitee)
        NotificationService.deliver(
          users:   invitation.invitee,
          type:    "group_invitation_approved",
          message: "Your invitation to #{group.name} was approved — welcome to the group!"
        )
      end
      render json: { invitation_id: invitation.id, status: invitation.status }
    else
      render json: { errors: invitation.errors.full_messages }, status: :unprocessable_entity
    end
  end
end
