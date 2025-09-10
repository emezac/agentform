require 'rails_helper'

RSpec.describe FormQuestionsController, type: :controller do
  let(:freemium_user) { create(:user, subscription_tier: 'freemium') }
  let(:premium_user) { create(:user, subscription_tier: 'premium') }
  let(:form) { create(:form, user: freemium_user) }
  let(:premium_form) { create(:form, user: premium_user) }

  describe 'Payment question restrictions' do
    context 'freemium user' do
      before { sign_in freemium_user }

      describe 'POST #create' do
        it 'prevents creating payment questions' do
          post :create, params: {
            form_id: form.id,
            form_question: {
              title: 'Payment Question',
              question_type: 'payment',
              required: true
            }
          }

          expect(response).to redirect_to(edit_form_path(form))
          expect(flash[:alert]).to include('Payment questions are only available for Premium users')
        end

        it 'allows creating non-payment questions' do
          post :create, params: {
            form_id: form.id,
            form_question: {
              title: 'Text Question',
              question_type: 'text_short',
              required: true
            }
          }

          expect(response).to redirect_to(edit_form_path(form))
          expect(flash[:notice]).to include('Question was successfully created')
        end
      end

      describe 'PATCH #update' do
        let(:question) { create(:form_question, form: form, question_type: 'text_short') }

        it 'prevents updating to payment question type' do
          patch :update, params: {
            form_id: form.id,
            id: question.id,
            form_question: {
              question_type: 'payment'
            }
          }

          expect(response).to redirect_to(edit_form_path(form))
          expect(flash[:alert]).to include('Payment questions are only available for Premium users')
        end

        it 'allows updating non-payment questions' do
          patch :update, params: {
            form_id: form.id,
            id: question.id,
            form_question: {
              title: 'Updated Title'
            }
          }

          expect(response).to redirect_to(edit_form_path(form))
          expect(flash[:notice]).to include('Question was successfully updated')
        end
      end
    end

    context 'premium user' do
      before { sign_in premium_user }

      describe 'POST #create' do
        it 'allows creating payment questions' do
          post :create, params: {
            form_id: premium_form.id,
            form_question: {
              title: 'Payment Question',
              question_type: 'payment',
              required: true
            }
          }

          expect(response).to redirect_to(edit_form_path(premium_form))
          expect(flash[:notice]).to include('Question was successfully created')
        end
      end

      describe 'PATCH #update' do
        let(:question) { create(:form_question, form: premium_form, question_type: 'text_short') }

        it 'allows updating to payment question type' do
          patch :update, params: {
            form_id: premium_form.id,
            id: question.id,
            form_question: {
              question_type: 'payment'
            }
          }

          expect(response).to redirect_to(edit_form_path(premium_form))
          expect(flash[:notice]).to include('Question was successfully updated')
        end
      end
    end
  end

  describe 'JSON responses' do
    context 'freemium user' do
      before { sign_in freemium_user }

      it 'returns forbidden status for payment questions via JSON' do
        post :create, params: {
          form_id: form.id,
          form_question: {
            title: 'Payment Question',
            question_type: 'payment',
            required: true
          }
        }, format: :json

        expect(response).to have_http_status(:forbidden)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to include('Payment questions require Premium subscription')
        expect(json_response['upgrade_required']).to be true
      end
    end
  end
end