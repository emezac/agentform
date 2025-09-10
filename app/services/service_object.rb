# frozen_string_literal: true

# Base module for service objects
module ServiceObject
  extend ActiveSupport::Concern

  included do
    def self.call(*args, **kwargs)
      new(*args, **kwargs).call
    end
  end

  class_methods do
    def call(*args, **kwargs)
      new(*args, **kwargs).call
    end
  end
end

# Service result object for consistent return values
class ServiceResult
  attr_reader :result, :errors

  def initialize(success:, result: nil, errors: [])
    @success = success
    @result = result
    @errors = Array(errors)
  end

  def success?
    @success
  end

  def failure?
    !@success
  end

  def self.success(result = nil)
    new(success: true, result: result)
  end

  def self.failure(errors)
    new(success: false, errors: errors)
  end
end