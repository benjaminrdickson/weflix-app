class PushTokensController < ApplicationController
  before_action :authenticate_user

  def upsert
    token    = params[:token].to_s.strip
    platform = params[:platform].to_s.strip
    return render json: { error: "Invalid token" }, status: :unprocessable_entity if token.blank?

    push_token = PushToken.find_or_initialize_by(user: current_user)
    push_token.assign_attributes(token: token, platform: platform)

    if push_token.save
      render json: { message: "Token registered" }, status: :ok
    else
      render json: { errors: push_token.errors.full_messages }, status: :unprocessable_entity
    end
  end
end
