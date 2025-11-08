require 'securerandom'
require 'digest'

class Service < ApplicationRecord
  # Associations
  has_many :api_keys, dependent: :destroy

  # Validations
  validates :name, presence: true, uniqueness: { scope: :tenant_id }
  validates :tenant_id, presence: true
  validates :schemas, presence: true
  validate :schemas_must_be_array

  # Scopes
  scope :active, -> { where(active: true) }
  scope :for_tenant, ->(tenant_id) { where(tenant_id: tenant_id) }

  # Virtual attribute for plain API key (only available during creation)
  attr_accessor :api_key

  # Callbacks
  after_create :create_default_api_key

  ##
  # Create default API key after service creation
  #
  def create_default_api_key
    api_key_record = api_keys.create!(name: "Default API Key")
    self.api_key = api_key_record.key # Store plain key in virtual attribute
  end

  ##
  # Generate a new API key (creates new ApiKey record)
  #
  def create_api_key(name: nil)
    api_key_record = api_keys.create!(name: name)
    api_key_record.key # Return plain key (only shown once)
  end

  ##
  # Regenerate API key (deprecated - use create_api_key instead)
  # For backward compatibility, revokes all old keys and creates a new one
  #
  def regenerate_api_key!
    api_keys.active.each(&:revoke!)
    new_key = create_api_key(name: "Regenerated API Key")
    self.api_key = new_key
    new_key
  end

  ##
  # Verify an API key matches this service
  #
  def verify_api_key(key)
    return false if key.blank?
    api_keys.active.any? { |k| k.verify_api_key(key) }
  end

  ##
  # Find service by API key
  #
  def self.find_by_api_key(key)
    api_key_record = ApiKey.find_by_key(key)
    api_key_record&.service
  end

  ##
  # Check if service can access a subject type
  #
  def can_access_subject?(subject)
    return true if allowed_subjects.empty? # Empty means all allowed
    allowed_subjects.include?(subject)
  end

  ##
  # Check if service can access a relation
  #
  def can_access_relation?(relation)
    return true if allowed_relations.empty? # Empty means all allowed
    allowed_relations.include?(relation)
  end

  ##
  # Add allowed subject
  #
  def add_allowed_subject(subject)
    self.allowed_subjects = (allowed_subjects + [subject]).uniq
    save
  end

  ##
  # Remove allowed subject
  #
  def remove_allowed_subject(subject)
    self.allowed_subjects = allowed_subjects - [subject]
    save
  end

  ##
  # Add allowed relation
  #
  def add_allowed_relation(relation)
    self.allowed_relations = (allowed_relations + [relation]).uniq
    save
  end

  ##
  # Remove allowed relation
  #
  def remove_allowed_relation(relation)
    self.allowed_relations = allowed_relations - [relation]
    save
  end

  ##
  # Add schema
  #
  def add_schema(schema)
    self.schemas = (schemas + [schema]).uniq
    save
  end

  ##
  # Remove schema
  #
  def remove_schema(schema)
    return false if schemas.length <= 1 # Must have at least one schema
    self.schemas = schemas - [schema]
    save
  end

  ##
  # Deactivate service
  #
  def deactivate!
    update!(active: false)
  end

  ##
  # Activate service
  #
  def activate!
    update!(active: true)
  end

  private

  def schemas_must_be_array
    unless schemas.is_a?(Array) && schemas.any?
      errors.add(:schemas, 'must be an array with at least one schema')
    end
  end

  def self.hash_api_key(key)
    Digest::SHA256.hexdigest(key)
  end

  def hash_api_key(key)
    self.class.hash_api_key(key)
  end
end
