class UsersController < ApplicationController

  before_action :authenticate_user, except: [:create]
  include Rails.application.routes.url_helpers


  # def index
  #   user = User.all
  #   render json: user
  # end 


  def create
    user = User.new(
      name: params[:name],
      email: params[:email],
      username: params[:username],
      image_url: params[:image_url],
      password: params[:password],
      password_confirmation: params[:password_confirmation]
    )
    if user.save
      render json: user
    else 
      render json: {errors: user.errors.full_messages }, status: :bad_request
    end 
  end 


  # def username
  #   user = User.find_by(params[:username])
  #   render json: user
  # end



  def show
    user = User.find_by(username: params[:username])
    return render json: { error: "User not found" }, status: :not_found unless user

    rel = user.relationship
    partner = rel ? user.partner : nil
    render json: {
      id: user.id,
      name: user.name,
      username: user.username,
      email: user.email,
      image_url: user.profile_picture.attached? ? user.profile_picture.blob.url : user.image_url,
      is_group_creator: user.created_groups.any?,
      relationship: rel ? {
        id: rel.id,
        confirmed: rel.confirmation,
        is_sender: rel.sender_id == user.id,
        partner: partner ? {
          id: partner.id,
          name: partner.name,
          username: partner.username,
          image_url: partner.profile_picture.attached? ? partner.profile_picture.blob.url : partner.image_url
        } : nil
      } : nil
    }
  end


  def update
    user = User.find(params[:id])
    return render json: { error: "Unauthorized" }, status: :unauthorized unless current_user.id == user.id
    if params[:password] && params[:password_confirmation]
      user.password = params[:password]
      user.password_confirmation = params[:password_confirmation]
    end
    user.name = params[:name] || user.name
    user.email = params[:email] || user.email
    user.username = params[:username] || user.username
    if user.save
      render json: user
    else
      render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
    end
  end 



  def destroy
    user = User.find_by(username: params[:username])
    return render json: { error: "Unauthorized" }, status: :unauthorized unless current_user == user
    user.relationship&.destroy
    user.destroy
    render json: {message: "User destroyed"}
  end

  def upload_profile_picture
    user = User.find(params[:id])
    unless current_user.id == user.id
      render json: { error: "Unauthorized" }, status: :unauthorized
      return
    end
    user.profile_picture.attach(params[:profile_picture])
    if user.profile_picture.attached?
      render json: { image_url: user.profile_picture.blob.url }
    else
      render json: { error: "Upload failed" }, status: :unprocessable_entity
    end
  end




end
