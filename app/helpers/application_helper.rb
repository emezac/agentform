module ApplicationHelper
  def markdown(text)
    return "" if text.blank?
    
    renderer = Redcarpet::Render::HTML.new(
      filter_html: true,
      no_links: false,
      no_images: false,
      no_styles: false,
      safe_links_only: true,
      with_toc_data: false,
      hard_wrap: true
    )
    
    markdown = Redcarpet::Markdown.new(renderer,
      autolink: true,
      tables: true,
      strikethrough: true,
      fenced_code_blocks: true,
      no_intra_emphasis: true,
      superscript: true
    )
    
    markdown.render(text).html_safe
  end

  # Error display helpers for AI generation errors
  def error_border_color(severity)
    case severity
    when 'error', 'fatal'
      'border-red-400'
    when 'warning'
      'border-yellow-400'
    when 'info'
      'border-blue-400'
    else
      'border-gray-400'
    end
  end

  def error_text_color(severity)
    case severity
    when 'error', 'fatal'
      'text-red-800'
    when 'warning'
      'text-yellow-800'
    when 'info'
      'text-blue-800'
    else
      'text-gray-800'
    end
  end

  def error_icon(severity)
    case severity
    when 'error', 'fatal'
      content_tag(:svg, class: "w-6 h-6 text-red-400", fill: "currentColor", viewBox: "0 0 20 20") do
        content_tag(:path, "", fill_rule: "evenodd", d: "M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z", clip_rule: "evenodd")
      end
    when 'warning'
      content_tag(:svg, class: "w-6 h-6 text-yellow-400", fill: "currentColor", viewBox: "0 0 20 20") do
        content_tag(:path, "", fill_rule: "evenodd", d: "M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z", clip_rule: "evenodd")
      end
    when 'info'
      content_tag(:svg, class: "w-6 h-6 text-blue-400", fill: "currentColor", viewBox: "0 0 20 20") do
        content_tag(:path, "", fill_rule: "evenodd", d: "M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z", clip_rule: "evenodd")
      end
    else
      content_tag(:svg, class: "w-6 h-6 text-gray-400", fill: "currentColor", viewBox: "0 0 20 20") do
        content_tag(:path, "", fill_rule: "evenodd", d: "M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z", clip_rule: "evenodd")
      end
    end
  end

  # Admin navigation helpers
  def admin_nav_class(path)
    base_classes = "px-3 py-2 text-sm font-medium transition-colors"
    if current_page?(path)
      "#{base_classes} text-red-600 border-b-2 border-red-600"
    else
      "#{base_classes} text-gray-500 hover:text-red-600"
    end
  end

  def admin_card_classes
    "bg-white rounded-xl shadow-sm border border-gray-200 hover:shadow-md transition-shadow duration-200"
  end

  def admin_button_primary_classes
    "inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md text-white bg-red-600 hover:bg-red-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-red-500 transition-colors"
  end

  def admin_button_secondary_classes
    "inline-flex items-center px-4 py-2 border border-gray-300 text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-red-500 transition-colors"
  end

  def admin_status_badge(status, text = nil)
    text ||= status.to_s.humanize
    
    case status.to_s.downcase
    when 'active', 'published', 'enabled'
      content_tag(:span, text, class: "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800")
    when 'inactive', 'disabled', 'suspended'
      content_tag(:span, text, class: "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-red-100 text-red-800")
    when 'pending', 'processing'
      content_tag(:span, text, class: "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-yellow-100 text-yellow-800")
    when 'expired'
      content_tag(:span, text, class: "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-gray-100 text-gray-800")
    else
      content_tag(:span, text, class: "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-blue-100 text-blue-800")
    end
  end
end