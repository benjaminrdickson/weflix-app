class UsersController < ApplicationController

  before_action :authenticate_user, except: [:create, :show]
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
    render json: {
      id: user.id,
      name: user.name,
      username: user.username,
      email: user.email,
      image_url: user.profile_picture.attached? ? url_for(user.profile_picture) : user.image_url,
      relationship: rel ? {
        id: rel.id,
        confirmed: rel.confirmation,
        is_sender: rel.sender_id == user.id,
        partner: user.partner ? {
          id: user.partner.id,
          name: user.partner.name,
          username: user.partner.username,
          image_url: user.partner.image_url
        } : nil
      } : nil
    }
  end


  def update
    user = User.find(params[:id])
    if current_user.id == user.id
      if params[:password] && params[:password_confirmation]
        user.password = params[:password]
        user.password_confirmation = params[:password_confirmation]
      end 
      user.name = params[:name] || user.name
      user.email = params[:email] || user.email
      user.username = params[:username] || user.username
      user.image_url = params[:image_url] || user.image_url
      if user.save
        render json: user
      else 
        render json: {errors: user.errors.full_messages }, status: :unprocessable_entity
      end 
    end 
  end 



  def destroy
    user = User.find_by(username: params[:username])
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
      render json: { image_url: url_for(user.profile_picture) }
    else
      render json: { error: "Upload failed" }, status: :unprocessable_entity
    end
  end




end
