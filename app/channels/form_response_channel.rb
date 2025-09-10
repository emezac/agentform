# app/channels/form_response_channel.rb
class FormResponseChannel < ApplicationCable::Channel
  def subscribed
    form_response_id = params[:form_response_id]
    
    if form_response_id.present?
      # Find the form response to verify access
      form_response = FormResponse.find_by(id: form_response_id)
      
      if form_response
        stream_from "form_response_#{form_response_id}"
        Rails.logger.info "FormResponseChannel: Subscribed to form_response_#{form_response_id}"
      else
        Rails.logger.error "FormResponseChannel: FormResponse not found: #{form_response_id}"
        reject
      end
    else
      Rails.logger.error "FormResponseChannel: No form_response_id provided"
      reject
    end
  end

  def unsubscribed
    Rails.logger.info "FormResponseChannel: Unsubscribed"
  end
end