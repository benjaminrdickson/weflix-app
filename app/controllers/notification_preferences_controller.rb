class NotificationPreferencesController < ApplicationController
  before_action :authenticate_user

  def show
    prefs = NotificationPreference.for(current_user)
    render json: serialize(prefs)
  end

  def update
    prefs = current_user.notification_preference ||
            current_user.build_notification_preference
    allowed = NotificationPreference::PREFERENCE_COLUMNS
    updates = params.permit(*allowed).to_h.slice(*allowed)
    if prefs.update(updates)
      render json: serialize(prefs)
    else
      render json: { errors: prefs.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def serialize(prefs)
    NotificationPreference::PREFERENCE_COLUMNS.each_with_object({}) do |col, h|
      h[col] = prefs.public_send(col).nil? ? true : prefs.public_send(col)
    end
  end
end
