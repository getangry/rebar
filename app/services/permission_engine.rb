require "yaml"
require "set"

class PermissionEngine
  MAX_DEPTH = 6
  MEMORY_CACHE_SIZE = 10_000  # LRU cache for sub-millisecond checks

  # Class-level cache shared across all instances for true sub-millisecond performance
  @class_memory_cache = {}
  @class_cache_order = []
  @cache_mutex = Mutex.new

  class << self
    attr_accessor :class_memory_cache, :class_cache_order, :cache_mutex
  end

  def initialize(schema_path: nil, schema: nil, repo: RebacRepo.new, cache: true)
    @repo = repo
    @cache_enabled = cache

    # Support both Ruby DSL and YAML schemas
    if schema
      # Ruby DSL schema passed directly
      @dsl_schema = schema
      @schema = schema.to_legacy_yaml["types"]
    elsif schema_path&.to_s&.end_with?(".rb")
      # Load Ruby DSL schema
      require schema_path
      @dsl_schema = AuthSchema
      @schema = @dsl_schema.to_legacy_yaml["types"]
    else
      # Load YAML schema (backward compatibility)
      schema_path ||= Rails.root.join("config/auth_schema.yml")
      @schema = YAML.load_file(schema_path)["types"]
      @dsl_schema = nil
    end
  end

  def check(actor, actor_id, permission, subject, subject_id)
    return check_uncached(actor, actor_id, permission, subject, subject_id) unless @cache_enabled

    # Try class-level in-memory cache first (sub-millisecond, persists across requests)
    cache_key = "#{@repo.tenant_id}:#{actor}:#{actor_id}:#{permission}:#{subject}:#{subject_id}"

    # Thread-safe cache access
    cached_result = self.class.cache_mutex.synchronize do
      if self.class.class_memory_cache.key?(cache_key)
        # Move to end (most recently used)
        self.class.class_cache_order.delete(cache_key)
        self.class.class_cache_order.push(cache_key)
        self.class.class_memory_cache[cache_key]
      else
        nil
      end
    end

    return cached_result unless cached_result.nil?

    # Fall back to Rails.cache (slower but persistent across server restarts)
    rails_cache_key = "rebar:check:#{cache_key}"
    result = Rails.cache.fetch(rails_cache_key, expires_in: 5.minutes) do
      check_uncached(actor, actor_id, permission, subject, subject_id)
    end

    # Store in class-level memory cache (thread-safe)
    self.class.cache_mutex.synchronize do
      self.class.class_memory_cache[cache_key] = result
      self.class.class_cache_order.push(cache_key)

      # Evict oldest if cache is full (LRU)
      if self.class.class_memory_cache.size > MEMORY_CACHE_SIZE
        oldest_key = self.class.class_cache_order.shift
        self.class.class_memory_cache.delete(oldest_key)
      end
    end

    result
  end

  def check_uncached(actor, actor_id, permission, subject, subject_id)
    # First check if this is a computed permission
    if @dsl_schema && (type_def = @dsl_schema.get_type(subject))
      if type_def.has_permission?(permission)
        return check_computed_permission(actor, actor_id, permission, subject, subject_id)
      end
    end

    # Fall back to relation-based check
    !!explain(actor, actor_id, permission, subject, subject_id)
  end

  def explain(actor, actor_id, permission, subject, subject_id)
    target = [subject, subject_id, permission]
    queue  = [[target, 0, []]]
    visited = Set.new([state_key(target, actor, actor_id)])

    while (node = queue.shift)
      (current, depth, path) = node
      s_type, s_id, rel = current

      if direct_edge?(s_type, s_id, rel, actor, actor_id)
        return path + [{
          kind: :direct,
          relation: rel,
          subject: s_type,
          id: s_id,
          actor: actor,
          actor_id: actor_id
        }]
      end
      return nil if depth >= MAX_DEPTH

      # First, check for any group-based edges with actor_rel
      # This handles cases where tuples are written with actor_rel even if not in schema
      @repo.edges_for_object(subject: s_type, id: s_id, relation: rel).each do |edge|
        if edge["actor"] == "group" && edge["actor_rel"]
          members = @repo.expand_group_members(group_type: edge["actor"], group_id: edge["actor_id"])
          if members.any? { |m| m["subject"] == actor && m["id"] == actor_id }
            return path + [[:subject_role, rel, edge["actor_rel"], edge["actor"], edge["actor_id"]]]
          end
        end
      end

      # Then expand via schema-defined steps
      expand_steps(s_type, s_id, rel).each do |step|
        case step[:kind]
        when :union
          nxt = [s_type, s_id, step[:rel]]
          k = state_key(nxt, actor, actor_id)
          next if visited.include?(k)
          visited << k
          queue << [nxt, depth + 1, path + [[:union, rel, step[:rel]]]]

        when :parent
          @repo.parents_of(subject: s_type, id: s_id).each do |p|
            nxt = [p["subject"], p["id"], step[:rel]]
            k = state_key(nxt, actor, actor_id)
            next if visited.include?(k)
            visited << k
            queue << [nxt, depth + 1, path + [[:parent, s_type, s_id, p["subject"], p["id"], step[:rel]]]]
          end

        when :subject_role
          @repo.edges_for_object(subject: s_type, id: s_id, relation: step[:on_rel]).each do |edge|
            next unless edge["actor"] == step[:actor_type]
            # Only check actor_rel if it's specified in the edge
            # This allows both direct group ownership and group#member patterns
            next if edge["actor_rel"] && edge["actor_rel"] != step[:role]
            members = @repo.expand_group_members(group_type: edge["actor"], group_id: edge["actor_id"])
            if members.any? { |m| m["subject"] == actor && m["id"] == actor_id }
              return path + [[:subject_role, rel, step[:role], edge["actor"], edge["actor_id"]]]
            end
          end
        end
      end
    end
    nil
  end

  private

  def check_computed_permission(actor, actor_id, permission, subject, subject_id)
    type_def = @dsl_schema.get_type(subject)
    permission_def = type_def.get_permission(permission)

    context = AuthSchema::PermissionContext.new(
      actor: actor,
      actor_id: actor_id,
      subject: subject,
      subject_id: subject_id,
      repo: @repo,
      engine: self
    )

    # Evaluate the permission block
    begin
      result = permission_def.evaluate(context)
      !!result
    rescue => e
      Rails.logger.error("Permission evaluation error for #{permission} on #{subject}:#{subject_id}: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      false
    end
  end

  def direct_edge?(s_type, s_id, rel, actor, actor_id)
    @repo.edges_for_object(subject: s_type, id: s_id, relation: rel).any? do |row|
      row["actor"] == actor && row["actor_id"] == actor_id && row["actor_rel"].nil?
    end
  end

  def state_key(state, actor, actor_id)
    "#{state.join(':')}|#{actor}:#{actor_id}"
  end

  def expand_steps(s_type, _s_id, rel)
    spec = @schema.fetch(s_type).fetch("relations", {})[rel.to_s]
    return [] unless spec

    steps = spec.flat_map do |term|
      if term.include?("->")             # parent->editor
        left, right = term.split("->", 2)
        raise "only 'parent->X' supported" unless left == "parent"
        [{ kind: :parent, rel: right }]
      elsif term.include?("#")           # group#editor
        actor_type, role = term.split("#", 2)
        [{ kind: :subject_role, actor_type: actor_type, role: role, on_rel: rel }]
      else                                 # union on same object
        [{ kind: :union, rel: term }]
      end
    end

    # If "group" is in the allowed types, also check for group membership
    # This handles cases like owner: ["user", "group"] where a group owns something
    # and we need to check if the user is a member of that owning group
    if spec.include?("group") && !spec.any? { |t| t.start_with?("group#") }
      steps << { kind: :subject_role, actor_type: "group", role: "member", on_rel: rel }
    end

    steps
  end
end
