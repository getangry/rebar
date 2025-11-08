# frozen_string_literal: true

# Parses Zanzibar-style tuple strings into components
#
# Standard Zanzibar format (preferred):
#   subject_type:subject_id#relation@actor_type:actor_id
#   Example: document:quarterly-report#viewer@user:alice
#
# Legacy format (also supported):
#   actor_type:actor_id#relation#subject_type:subject_id
#   Example: user:alice#viewer#document:quarterly-report
#
# Userset format:
#   actor_type:actor_id#relation
#   Example: group:engineering#member
class TupleParser
  class ParseError < StandardError; end

  # Parse a tuple string into its components
  # @param tuple [String] The tuple string to parse
  # @return [Hash] Hash with :actor, :actor_id, :permission, :subject, :subject_id
  # @raise [ParseError] If the tuple format is invalid
  def self.parse(tuple)
    raise ParseError, "Tuple cannot be blank" if tuple.blank?

    # Check for Zanzibar format with @ symbol
    if tuple.include?("@")
      parse_zanzibar_format(tuple)
    else
      parse_legacy_format(tuple)
    end
  end

  # Parse Zanzibar format: subject:id#relation@actor:id
  # @param tuple [String] The tuple string to parse
  # @return [Hash] Parsed components
  def self.parse_zanzibar_format(tuple)
    # Split by @ to get subject#relation and actor parts
    parts = tuple.split("@", 2)
    raise ParseError, "Invalid Zanzibar format. Expected 'subject:id#relation@actor:id'" if parts.length != 2

    subject_and_relation = parts[0]
    actor_part = parts[1]

    # Split subject#relation
    sr_parts = subject_and_relation.split("#", 2)
    raise ParseError, "Invalid format. Expected 'subject:id#relation@actor:id'" if sr_parts.length != 2

    subject_part = sr_parts[0]
    relation = sr_parts[1]

    subject_type, subject_id = parse_entity(subject_part)
    actor_type, actor_id = parse_actor_with_userset(actor_part)

    {
      subject: subject_type,
      subject_id: subject_id,
      permission: relation,
      actor: actor_type,
      actor_id: actor_id
    }
  end

  # Parse legacy format: actor:id#relation#subject:id
  # @param tuple [String] The tuple string to parse
  # @return [Hash] Parsed components
  def self.parse_legacy_format(tuple)
    parts = tuple.split("#")

    case parts.length
    when 2
      # Userset format: actor_type:actor_id#relation
      actor_part = parts[0]
      relation = parts[1]

      actor_type, actor_id = parse_entity(actor_part)

      {
        actor: actor_type,
        actor_id: actor_id,
        permission: relation,
        subject: nil,
        subject_id: nil
      }
    when 3
      # Full tuple format: actor_type:actor_id#relation#subject_type:subject_id
      actor_part = parts[0]
      relation = parts[1]
      subject_part = parts[2]

      actor_type, actor_id = parse_entity(actor_part)
      subject_type, subject_id = parse_entity(subject_part)

      {
        actor: actor_type,
        actor_id: actor_id,
        permission: relation,
        subject: subject_type,
        subject_id: subject_id
      }
    else
      raise ParseError, "Invalid tuple format. Expected 'actor:id#relation#subject:id' or 'subject:id#relation@actor:id'"
    end
  end

  # Parse actor part which might include userset (e.g., "group:engineering#member")
  # @param actor [String] The actor string to parse
  # @return [Array<String, String>] [type, id]
  def self.parse_actor_with_userset(actor)
    # Check if this is a userset reference (actor_type:actor_id#relation)
    if actor.include?("#")
      # For now, treat the whole thing as the actor_id with special handling
      # Example: group:engineering#member becomes actor="group", actor_id="engineering", actor_rel="member"
      # But we need to return it in a way the system understands
      parts = actor.split("#", 2)
      entity_part = parts[0]
      # relation_part = parts[1]  # This would be actor_rel

      parse_entity(entity_part)
    else
      parse_entity(actor)
    end
  end

  # Parse an entity part (type:id)
  # @param entity [String] The entity string to parse
  # @return [Array<String, String>] [type, id]
  # @raise [ParseError] If the entity format is invalid
  def self.parse_entity(entity)
    parts = entity.split(":", 2)

    raise ParseError, "Invalid entity format '#{entity}'. Expected 'type:id'" if parts.length != 2
    raise ParseError, "Entity type cannot be empty" if parts[0].blank?
    raise ParseError, "Entity id cannot be empty" if parts[1].blank?

    parts
  end

  # Format components into a Zanzibar-style tuple string
  # @param subject [String] Subject type
  # @param subject_id [String] Subject ID
  # @param relation [String] Relation/permission
  # @param actor [String] Actor type
  # @param actor_id [String] Actor ID
  # @param format [Symbol] :zanzibar (default) or :legacy
  # @return [String] Formatted tuple string
  def self.format(subject:, subject_id:, relation:, actor:, actor_id:, format: :zanzibar)
    case format
    when :zanzibar
      "#{subject}:#{subject_id}##{relation}@#{actor}:#{actor_id}"
    when :legacy
      "#{actor}:#{actor_id}##{relation}##{subject}:#{subject_id}"
    else
      raise ArgumentError, "Unknown format: #{format}. Use :zanzibar or :legacy"
    end
  end
end
