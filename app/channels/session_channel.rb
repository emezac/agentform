# app/channels/session_channel.rb
class SessionChannel < ApplicationCable::Channel
  def subscribed
    session_id = connection.current_session_id
    if session_id.present?
      stream_from "session_#{session_id}"
      
      # Also subscribe to form response updates if we have one
      form_response = FormResponse.find_by(session_id: session_id)
      if form_response
        stream_from "form_response_#{form_response.id}"
      end
      
      Rails.logger.info "SessionChannel subscribed to session_#{session_id}"
    else
      reject
    end
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
  end
end