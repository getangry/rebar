require "yaml"
require "set"

class PermissionEngine
  MAX_DEPTH = 6

  def initialize(schema_path: Rails.root.join("config/auth_schema.yml"), repo: RebacRepo.new)
    @schema = YAML.load_file(schema_path)["types"]
    @repo   = repo
  end

  def check(actor, actor_id, permission, subject, subject_id)
    !!explain(actor, actor_id, permission, subject, subject_id)
  end

  def explain(actor, actor_id, permission, subject, subject_id)
    target = [subject, subject_id, permission]
    queue  = [[target, 0, []]]
    visited = Set.new([state_key(target, actor, actor_id)])

    while (node = queue.shift)
      (current, depth, path) = node
      s_type, s_id, rel = current

      return path if direct_edge?(s_type, s_id, rel, actor, actor_id)
      return nil   if depth >= MAX_DEPTH

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

  def direct_edge?(s_type, s_id, rel, actor, actor_id)
    @repo.edges_for_object(subject: s_type, id: s_id, relation: rel).any? do |row|
      row["actor"] == actor && row["actor_id"] == actor_id && row["actor_rel"].nil?
    end
  end

  def state_key(state, actor, actor_id)
    "#{state.join(':')}|#{actor}:#{actor_id}"
  end

  def expand_steps(s_type, _s_id, rel)
    spec = @schema.fetch(s_type).fetch("relations", {})[rel]
    return [] unless spec

    spec.flat_map do |term|
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
  end
end
