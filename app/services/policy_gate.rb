class ForbiddenError < StandardError; end

class PolicyGate
  def initialize(service_id:, grant_repo:)
    @service_id = service_id
    @grants = grant_repo.grants_for(service_id) # array of OpenStruct/Hash with keys below
  end

  def allow_tuple_write!(tenant:, subject:, id:, relation:, actor:, actor_id:)
    allowed = @grants.any? do |g|
      g[:action] == "tuples.write" &&
      match_tenant(g, tenant) &&
      match_subject(g, subject) &&
      match_rel(g, relation) &&
      match_prefix(g[:subject_prefix], id) &&
      (g[:actor].nil? || g[:actor] == actor) &&
      match_prefix(g[:actor_prefix], actor_id)
    end
    raise ForbiddenError, "tuples.write denied" unless allowed
  end

  def allow_check!(tenant:, subject:, subject_id:, permission:)
    allowed = @grants.any? do |g|
      g[:action] == "auth.check" &&
      match_tenant(g, tenant) &&
      match_subject(g, subject) &&
      match_prefix(g[:subject_prefix], subject_id)
    end
    raise ForbiddenError, "auth.check denied" unless allowed
  end

  private
  def match_tenant(g, tenant)  = g[:tenant_id].nil? || g[:tenant_id] == tenant
  def match_subject(g, subj)   = g[:subject].nil? || g[:subject] == subj
  def match_rel(g, rel)        = g[:relations].nil? || g[:relations].include?(rel)
  def match_prefix(prefix, s)  = prefix.nil? || s.start_with?(prefix)
end
