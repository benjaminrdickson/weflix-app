class RelationshipsController < ApplicationController

  


  def destroy 
    relationship = Relationship.find(params[:id])
    relationship.destroy 
    render json: {message: "Relationship successfully destroyed"}
  end 



end
