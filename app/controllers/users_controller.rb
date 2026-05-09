class UsersController < ApplicationController

  before_action :authenticate_user, except: [:create, :show]


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
    user = User.find_by({username: params[:username]})
    render json: user
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




end
