class FavoritesController < ApplicationController

  def index
    favorites = Favorite.all
    render json: favorites 
  end 

  def destroy 
    favorite = Favorite.find(params[:id])
    favorite.destroy 
    render json: {message: "Favorite successfully destroyed"}
  end 


end
