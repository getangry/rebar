require 'securerandom'
require 'digest'

class ApiKey < ApplicationRecord
  # Associations
  belongs_to :service

  # Validations
  validates :key_hash, presence: true, uniqueness: true
  validates :key_prefix, presence: true
  validates :service_id, presence: true
  validates :usage_count, numericality: { greater_than_or_equal_to: 0 }

  # Scopes
  scope :active, -> { where(active: true) }
  scope :for_service, ->(service_id) { where(service_id: service_id) }
  scope :unused, -> { where('last_used_at IS NULL OR last_used_at < ?', 30.days.ago) }
  scope :recently_used, -> { where('last_used_at > ?', 7.days.ago) }

  # Virtual attribute for plain API key (only available during creation)
  attr_accessor :key

  # Callbacks
  before_validation :generate_api_key, on: :create, unless: :key_hash

  ##
  # Generate a new API key
  # Format: rebar_live_<random_32_chars> or rebar_test_<random_32_chars>
  #
  def generate_api_key
    prefix = Rails.env.production? ? 'rebar_live' : 'rebar_test'
    random_part = SecureRandom.alphanumeric(32)
    self.key = "#{prefix}_#{random_part}"
    self.key_hash = hash_api_key(self.key)
    self.key_prefix = "#{prefix}_#{random_part[0..6]}..."
  end

  ##
  # Verify an API key matches this record
  #
  def verify_api_key(key_to_verify)
    return false if key_to_verify.blank?
    hash_api_key(key_to_verify) == key_hash
  end

  ##
  # Find API key by the actual key value
  #
  def self.find_by_key(key)
    return nil if key.blank?
    hash = hash_api_key(key)
    joins(:service).where(key_hash: hash, active: true).where(services: { active: true }).first
  end

  ##
  # Record that this key was used
  #
  def record_usage!
    update_columns(
      last_used_at: Time.current,
      usage_count: usage_count + 1
    )
  end

  ##
  # Revoke this API key
  #
  def revoke!
    update!(active: false)
  end

  ##
  # Check if key appears to be stale (not used in 30+ days)
  #
  def stale?
    last_used_at.nil? || last_used_at < 30.days.ago
  end

  ##
  # Check if key was recently created but never used
  #
  def unused?
    last_used_at.nil? && created_at < 7.days.ago
  end

  private

  def self.hash_api_key(key)
    Digest::SHA256.hexdigest(key)
  end

  def hash_api_key(key)
    self.class.hash_api_key(key)
  end
end
