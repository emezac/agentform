# frozen_string_literal: true

class BillingsController < ApplicationController
  # Important! We skip our new check here to avoid a redirect loop.
  skip_before_action :check_trial_status, only: [:show, :create]

  # Shows the plans page for a user with expired trial.
  def show
    # Here you can load your plan details to display in the view.
  end

  # Creates a new checkout session so an existing user can subscribe.
  def create
    plan = params[:plan] # 'basic' o 'professional'
    price_id = case plan
               when 'basic'
                 Rails.application.credentials.stripe[:basic_plan_price_id] # You'll need to add this
               when 'professional'
                 Rails.application.credentials.stripe[:professional_plan_price_id] # You already have this as 'premium_plan_price_id'
               else
                 flash[:alert] = "Invalid plan."
                 return redirect_to billing_path
               end

    checkout_session = Stripe::Checkout::Session.create({
      customer: current_user.stripe_customer_id, # Use the customer_id if it already exists
      payment_method_types: ['card'],
      line_items: [{ price: price_id, quantity: 1 }],
      mode: 'subscription',
      success_url: root_url, # Redirect to dashboard after successful payment
      cancel_url: billing_url,
      metadata: {
        user_id: current_user.id
      }
    })
    
    redirect_to checkout_session.url, allow_other_host: true, status: :see_other
  rescue Stripe::StripeError => e
    flash[:alert] = "There was an error with the payment: #{e.message}"
    redirect_to billing_path
  end
end