# frozen_string_literal: true

require 'securerandom'
require 'active_model'

module SuperAgent
  module A2A
    # Represents a message in A2A protocol communication
    class Message
      include ActiveModel::Model
      include ActiveModel::Validations

      attr_accessor :id, :role, :parts, :metadata, :timestamp

      validates :id, :role, :parts, presence: true
      validates :role, inclusion: { in: %w[user agent system] }
      validate :parts_must_be_array_of_parts

      def initialize(attributes = {})
        super
        @id ||= SecureRandom.uuid
        @parts ||= []
        @metadata ||= {}
        @timestamp ||= Time.current.iso8601
      end

      def to_h
        {
          id: id,
          role: role,
          parts: parts.map(&:to_h),
          metadata: metadata,
          timestamp: timestamp,
        }
      end

      def to_json(*args)
        to_h.to_json(*args)
      end

      def self.from_hash(data)
        new(
          id: data['id'],
          role: data['role'],
          parts: data['parts']&.map { |part_data| Part.from_hash(part_data) } || [],
          metadata: data['metadata'] || {},
          timestamp: data['timestamp']
        )
      end

      def self.from_json(json_string)
        data = JSON.parse(json_string)
        from_hash(data)
      end

      # Content manipulation methods
      def add_text_part(text, metadata: {})
        parts << TextPart.new(content: text, metadata: metadata)
        update_timestamp
      end

      def add_file_part(file_path, content_type: nil, metadata: {})
        parts << FilePart.new(file_path: file_path, content_type: content_type, metadata: metadata)
        update_timestamp
      end

      def add_data_part(data, schema: nil, metadata: {})
        parts << DataPart.new(data: data, schema: schema, metadata: metadata)
        update_timestamp
      end

      def add_part(part)
        raise ArgumentError, 'Part must be a Part instance' unless part.is_a?(Part)

        parts << part
        update_timestamp
      end

      # Content access methods
      def text_content
        text_parts = parts.select { |p| p.is_a?(TextPart) }
        text_parts.map(&:content).join("\n")
      end

      def data_content
        data_parts = parts.select { |p| p.is_a?(DataPart) }
        data_parts.map(&:data)
      end

      def file_attachments
        parts.select { |p| p.is_a?(FilePart) }
      end

      def has_text?
        parts.any? { |p| p.is_a?(TextPart) }
      end

      def has_files?
        parts.any? { |p| p.is_a?(FilePart) }
      end

      def has_data?
        parts.any? { |p| p.is_a?(DataPart) }
      end

      def part_count
        parts.size
      end

      delegate :empty?, to: :parts

      # Convenience constructor methods
      def self.text_message(text, role: 'user', metadata: {})
        message = new(role: role, metadata: metadata)
        message.add_text_part(text)
        message
      end

      def self.data_message(data, role: 'agent', schema: nil, metadata: {})
        message = new(role: role, metadata: metadata)
        message.add_data_part(data, schema: schema)
        message
      end

      def self.file_message(file_path, role: 'user', content_type: nil, metadata: {})
        message = new(role: role, metadata: metadata)
        message.add_file_part(file_path, content_type: content_type)
        message
      end

      private

      def parts_must_be_array_of_parts
        return unless parts.is_a?(Array)

        parts.each_with_index do |part, index|
          errors.add(:parts, "Part at index #{index} must be a Part instance") unless part.is_a?(Part)
        end
      end

      def update_timestamp
        @timestamp = Time.current.iso8601
      end
    end
  end
end
