class RelationshipsController < ApplicationController

   
  # write method where if user requests a relationship, a relationship_id is created for that user, and a sender_id is created for that user, and a recipient_id is created for the user that is getting the request. Once the recipient has confirmed the relationship, both users are saved to that relationship_id. If the recipient denies the request, the relationship_id, sender_id, and recipient_id are all destroyed. 

  def create
    relationship = Relationship.new(
      sender_id: current_user.id,
      recipient_id: params[:recipient_id]
    )
    if relationship.save
      render json: relationship
    else
      render json: { errors: relationship.errors.full_messages }, status: :unprocessable_entity
    end
  end

  

  def update
    # User may only change the confirmed status, and only of the friendship request they are a recipient
    relationship = Relationship.find(params[:id])
    if relationship.recipient == current_user
      relationship.confirmed = params[:confirmed] || relationship.confirmed
      if relationship.save
        render json: relationship
      else
        render json: {errors: relationship.errors.full_messages }, status: :unprocessable_entity
      end
    else
      render json: {}, status: 401
    end
  end

    

   


  def destroy 
    relationship = Relationship.find(params[:id])
    relationship.destroy 
    render json: {message: "Relationship successfully destroyed"}
  end 



end
