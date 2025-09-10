# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ApplicationController, type: :controller do
  describe 'basic functionality' do
    it 'includes Pundit::Authorization' do
      expect(ApplicationController.ancestors).to include(Pundit::Authorization)
    end

    it 'has authentication before_action' do
      expect(ApplicationController._process_action_callbacks.map(&:filter)).to include(:authenticate_user!)
    end

    it 'has set_current_user before_action' do
      expect(ApplicationController._process_action_callbacks.map(&:filter)).to include(:set_current_user)
    end

    it 'has CSRF protection enabled' do
      expect(ApplicationController.forgery_protection_strategy).to eq(ActionController::RequestForgeryProtection::ProtectionMethods::Exception)
    end
  end

  describe 'error handling' do
    it 'has rescue handlers defined' do
      rescue_handlers = ApplicationController.rescue_handlers
      handler_classes = rescue_handlers.map { |handler| handler.first.to_s }
      
      expect(handler_classes).to include(
        'ActiveRecord::RecordNotFound',
        'Pundit::NotAuthorizedError',
        'ActionController::ParameterMissing',
        'ActiveRecord::RecordInvalid'
      )
    end
  end

  describe 'helper methods' do
    let(:controller) { ApplicationController.new }

    describe '#skip_authorization?' do
      it 'returns true for devise controllers' do
        allow(controller).to receive(:devise_controller?).and_return(true)
        expect(controller.send(:skip_authorization?)).to be true
      end

      it 'returns true for home controller' do
        allow(controller).to receive(:controller_name).and_return('home')
        expect(controller.send(:skip_authorization?)).to be true
      end

      it 'returns true for health controller' do
        allow(controller).to receive(:controller_name).and_return('health')
        expect(controller.send(:skip_authorization?)).to be true
      end

      it 'returns true for public_form action' do
        allow(controller).to receive(:action_name).and_return('public_form')
        expect(controller.send(:skip_authorization?)).to be true
      end
    end
  end
end