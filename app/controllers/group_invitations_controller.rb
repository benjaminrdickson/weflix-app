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
    return render json: { error: "Invitation already sent" }, status: :unprocessable_entity if invitation.persisted? && invitation.status == "pending"

    invitation.status = "pending"
    invitation.inviter = current_user
    if invitation.save
      NotificationService.deliver(
        users:   invitee,
        type:    "group_invitation",
        message: "#{current_user.name} invited you to join #{group.name}",
        context: { group_id: group.id, invitation_id: invitation.id }.to_json
      )
      render json: { invitation_id: invitation.id }, status: :created
    else
      render json: { errors: invitation.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    group = Group.find_by(id: params[:group_id])
    return render json: { error: "Not found" }, status: :not_found unless group

    invitation = group.group_invitations.find_by(id: params[:invitation_id])
    return render json: { error: "Not found" }, status: :not_found unless invitation

    if current_user.id == invitation.invitee_id
      handle_invitee_response(group, invitation)
    elsif current_user.id == group.creator_id
      handle_creator_response(group, invitation)
    else
      render json: { error: "Unauthorized" }, status: :unauthorized
    end
  end

  private

  def handle_invitee_response(group, invitation)
    return render json: { error: "Invitation is no longer pending" }, status: :unprocessable_entity unless invitation.status == "pending"

    if params[:accepted].to_s == "true"
      if invitation.inviter_id == group.creator_id
        invitation.status = "approved"
        if invitation.save
          group.group_memberships.create!(user: invitation.invitee)
          render json: { invitation_id: invitation.id, status: invitation.status }
        else
          render json: { errors: invitation.errors.full_messages }, status: :unprocessable_entity
        end
      else
        invitation.status = "accepted"
        if invitation.save
          creator = User.find_by(id: group.creator_id)
          if creator
            NotificationService.deliver(
              users:   creator,
              type:    "group_join_request",
              message: "#{invitation.invitee.name} accepted an invitation to #{group.name} — awaiting your approval",
              context: "group_#{group.id}"
            )
          end
          render json: { invitation_id: invitation.id, status: invitation.status }
        else
          render json: { errors: invitation.errors.full_messages }, status: :unprocessable_entity
        end
      end
    else
      invitation.status = "declined"
      if invitation.save
        render json: { invitation_id: invitation.id, status: invitation.status }
      else
        render json: { errors: invitation.errors.full_messages }, status: :unprocessable_entity
      end
    end
  end

  def handle_creator_response(group, invitation)
    return render json: { error: "Not awaiting approval" }, status: :unprocessable_entity unless invitation.status == "accepted"

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
      else
        NotificationService.deliver(
          users:   invitation.invitee,
          type:    "group_invitation",
          message: "Your request to join #{group.name} was not approved."
        )
      end
      render json: { invitation_id: invitation.id, status: invitation.status }
    else
      render json: { errors: invitation.errors.full_messages }, status: :unprocessable_entity
    end
  end
end
