# frozen_string_literal: true

class StripeWebhooksController < ApplicationController
  skip_before_action :authenticate_user!, raise: false
  skip_before_action :verify_authenticity_token, raise: false

  def create
    # La gema stripe_event maneja la verificación y llama al servicio
    # configurado en el inicializador.
    StripeEvent.instrument(params.to_unsafe_h)
    head :ok
  rescue Stripe::SignatureVerificationError => e
    render json: { error: "Firma de Webhook inválida" }, status: 400
  end
end
