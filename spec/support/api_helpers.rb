# frozen_string_literal: true

module ApiHelpers
  # Parse JSON response body
  def json_response
    @json_response ||= JSON.parse(response.body)
  rescue JSON::ParserError
    {}
  end

  # Get parsed JSON response (alias for readability)
  def json
    json_response
  end

  # Expect specific JSON response structure and status
  def expect_json_response(status, structure = {})
    expect(response).to have_http_status(status)
    expect(response.content_type).to match(%r{application/json})
    
    structure.each do |key, type|
      case type
      when Class
        expect(json_response[key.to_s]).to be_a(type)
      when Array
        expect(json_response[key.to_s]).to be_an(Array)
        if type.first.is_a?(Class)
          json_response[key.to_s].each do |item|
            expect(item).to be_a(type.first)
          end
        end
      when Hash
        expect(json_response[key.to_s]).to be_a(Hash)
        type.each do |nested_key, nested_type|
          expect(json_response[key.to_s][nested_key.to_s]).to be_a(nested_type)
        end
      end
    end
  end

  # Make API POST request with JSON body
  def api_post(path, params = {}, headers = {})
    post path, 
         params: params.to_json, 
         headers: default_api_headers.merge(headers)
  end

  # Make API PUT request with JSON body
  def api_put(path, params = {}, headers = {})
    put path, 
        params: params.to_json, 
        headers: default_api_headers.merge(headers)
  end

  # Make API PATCH request with JSON body
  def api_patch(path, params = {}, headers = {})
    patch path, 
          params: params.to_json, 
          headers: default_api_headers.merge(headers)
  end

  # Make API DELETE request
  def api_delete(path, headers = {})
    delete path, headers: default_api_headers.merge(headers)
  end

  # Make API GET request
  def api_get(path, params = {}, headers = {})
    get path, 
        params: params, 
        headers: default_api_headers.merge(headers)
  end

  # Expect successful API response with data
  def expect_successful_response(data_key = 'data')
    expect(response).to have_http_status(:ok)
    expect(json_response).to have_key(data_key)
  end

  # Expect API error response
  def expect_error_response(status, error_code = nil, message = nil)
    expect(response).to have_http_status(status)
    expect(json_response).to have_key('error')
    
    if error_code
      expect(json_response['error']['code']).to eq(error_code)
    end
    
    if message
      expect(json_response['error']['message']).to include(message)
    end
  end

  # Expect validation error response
  def expect_validation_error(field = nil, message = nil)
    expect(response).to have_http_status(:unprocessable_entity)
    expect(json_response).to have_key('errors')
    
    if field
      expect(json_response['errors']).to have_key(field.to_s)
      
      if message
        expect(json_response['errors'][field.to_s]).to include(message)
      end
    end
  end

  # Expect paginated response structure
  def expect_paginated_response(data_key = 'data', meta_key = 'meta')
    expect_successful_response(data_key)
    expect(json_response).to have_key(meta_key)
    
    meta = json_response[meta_key]
    expect(meta).to have_key('current_page')
    expect(meta).to have_key('total_pages')
    expect(meta).to have_key('total_count')
    expect(meta).to have_key('per_page')
  end

  # Test API rate limiting
  def expect_rate_limited
    expect(response).to have_http_status(:too_many_requests)
    expect(json_response['error']['code']).to eq('rate_limit_exceeded')
  end

  # Test API authentication required
  def expect_authentication_required
    expect(response).to have_http_status(:unauthorized)
    expect(json_response['error']['code']).to eq('authentication_required')
  end

  # Test API authorization denied
  def expect_authorization_denied
    expect(response).to have_http_status(:forbidden)
    expect(json_response['error']['code']).to eq('authorization_denied')
  end

  # Verify API response headers
  def expect_api_headers
    expect(response.headers['Content-Type']).to match(%r{application/json})
    expect(response.headers['X-Request-ID']).to be_present
    expect(response.headers['X-RateLimit-Limit']).to be_present
    expect(response.headers['X-RateLimit-Remaining']).to be_present
  end

  # Verify CORS headers for API
  def expect_cors_headers
    expect(response.headers['Access-Control-Allow-Origin']).to be_present
    expect(response.headers['Access-Control-Allow-Methods']).to be_present
    expect(response.headers['Access-Control-Allow-Headers']).to be_present
  end

  # Create test API request with file upload
  def api_post_with_file(path, file_param, file_path, params = {}, headers = {})
    file = fixture_file_upload(file_path, 'image/png')
    
    post path,
         params: params.merge(file_param => file),
         headers: headers
  end

  # Verify file upload response
  def expect_file_upload_success(file_key = 'file')
    expect_successful_response
    expect(json_response['data']).to have_key(file_key)
    expect(json_response['data'][file_key]).to have_key('url')
    expect(json_response['data'][file_key]).to have_key('filename')
    expect(json_response['data'][file_key]).to have_key('size')
  end

  # Mock external API calls
  def mock_external_api(url, response_body, status: 200, headers: {})
    stub_request(:any, url)
      .to_return(
        status: status,
        body: response_body.to_json,
        headers: { 'Content-Type' => 'application/json' }.merge(headers)
      )
  end

  # Verify external API was called
  def expect_external_api_called(url, method: :post, times: 1)
    expect(WebMock).to have_requested(method, url).times(times)
  end

  private

  def default_api_headers
    @default_headers || {
      'Content-Type' => 'application/json',
      'Accept' => 'application/json'
    }
  end
end