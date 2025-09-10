# frozen_string_literal: true

require 'base64'
require 'active_model'

module SuperAgent
  module A2A
    # Base class for message parts in A2A protocol
    class Part
      include ActiveModel::Model
      include ActiveModel::Validations

      attr_accessor :type, :metadata

      validates :type, presence: true

      def initialize(attributes = {})
        super
        @metadata ||= {}
      end

      def to_h
        {
          type: type,
          metadata: metadata,
        }.merge(part_specific_attributes)
      end

      def to_json(*args)
        to_h.to_json(*args)
      end

      def self.from_hash(data)
        case data['type']
        when 'text'
          TextPart.from_hash(data)
        when 'file'
          FilePart.from_hash(data)
        when 'data'
          DataPart.from_hash(data)
        else
          new(type: data['type'], metadata: data['metadata'] || {})
        end
      end

      protected

      def part_specific_attributes
        {}
      end
    end

    # Text content part for A2A messages
    class TextPart < Part
      attr_accessor :content

      validates :content, presence: true

      def initialize(attributes = {})
        super
        @type = 'text'
      end

      def self.from_hash(data)
        new(
          content: data['content'],
          metadata: data['metadata'] || {}
        )
      end

      def word_count
        return 0 unless content.is_a?(String)

        content.split(/\s+/).length
      end

      def character_count
        return 0 unless content.is_a?(String)

        content.length
      end

      def line_count
        return 0 unless content.is_a?(String)

        content.lines.count
      end

      def truncate(length = 100, suffix = '...')
        return content if content.length <= length

        content[0, length - suffix.length] + suffix
      end

      protected

      def part_specific_attributes
        { content: content }
      end
    end

    # File content part for A2A messages
    class FilePart < Part
      attr_accessor :file_path, :content_type, :size, :filename

      validates :file_path, presence: true

      def initialize(attributes = {})
        super
        @type = 'file'
        extract_file_info if @file_path && File.exist?(@file_path)
      end

      def self.from_hash(data)
        new(
          file_path: data['filePath'],
          content_type: data['contentType'],
          size: data['size'],
          filename: data['filename'],
          metadata: data['metadata'] || {}
        )
      end

      def exists?
        file_path && File.exist?(file_path)
      end

      def read_content
        return nil unless exists?

        File.read(file_path)
      end

      def base64_content
        return nil unless exists?

        Base64.strict_encode64(File.read(file_path))
      end

      def readable?
        exists? && File.readable?(file_path)
      end

      def binary?
        return false unless exists?

        content = File.read(file_path, 1024) # Read first 1KB
        content.encoding == Encoding::ASCII_8BIT && content.bytes.any? { |b| b < 32 && ![9, 10, 13].include?(b) }
      end

      def text?
        !binary?
      end

      def image?
        return false unless content_type

        content_type.start_with?('image/')
      end

      def document?
        return false unless content_type

        %w[
          application/pdf
          application/msword
          application/vnd.openxmlformats-officedocument.wordprocessingml.document
          text/plain
          text/markdown
        ].include?(content_type)
      end

      protected

      def part_specific_attributes
        {
          filePath: file_path,
          contentType: content_type,
          size: size,
          filename: filename,
        }.compact
      end

      private

      def extract_file_info
        @size = File.size(file_path)
        @filename = File.basename(file_path)
        @content_type ||= detect_content_type
      end

      def detect_content_type
        case File.extname(file_path).downcase
        when '.txt' then 'text/plain'
        when '.md', '.markdown' then 'text/markdown'
        when '.json' then 'application/json'
        when '.xml' then 'application/xml'
        when '.pdf' then 'application/pdf'
        when '.doc' then 'application/msword'
        when '.docx' then 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
        when '.jpg', '.jpeg' then 'image/jpeg'
        when '.png' then 'image/png'
        when '.gif' then 'image/gif'
        when '.svg' then 'image/svg+xml'
        when '.mp3' then 'audio/mpeg'
        when '.wav' then 'audio/wav'
        when '.mp4' then 'video/mp4'
        when '.avi' then 'video/x-msvideo'
        when '.csv' then 'text/csv'
        when '.html', '.htm' then 'text/html'
        when '.css' then 'text/css'
        when '.js' then 'application/javascript'
        when '.zip' then 'application/zip'
        else 'application/octet-stream'
        end
      end
    end

    # Data content part for structured data in A2A messages
    class DataPart < Part
      attr_accessor :data, :schema, :encoding

      validates :data, presence: true

      def initialize(attributes = {})
        super
        @type = 'data'
        @encoding ||= 'json'
      end

      def self.from_hash(hash_data)
        new(
          data: hash_data['data'],
          schema: hash_data['schema'],
          encoding: hash_data['encoding'],
          metadata: hash_data['metadata'] || {}
        )
      end

      def serialized_data
        case encoding
        when 'json'
          data.to_json
        when 'yaml'
          data.to_yaml if data.respond_to?(:to_yaml)
        when 'xml'
          # Would need XML serializer
          data.to_s
        when 'csv'
          # Would need CSV serializer for arrays/hashes
          data.to_s
        else
          data.to_s
        end
      end

      def parsed_data
        case encoding
        when 'json'
          data.is_a?(String) ? JSON.parse(data) : data
        when 'yaml'
          data.is_a?(String) ? YAML.safe_load(data) : data
        else
          data
        end
      rescue JSON::ParserError, Psych::SyntaxError => e
        raise ValidationError, "Failed to parse #{encoding} data: #{e.message}"
      end

      def validate_against_schema
        return true unless schema

        # Basic JSON Schema validation
        case schema['type']
        when 'object'
          parsed_data.is_a?(Hash)
        when 'array'
          parsed_data.is_a?(Array)
        when 'string'
          parsed_data.is_a?(String)
        when 'number', 'integer'
          parsed_data.is_a?(Numeric)
        when 'boolean'
          [true, false].include?(parsed_data)
        else
          true
        end
      end

      def size
        serialized_data.bytesize
      end

      def empty?
        case data
        when Hash then data.empty?
        when Array then data.empty?
        when String then data.strip.empty?
        else false
        end
      end

      protected

      def part_specific_attributes
        {
          data: data,
          schema: schema,
          encoding: encoding,
        }.compact
      end
    end
  end
end
