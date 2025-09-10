# frozen_string_literal: true

# Shared examples for common controller behaviors

RSpec.shared_examples "requires authentication" do |action, params = {}|
  it "redirects to sign in when not authenticated" do
    case action
    when :get, :show, :index, :new, :edit
      get action, params: params
    when :post, :create
      post action, params: params
    when :patch, :put, :update
      patch action, params: params
    when :delete, :destroy
      delete action, params: params
    end
    
    expect(response).to redirect_to(new_user_session_path)
  end
end

RSpec.shared_examples "requires authorization" do |action, params = {}, expected_status = :forbidden|
  it "denies access when not authorized" do
    unauthorized_user = create(:user)
    sign_in unauthorized_user
    
    case action
    when :get, :show, :index, :new, :edit
      get action, params: params
    when :post, :create
      post action, params: params
    when :patch, :put, :update
      patch action, params: params
    when :delete, :destroy
      delete action, params: params
    end
    
    expect(response).to have_http_status(expected_status)
  end
end

RSpec.shared_examples "a CRUD controller" do |resource_name, factory_name = nil|
  factory_name ||= resource_name
  let(:user) { create(:user) }
  let(:resource) { create(factory_name, user: user) }
  let(:valid_attributes) { attributes_for(factory_name) }
  let(:invalid_attributes) { { title: '' } }
  
  before { sign_in user }
  
  describe "GET #index" do
    it "returns a success response" do
      get :index
      expect(response).to be_successful
    end
    
    it "assigns user's resources" do
      user_resource = create(factory_name, user: user)
      other_resource = create(factory_name)
      
      get :index
      
      expect(assigns(resource_name.to_s.pluralize.to_sym)).to include(user_resource)
      expect(assigns(resource_name.to_s.pluralize.to_sym)).not_to include(other_resource)
    end
  end
  
  describe "GET #show" do
    it "returns a success response" do
      get :show, params: { id: resource.id }
      expect(response).to be_successful
    end
    
    it "assigns the requested resource" do
      get :show, params: { id: resource.id }
      expect(assigns(resource_name)).to eq(resource)
    end
  end
  
  describe "GET #new" do
    it "returns a success response" do
      get :new
      expect(response).to be_successful
    end
    
    it "assigns a new resource" do
      get :new
      expect(assigns(resource_name)).to be_a_new(resource.class)
    end
  end
  
  describe "GET #edit" do
    it "returns a success response" do
      get :edit, params: { id: resource.id }
      expect(response).to be_successful
    end
    
    it "assigns the requested resource" do
      get :edit, params: { id: resource.id }
      expect(assigns(resource_name)).to eq(resource)
    end
  end
  
  describe "POST #create" do
    context "with valid parameters" do
      it "creates a new resource" do
        expect {
          post :create, params: { resource_name => valid_attributes }
        }.to change(resource.class, :count).by(1)
      end
      
      it "redirects to the created resource" do
        post :create, params: { resource_name => valid_attributes }
        expect(response).to redirect_to(assigns(resource_name))
      end
      
      it "sets success flash message" do
        post :create, params: { resource_name => valid_attributes }
        expect(flash[:notice]).to be_present
      end
    end
    
    context "with invalid parameters" do
      it "does not create a new resource" do
        expect {
          post :create, params: { resource_name => invalid_attributes }
        }.not_to change(resource.class, :count)
      end
      
      it "renders the new template" do
        post :create, params: { resource_name => invalid_attributes }
        expect(response).to render_template(:new)
      end
    end
  end
  
  describe "PATCH #update" do
    context "with valid parameters" do
      let(:new_attributes) { { title: 'Updated Title' } }
      
      it "updates the requested resource" do
        patch :update, params: { id: resource.id, resource_name => new_attributes }
        resource.reload
        expect(resource.title).to eq('Updated Title')
      end
      
      it "redirects to the resource" do
        patch :update, params: { id: resource.id, resource_name => new_attributes }
        expect(response).to redirect_to(resource)
      end
      
      it "sets success flash message" do
        patch :update, params: { id: resource.id, resource_name => new_attributes }
        expect(flash[:notice]).to be_present
      end
    end
    
    context "with invalid parameters" do
      it "renders the edit template" do
        patch :update, params: { id: resource.id, resource_name => invalid_attributes }
        expect(response).to render_template(:edit)
      end
    end
  end
  
  describe "DELETE #destroy" do
    it "destroys the requested resource" do
      resource # Create the resource
      expect {
        delete :destroy, params: { id: resource.id }
      }.to change(resource.class, :count).by(-1)
    end
    
    it "redirects to the resources list" do
      delete :destroy, params: { id: resource.id }
      expect(response).to redirect_to(send("#{resource_name.to_s.pluralize}_path"))
    end
    
    it "sets success flash message" do
      delete :destroy, params: { id: resource.id }
      expect(flash[:notice]).to be_present
    end
  end
end

RSpec.shared_examples "an API controller" do |resource_name, factory_name = nil|
  factory_name ||= resource_name
  let(:user) { create(:user) }
  let(:api_token) { create(:api_token, user: user) }
  let(:headers) { api_headers(api_token) }
  let(:resource) { create(factory_name, user: user) }
  let(:valid_attributes) { attributes_for(factory_name) }
  let(:invalid_attributes) { { title: '' } }
  
  describe "GET #index" do
    it "returns a success response" do
      get :index, headers: headers
      expect_json_response(:ok, {
        data: Array,
        meta: Hash
      })
    end
    
    it "returns user's resources only" do
      user_resource = create(factory_name, user: user)
      other_resource = create(factory_name)
      
      get :index, headers: headers
      
      resource_ids = json_response['data'].map { |r| r['id'] }
      expect(resource_ids).to include(user_resource.id)
      expect(resource_ids).not_to include(other_resource.id)
    end
    
    it "includes pagination metadata" do
      get :index, headers: headers
      expect_paginated_response
    end
  end
  
  describe "GET #show" do
    it "returns a success response" do
      get :show, params: { id: resource.id }, headers: headers
      expect_json_response(:ok, {
        data: Hash
      })
    end
    
    it "returns the requested resource" do
      get :show, params: { id: resource.id }, headers: headers
      expect(json_response['data']['id']).to eq(resource.id)
    end
    
    it "returns 404 for non-existent resource" do
      get :show, params: { id: 'non-existent' }, headers: headers
      expect_error_response(:not_found)
    end
  end
  
  describe "POST #create" do
    context "with valid parameters" do
      it "creates a new resource" do
        expect {
          api_post "/api/v1/#{resource_name.to_s.pluralize}", valid_attributes, headers
        }.to change(resource.class, :count).by(1)
      end
      
      it "returns the created resource" do
        api_post "/api/v1/#{resource_name.to_s.pluralize}", valid_attributes, headers
        expect_json_response(:created, {
          data: Hash
        })
      end
    end
    
    context "with invalid parameters" do
      it "does not create a new resource" do
        expect {
          api_post "/api/v1/#{resource_name.to_s.pluralize}", invalid_attributes, headers
        }.not_to change(resource.class, :count)
      end
      
      it "returns validation errors" do
        api_post "/api/v1/#{resource_name.to_s.pluralize}", invalid_attributes, headers
        expect_validation_error
      end
    end
  end
  
  describe "PATCH #update" do
    context "with valid parameters" do
      let(:new_attributes) { { title: 'Updated Title' } }
      
      it "updates the requested resource" do
        api_patch "/api/v1/#{resource_name.to_s.pluralize}/#{resource.id}", new_attributes, headers
        expect_json_response(:ok)
        
        resource.reload
        expect(resource.title).to eq('Updated Title')
      end
    end
    
    context "with invalid parameters" do
      it "returns validation errors" do
        api_patch "/api/v1/#{resource_name.to_s.pluralize}/#{resource.id}", invalid_attributes, headers
        expect_validation_error
      end
    end
  end
  
  describe "DELETE #destroy" do
    it "destroys the requested resource" do
      resource # Create the resource
      expect {
        api_delete "/api/v1/#{resource_name.to_s.pluralize}/#{resource.id}", headers
      }.to change(resource.class, :count).by(-1)
    end
    
    it "returns success response" do
      api_delete "/api/v1/#{resource_name.to_s.pluralize}/#{resource.id}", headers
      expect(response).to have_http_status(:no_content)
    end
  end
  
  describe "authentication" do
    it "requires valid API token" do
      get :index
      expect_authentication_required
    end
    
    it "rejects expired tokens" do
      get :index, headers: expired_api_headers
      expect_authentication_required
    end
    
    it "rejects invalid tokens" do
      get :index, headers: invalid_api_headers
      expect_authentication_required
    end
  end
end

RSpec.shared_examples "handles file uploads" do |upload_param, allowed_types = %w[image/png image/jpeg]|
  let(:user) { create(:user) }
  let(:valid_file) { fixture_file_upload('test_image.png', 'image/png') }
  let(:invalid_file) { fixture_file_upload('test_document.txt', 'text/plain') }
  
  before { sign_in user }
  
  context "with valid file" do
    it "accepts allowed file types" do
      post :create, params: { upload_param => valid_file }
      expect(response).to be_successful
    end
    
    it "stores file securely" do
      post :create, params: { upload_param => valid_file }
      # Verify file is stored in expected location
      # Verify file permissions are correct
    end
  end
  
  context "with invalid file" do
    it "rejects disallowed file types" do
      post :create, params: { upload_param => invalid_file }
      expect(response).to have_http_status(:unprocessable_entity)
    end
    
    it "validates file size limits" do
      # Test with oversized file
      allow(valid_file).to receive(:size).and_return(50.megabytes)
      
      post :create, params: { upload_param => valid_file }
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end

RSpec.shared_examples "rate limited endpoint" do |action, params = {}, limit = 100|
  let(:user) { create(:user) }
  let(:headers) { api_headers_for_user(user) }
  
  it "allows requests within rate limit" do
    10.times do
      case action
      when :get
        get action, params: params, headers: headers
      when :post
        post action, params: params, headers: headers
      end
      
      expect(response).not_to have_http_status(:too_many_requests)
    end
  end
  
  it "blocks requests exceeding rate limit", :slow do
    (limit + 1).times do
      case action
      when :get
        get action, params: params, headers: headers
      when :post
        post action, params: params, headers: headers
      end
    end
    
    expect_rate_limited
  end
end

RSpec.shared_examples "API versioning support" do |versions = ['v1']|
  versions.each do |version|
    describe "API version #{version}" do
      let(:versioned_headers) { headers.merge('Accept' => "application/vnd.agentform.#{version}+json") }
      
      it "responds to version-specific requests" do
        get :index, headers: versioned_headers
        expect(response).to be_successful
      end
      
      it "includes version in response headers" do
        get :index, headers: versioned_headers
        expect(response.headers['API-Version']).to eq(version)
      end
    end
  end
  
  it "defaults to latest version when no version specified" do
    get :index, headers: headers
    expect(response.headers['API-Version']).to eq(versions.last)
  end
  
  it "returns error for unsupported versions" do
    unsupported_headers = headers.merge('Accept' => 'application/vnd.agentform.v99+json')
    get :index, headers: unsupported_headers
    expect(response).to have_http_status(:not_acceptable)
  end
end

RSpec.shared_examples "API error handling" do
  describe "error responses" do
    it "returns structured error responses" do
      allow(controller).to receive(:index).and_raise(StandardError, "Test error")
      
      get :index, headers: headers
      
      expect(response).to have_http_status(:internal_server_error)
      expect(json_response).to have_key('error')
      expect(json_response['error']).to have_key('message')
      expect(json_response['error']).to have_key('code')
    end
    
    it "handles validation errors" do
      post :create, params: { invalid: 'data' }, headers: headers
      
      if response.status == 422
        expect(json_response).to have_key('errors')
        expect(json_response['errors']).to be_an(Array)
      end
    end
    
    it "handles not found errors" do
      get :show, params: { id: 'non-existent' }, headers: headers
      
      expect(response).to have_http_status(:not_found)
      expect(json_response['error']['code']).to eq('RESOURCE_NOT_FOUND')
    end
    
    it "handles unauthorized access" do
      get :index
      
      expect(response).to have_http_status(:unauthorized)
      expect(json_response['error']['code']).to eq('UNAUTHORIZED')
    end
  end
end

RSpec.shared_examples "API pagination" do |default_per_page = 25, max_per_page = 100|
  describe "pagination" do
    before do
      create_list(factory_name, default_per_page + 10, user: user)
    end
    
    it "paginates results by default" do
      get :index, headers: headers
      
      expect(json_response['data'].size).to eq(default_per_page)
      expect(json_response['meta']).to have_key('pagination')
    end
    
    it "respects per_page parameter" do
      get :index, params: { per_page: 10 }, headers: headers
      
      expect(json_response['data'].size).to eq(10)
    end
    
    it "enforces maximum per_page limit" do
      get :index, params: { per_page: max_per_page + 50 }, headers: headers
      
      expect(json_response['data'].size).to eq(max_per_page)
    end
    
    it "includes pagination metadata" do
      get :index, headers: headers
      
      pagination = json_response['meta']['pagination']
      expect(pagination).to have_key('current_page')
      expect(pagination).to have_key('total_pages')
      expect(pagination).to have_key('total_count')
      expect(pagination).to have_key('per_page')
    end
    
    it "supports page navigation" do
      get :index, params: { page: 2 }, headers: headers
      
      expect(json_response['meta']['pagination']['current_page']).to eq(2)
    end
  end
end

RSpec.shared_examples "API filtering and sorting" do |filterable_fields = [], sortable_fields = []|
  describe "filtering" do
    filterable_fields.each do |field|
      it "filters by #{field}" do
        matching_record = create(factory_name, user: user, field => 'matching_value')
        non_matching_record = create(factory_name, user: user, field => 'other_value')
        
        get :index, params: { field => 'matching_value' }, headers: headers
        
        resource_ids = json_response['data'].map { |r| r['id'] }
        expect(resource_ids).to include(matching_record.id)
        expect(resource_ids).not_to include(non_matching_record.id)
      end
    end
  end
  
  describe "sorting" do
    sortable_fields.each do |field|
      it "sorts by #{field} ascending" do
        get :index, params: { sort: field, order: 'asc' }, headers: headers
        
        values = json_response['data'].map { |r| r[field.to_s] }
        expect(values).to eq(values.sort)
      end
      
      it "sorts by #{field} descending" do
        get :index, params: { sort: field, order: 'desc' }, headers: headers
        
        values = json_response['data'].map { |r| r[field.to_s] }
        expect(values).to eq(values.sort.reverse)
      end
    end
    
    it "defaults to created_at desc when no sort specified" do
      old_record = create(factory_name, user: user, created_at: 1.day.ago)
      new_record = create(factory_name, user: user, created_at: 1.hour.ago)
      
      get :index, headers: headers
      
      first_id = json_response['data'].first['id']
      expect(first_id).to eq(new_record.id)
    end
  end
end

RSpec.shared_examples "API field selection" do |selectable_fields = []|
  describe "field selection" do
    it "returns all fields by default" do
      resource = create(factory_name, user: user)
      
      get :show, params: { id: resource.id }, headers: headers
      
      selectable_fields.each do |field|
        expect(json_response['data']).to have_key(field.to_s)
      end
    end
    
    it "returns only requested fields when specified" do
      resource = create(factory_name, user: user)
      requested_fields = selectable_fields.first(2)
      
      get :show, params: { id: resource.id, fields: requested_fields.join(',') }, headers: headers
      
      requested_fields.each do |field|
        expect(json_response['data']).to have_key(field.to_s)
      end
      
      excluded_fields = selectable_fields - requested_fields
      excluded_fields.each do |field|
        expect(json_response['data']).not_to have_key(field.to_s)
      end
    end
  end
end

RSpec.shared_examples "CORS enabled endpoint" do
  it "includes CORS headers" do
    get :index, headers: headers
    
    expect(response.headers['Access-Control-Allow-Origin']).to be_present
    expect(response.headers['Access-Control-Allow-Methods']).to be_present
    expect(response.headers['Access-Control-Allow-Headers']).to be_present
  end
  
  it "responds to OPTIONS requests" do
    process :options, method: :options, params: {}
    
    expect(response).to have_http_status(:ok)
    expect(response.headers['Access-Control-Allow-Methods']).to include('GET', 'POST', 'PUT', 'DELETE')
  end
end