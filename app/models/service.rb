require 'securerandom'
require 'digest'

class Service < ApplicationRecord
  # Validations
  validates :name, presence: true, uniqueness: { scope: :tenant_id }
  validates :tenant_id, presence: true
  validates :api_key_hash, presence: true, uniqueness: true
  validates :schema_name, presence: true

  # Scopes
  scope :active, -> { where(active: true) }
  scope :for_tenant, ->(tenant_id) { where(tenant_id: tenant_id) }

  # Virtual attribute for plain API key (only available during creation)
  attr_accessor :api_key

  # Callbacks
  before_validation :generate_api_key, on: :create, unless: :api_key_hash

  ##
  # Generate a new API key
  # Format: rebar_live_<random_32_chars> or rebar_test_<random_32_chars>
  #
  def generate_api_key
    prefix = Rails.env.production? ? 'rebar_live' : 'rebar_test'
    self.api_key = "#{prefix}_#{SecureRandom.alphanumeric(32)}"
    self.api_key_hash = hash_api_key(self.api_key)
  end

  ##
  # Regenerate API key (returns new plain key)
  #
  def regenerate_api_key!
    generate_api_key
    save!
    api_key
  end

  ##
  # Verify an API key matches this service
  #
  def verify_api_key(key)
    return false if key.blank?
    hash_api_key(key) == api_key_hash
  end

  ##
  # Find service by API key
  #
  def self.find_by_api_key(key)
    return nil if key.blank?
    hash = hash_api_key(key)
    find_by(api_key_hash: hash, active: true)
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

  def self.hash_api_key(key)
    Digest::SHA256.hexdigest(key)
  end

  def hash_api_key(key)
    self.class.hash_api_key(key)
  end
end
