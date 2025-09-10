require 'rails_helper'

RSpec.describe "Templates", type: :request do
  let(:user) { create(:user) }
  let(:template) { create(:form_template, :public) }

  describe "GET /templates" do
    let!(:public_template1) { create(:form_template, name: "Customer Survey", visibility: "template_public") }
    let!(:public_template2) { create(:form_template, name: "Lead Qualification", visibility: "template_public") }
    let!(:private_template) { create(:form_template, name: "Private Template", visibility: "template_private") }

    context "when user is authenticated" do
      before { sign_in user }

      it "returns http success" do
        get templates_path
        expect(response).to have_http_status(:success)
      end

      it "shows only public templates" do
        get templates_path
        expect(response.body).to include("Customer Survey")
        expect(response.body).to include("Lead Qualification")
        expect(response.body).not_to include("Private Template")
      end

      it "displays template cards with correct information" do
        get templates_path
        expect(response.body).to include(public_template1.description)
        expect(response.body).to include(public_template1.category.humanize)
      end
    end

    context "when user is not authenticated" do
      it "redirects to login page" do
        get templates_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe "POST /templates/:id/instantiate" do
    let(:template) { create(:form_template, :customer_feedback) }

    context "when user is authenticated" do
      before { sign_in user }

      it "creates a new form from template" do
        expect {
          post instantiate_template_path(template)
        }.to change(Form, :count).by(1)
          .and change(FormQuestion, :count).by(2)
      end

      it "redirects to form edit page" do
        post instantiate_template_path(template)
        new_form = Form.last
        expect(response).to redirect_to(edit_form_path(new_form))
      end

      it "shows success notice" do
        post instantiate_template_path(template)
        follow_redirect!
        expect(response.body).to include("Formulario creado desde la plantilla")
      end

      it "increments template usage count" do
        expect {
          post instantiate_template_path(template)
          template.reload
        }.to change(template, :usage_count).by(1)
      end

      it "sets correct form attributes" do
        post instantiate_template_path(template)
        new_form = Form.last
        
        expect(new_form.name).to eq(template.name)
        expect(new_form.description).to eq(template.description)
        expect(new_form.user).to eq(user)
        expect(new_form.template_id).to eq(template.id)
      end
    end

    context "when user is not authenticated" do
      it "redirects to login page" do
        post instantiate_template_path(template)
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end
end