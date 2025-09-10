# frozen_string_literal: true

require 'digest'
require 'securerandom'
require 'base64'
require 'active_model'

module SuperAgent
  module A2A
    # Base class for artifacts in A2A protocol
    class Artifact
      include ActiveModel::Model
      include ActiveModel::Validations

      attr_accessor :id, :type, :name, :description, :content, :metadata,
                    :created_at, :updated_at, :size, :checksum

      validates :id, :type, :name, presence: true

      def initialize(attributes = {})
        super
        @id ||= SecureRandom.uuid
        @metadata ||= {}
        @created_at ||= Time.current.iso8601
        @updated_at ||= Time.current.iso8601
        calculate_size_and_checksum if @content
      end

      def to_h
        {
          id: id,
          type: type,
          name: name,
          description: description,
          content: serialized_content,
          metadata: metadata,
          createdAt: created_at,
          updatedAt: updated_at,
          size: size,
          checksum: checksum,
        }.compact
      end

      def to_json(*args)
        to_h.to_json(*args)
      end

      def self.from_hash(data)
        artifact_class = case data['type']
                         when 'document'
                           DocumentArtifact
                         when 'image'
                           ImageArtifact
                         when 'data'
                           DataArtifact
                         when 'code'
                           CodeArtifact
                         else
                           self
                         end

        artifact_class.new(
          id: data['id'],
          type: data['type'],
          name: data['name'],
          description: data['description'],
          content: data['content'],
          metadata: data['metadata'] || {},
          created_at: data['createdAt'],
          updated_at: data['updatedAt'],
          size: data['size'],
          checksum: data['checksum']
        )
      end

      def self.from_json(json_string)
        data = JSON.parse(json_string)
        from_hash(data)
      end

      def update_content(new_content)
        @content = new_content
        @updated_at = Time.current.iso8601
        calculate_size_and_checksum
      end

      def validate_checksum
        return false unless content && checksum

        calculate_checksum == checksum
      end

      def save_to_file(file_path)
        File.write(file_path, serialized_content)
      end

      def self.from_file(file_path, type: nil, name: nil, description: nil)
        content = File.read(file_path)
        type ||= detect_type_from_extension(File.extname(file_path))
        name ||= File.basename(file_path)

        new(
          type: type,
          name: name,
          description: description,
          content: content
        )
      end

      def empty?
        content.nil? || (content.respond_to?(:empty?) && content.empty?)
      end

      def binary?
        content.is_a?(String) && content.encoding == Encoding::ASCII_8BIT
      end

      private

      def serialized_content
        case type
        when 'data'
          content.is_a?(String) ? content : content.to_json
        else
          content.to_s
        end
      end

      def calculate_size_and_checksum
        serialized = serialized_content
        @size = serialized.bytesize
        @checksum = calculate_checksum
      end

      def calculate_checksum
        return nil unless content

        Digest::SHA256.hexdigest(serialized_content)
      end

      def self.detect_type_from_extension(ext)
        case ext.downcase
        when '.txt', '.md', '.rtf', '.doc', '.docx', '.pdf'
          'document'
        when '.jpg', '.jpeg', '.png', '.gif', '.bmp', '.svg'
          'image'
        when '.json', '.xml', '.csv', '.yaml', '.yml'
          'data'
        when '.rb', '.py', '.js', '.html', '.css', '.java', '.cpp', '.c'
          'code'
        else
          'document'
        end
      end
    end

    # Document artifact for text-based content
    class DocumentArtifact < Artifact
      def initialize(attributes = {})
        super
        @type = 'document'
      end

      def word_count
        return 0 unless content.is_a?(String)

        content.split(/\s+/).length
      end

      def line_count
        return 0 unless content.is_a?(String)

        content.lines.count
      end

      def character_count
        return 0 unless content.is_a?(String)

        content.length
      end

      def paragraph_count
        return 0 unless content.is_a?(String)

        content.split(/\n\s*\n/).reject(&:empty?).length
      end

      def reading_time(words_per_minute: 200)
        return 0 if word_count.zero?

        (word_count.to_f / words_per_minute).ceil
      end

      def extract_headings
        return [] unless content.is_a?(String)

        content.scan(/^#+\s+(.+)$/).flatten
      end

      def truncate(length = 500, suffix = '...')
        return content if content.length <= length

        content[0, length - suffix.length] + suffix
      end
    end

    # Image artifact for visual content
    class ImageArtifact < Artifact
      attr_accessor :width, :height, :format

      def initialize(attributes = {})
        super
        @type = 'image'
        extract_image_info if @content
      end

      def to_h
        super.merge(
          width: width,
          height: height,
          format: format
        ).compact
      end

      def base64_content
        return nil unless content

        Base64.strict_encode64(content)
      end

      def data_url
        return nil unless content && format

        mime_type = case format.downcase
                    when 'jpg', 'jpeg' then 'image/jpeg'
                    when 'png' then 'image/png'
                    when 'gif' then 'image/gif'
                    when 'svg' then 'image/svg+xml'
                    else 'application/octet-stream'
                    end

        "data:#{mime_type};base64,#{base64_content}"
      end

      def aspect_ratio
        return nil unless width && height && height != 0

        width.to_f / height
      end

      def dimensions
        return nil unless width && height

        "#{width}x#{height}"
      end

      private

      def extract_image_info
        # This would require an image processing library like MiniMagick or ImageMagick
        # For now, just set basic defaults based on content
        @format = detect_format_from_content || 'unknown'
        @width = nil
        @height = nil
      end

      def detect_format_from_content
        return nil unless content

        first_bytes = content[0, 10]
        case first_bytes
        when /\A\x89PNG/n
          'png'
        when /\A\xFF\xD8\xFF/n
          'jpeg'
        when /\AGIF8[79]a/
          'gif'
        else
          # Check for XML/SVG as text
          if content.start_with?('<?xml') || content.start_with?('<svg')
            'svg'
          else
            nil
          end
        end
      end
    end

    # Data artifact for structured data
    class DataArtifact < Artifact
      attr_accessor :schema, :encoding

      def initialize(attributes = {})
        super
        @type = 'data'
        @encoding ||= 'json'
      end

      def to_h
        super.merge(
          schema: schema,
          encoding: encoding
        ).compact
      end

      def parsed_content
        case encoding
        when 'json'
          JSON.parse(content)
        when 'yaml'
          YAML.safe_load(content)
        when 'csv'
          require 'csv'
          CSV.parse(content, headers: true)
        else
          content
        end
      rescue StandardError => e
        raise ValidationError, "Failed to parse #{encoding} content: #{e.message}"
      end

      def validate_schema
        return true unless schema

        # Basic JSON Schema validation
        data = parsed_content
        case schema['type']
        when 'object'
          data.is_a?(Hash)
        when 'array'
          data.is_a?(Array)
        when 'string'
          data.is_a?(String)
        when 'number'
          data.is_a?(Numeric)
        when 'boolean'
          [true, false].include?(data)
        else
          true
        end
      end

      def keys
        return [] unless parsed_content.respond_to?(:keys)

        parsed_content.keys
      end

      def values
        return [] unless parsed_content.respond_to?(:values)

        parsed_content.values
      end

      def size_info
        data = parsed_content
        case data
        when Hash
          { type: 'object', keys: data.keys.size, total_size: size }
        when Array
          { type: 'array', items: data.size, total_size: size }
        else
          { type: 'primitive', total_size: size }
        end
      end
    end

    # Code artifact for source code
    class CodeArtifact < Artifact
      attr_accessor :language, :executable

      def initialize(attributes = {})
        super
        @type = 'code'
        @executable ||= false
        @language ||= detect_language
      end

      def to_h
        super.merge(
          language: language,
          executable: executable
        ).compact
      end

      def line_count
        return 0 unless content.is_a?(String)

        content.lines.count
      end

      def detect_language
        return @language if @language

        case content
        when /class\s+\w+.*?end/m
          'ruby'
        when /def\s+\w+.*?:/m
          'python'
        when /function\s+\w+.*?\{/m
          'javascript'
        when /<\?php/
          'php'
        when /public\s+class\s+\w+/
          'java'
        when /#include\s*<.*?>/
          'c'
        when /using\s+namespace\s+std/
          'cpp'
        else
          'text'
        end
      end

      def syntax_highlighted_html
        # This would require a syntax highlighting library
        # For now, just wrap in pre/code tags
        "<pre><code class=\"language-#{language}\">#{CGI.escapeHTML(content)}</code></pre>"
      end

      def extract_functions
        return [] unless content.is_a?(String)

        case language
        when 'ruby'
          content.scan(/def\s+(\w+)/).flatten
        when 'python'
          content.scan(/def\s+(\w+)\s*\(/).flatten
        when 'javascript'
          content.scan(/function\s+(\w+)\s*\(/).flatten
        else
          []
        end
      end

      def extract_classes
        return [] unless content.is_a?(String)

        case language
        when 'ruby'
          content.scan(/class\s+(\w+)/).flatten
        when 'python'
          content.scan(/class\s+(\w+)\s*[\(:]/).flatten
        when 'java'
          content.scan(/(?:public\s+)?class\s+(\w+)/).flatten
        else
          []
        end
      end
    end
  end
end
