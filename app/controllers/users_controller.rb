class UsersController < ApplicationController

  def create
    user = User.new(
      name: params[:name],
      email: params[:email],
      password: params[:password],
      password_confirmation: params[:password_confirmation]
    )
    if user.save
      render json: {message: "User succesfully created"}, status: :created
    else 
      render json: {errors: user.errors.full_messages }, status: :bad_request
  end 



  def show
    user = User.find(params[:id])
    render json: user
  end 


  def update
    user = User.find(params[:id])
    user.name = params[:name] || user.name
    user.email = params[:email] || user.email
    user.username = params[:username] || user.username
    user.image_url = params[:image_url] || user.image_url
    user.password = params[:password] || user.password
    user.password_confirmation = params[:password_confirmation] || user.password_confirmation
    if user.save
      render json: user
    else 
      render json: {errors: user.errors.full_messages }, status: :unprocessable_entity
  end 



  def destroy
    user = User.find(params[:id])
    user.destroy
    render json: {message: "User destroyed"}
  end 


end