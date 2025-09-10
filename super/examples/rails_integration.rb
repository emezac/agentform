#!/usr/bin/env ruby
# frozen_string_literal: true

# Rails Integration Example
# This example shows how to integrate SuperAgent with Rails controllers

# This would typically be in your Rails app structure
# For demonstration purposes, we'll show the code structure

=begin

# 1. Gemfile
# Add to your Gemfile:
gem 'super_agent'
gem 'turbo-rails'

# 2. Install SuperAgent
# rails generate super_agent:install
# rails db:migrate

# 3. Create a workflow
# app/workflows/content_generation_workflow.rb
class ContentGenerationWorkflow < SuperAgent::WorkflowDefinition
  define_task :validate_topic, :pundit_policy do |config|
    config.policy_class = ContentPolicy
    config.action = :create?
  end

  define_task :research_topic, :llm do |config|
    config.model = "gpt-4"
    config.system_prompt = "Research the given topic and provide key insights"
    config.template = "Topic: {{topic}}, Tone: {{tone}}"
    config.max_tokens = 500
  end

  define_task :generate_content, :llm do |config|
    config.model = "gpt-4"
    config.system_prompt = "Write engaging content based on research"
    config.template = "Research: {{research_topic}}, Format: {{format}}"
  end

  define_task :save_content, :direct_handler do |config|
    config.handler = ->(context) {
      content = context.get(:generate_content)
      article = Article.create!(
        title: context.get(:topic),
        body: content,
        user_id: context.get(:current_user_id)
      )
      { article_id: article.id, status: "created" }
    }
  end

  define_task :notify_team, :turbo_stream do |config|
    config.target = "#articles_list"
    config.action = "prepend"
    config.template = "articles/article_preview"
    config.locals = { article_id: "{{article_id}}" }
  end
end

# 4. Create an agent
# app/agents/content_agent.rb
class ContentAgent < SuperAgent::Base
  def generate_article(topic, format: "blog_post", tone: "professional")
    run_workflow(ContentGenerationWorkflow, initial_input: {
      topic: topic,
      format: format,
      tone: tone
    })
  end

  def generate_with_streaming(topic, format: "blog_post", tone: "professional")
    run_workflow(ContentGenerationWorkflow, 
                 initial_input: { topic: topic, format: format, tone: tone }, 
                 streaming: true) do |step_result|
      
      # Stream progress to the UI
      Turbo::StreamsChannel.broadcast_replace_to(
        "user_#{current_user.id}",
        target: "content_generation_status",
        partial: "shared/progress_bar",
        locals: { step: step_result }
      )
    end
  end

  private

  def current_user
    @current_user ||= context[:current_user]
  end
end

# 5. Use in controller
# app/controllers/articles_controller.rb
class ArticlesController < ApplicationController
  before_action :authenticate_user!

  def create
    agent = ContentAgent.new(
      current_user: current_user,
      request: request,
      params: params
    )

    if params[:streaming] == "true"
      # Async with streaming
      agent.run_workflow_later(ContentGenerationWorkflow, initial_input: {
        topic: params[:topic],
        format: params[:format],
        tone: params[:tone]
      })
      
      render json: { message: "Content generation started" }, status: :accepted
    else
      # Sync execution
      result = agent.generate_article(params[:topic], 
                                      format: params[:format], 
                                      tone: params[:tone])

      if result.completed?
        redirect_to article_path(result.final_output[:article_id]), 
                    notice: "Article generated successfully!"
      else
        render :new, alert: "Error: #{result.error_message}"
      end
    end
  end

  def generate_with_live_updates
    @agent = ContentAgent.new(
      current_user: current_user,
      request: request
    )

    respond_to do |format|
      format.html
      format.turbo_stream do
        @agent.generate_with_streaming(
          params[:topic], 
          format: params[:format], 
          tone: params[:tone]
        )
      end
    end
  end
end

# 6. View with streaming support
# app/views/articles/generate_with_live_updates.html.erb
<div class="container">
  <h1>Generate Content</h1>
  
  <div id="content_generation_status">
    <p>Ready to generate content...</p>
  </div>

  <%= form_with url: generate_with_live_updates_articles_path, 
               method: :post, 
               local: false, 
               data: { turbo_stream: true } do |form| %>
    <div class="field">
      <%= form.label :topic %>
      <%= form.text_field :topic, required: true %>
    </div>

    <div class="field">
      <%= form.label :format %>
      <%= form.select :format, ['blog_post', 'social_media', 'email'] %>
    </div>

    <div class="field">
      <%= form.label :tone %>
      <%= form.select :tone, ['professional', 'casual', 'technical'] %>
    </div>

    <%= form.submit "Generate Content", class: "btn btn-primary" %>
  <% end %>

  <div id="generated_content">
    <!-- Content will be streamed here -->
  </div>
</div>

# 7. Routes
# config/routes.rb
Rails.application.routes.draw do
  resources :articles do
    collection do
      post :generate_with_live_updates
      get :generate_with_live_updates
    end
  end
end

# 8. Background job example
# app/jobs/content_generation_job.rb
class ContentGenerationJob < ApplicationJob
  queue_as :default

  def perform(user_id, topic, format, tone)
    user = User.find(user_id)
    agent = ContentAgent.new(current_user: user)
    
    agent.run_workflow(ContentGenerationWorkflow, initial_input: {
      topic: topic,
      format: format,
      tone: tone
    })
  end
end

=end

puts "🏗️ Rails Integration Examples"
puts "=" * 40
puts ""
puts "This example demonstrates how to integrate SuperAgent with Rails:"
puts ""
puts "1. ✅ Install SuperAgent in your Rails app"
puts "2. ✅ Create AI workflows for content generation"
puts "3. ✅ Build agents with Rails context"
puts "4. ✅ Use streaming with Turbo Rails"
puts "5. ✅ Handle background processing"
puts "6. ✅ Real-time UI updates"
puts ""
puts "📁 Check the examples/ directory for more practical examples!"
puts "🚀 Ready to build AI-powered Rails applications!"