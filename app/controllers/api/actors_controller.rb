module Api
  class ActorsController < ::ApplicationController
    include ServiceAuth

    # GET /api/actors/:actor_type/:actor_id/permissions
    # Returns all permissions/actions this actor can perform
    def permissions
      tenant_id = request.headers["X-Tenant"] || "default"
      actor_type = params[:actor_type]
      actor_id = params[:actor_id]

      # Initialize permission engine
      schema_path = Rails.root.join("config/auth_schema.rb")
      load schema_path # Load the schema to ensure it's fresh
      repo = RebacRepo.new(tenant_id: tenant_id)
      engine = PermissionEngine.new(schema: AuthSchema, repo: repo)

      # Get direct permissions (where actor is directly granted access)
      direct_permissions = RelTuple.where(tenant_id: tenant_id, actor: actor_type, actor_id: actor_id)
                                   .select(:subject, :id, :relation, :actor_rel)
                                   .map do |tuple|
        {
          type: 'direct',
          resource: "#{tuple.subject}:#{tuple['id']}",
          resource_type: tuple.subject,
          resource_id: tuple['id'],
          permission: tuple.relation,
          via: nil
        }
      end

      # Get group memberships (where actor is a member of groups)
      group_memberships = RelTuple.where(tenant_id: tenant_id, actor: actor_type, actor_id: actor_id)
                                  .where(subject: 'group')
                                  .pluck(:id)
                                  .uniq

      # Get permissions through groups
      group_permissions = []
      group_memberships.each do |group_id|
        group_tuples = RelTuple.where(tenant_id: tenant_id, actor: 'group', actor_id: group_id)

        group_tuples.each do |tuple|
          # Only include if actor_rel matches the actor's relation to the group (usually 'member')
          actor_group_rel = RelTuple.find_by(
            tenant_id: tenant_id,
            subject: 'group',
            id: group_id,
            actor: actor_type,
            actor_id: actor_id
          )&.relation

          # If actor_rel is specified, only include if it matches
          if tuple.actor_rel.nil? || tuple.actor_rel == actor_group_rel
            group_permissions << {
              type: 'group',
              resource: "#{tuple.subject}:#{tuple['id']}",
              resource_type: tuple.subject,
              resource_id: tuple['id'],
              permission: tuple.relation,
              via: "group:#{group_id}##{actor_group_rel}"
            }
          end
        end
      end

      # Combine direct and group permissions
      all_permissions = (direct_permissions + group_permissions)

      # Compute inherited permissions (can be disabled for extreme scale)
      inherited_permissions = []
      if Rebar::Config.compute_inherited_permissions?
        inherited_permissions = compute_inherited_permissions(
          engine, tenant_id, actor_type, actor_id, all_permissions.map { |p| p[:resource] }
        )
      end

      # Combine all permission types
      all_permissions = all_permissions + inherited_permissions

      # Group by resource
      grouped = all_permissions.group_by { |p| p[:resource] }

      resources = grouped.map do |resource, perms|
        resource_type = perms.first[:resource_type]
        resource_id = perms.first[:resource_id]

        # Compute available actions for this resource
        actions = compute_actions(engine, actor_type, actor_id, resource_type, resource_id)

        {
          resource: resource,
          resource_type: resource_type,
          resource_id: resource_id,
          permissions: perms.map do |p|
            {
              permission: p[:permission],
              type: p[:type],
              via: p[:via]
            }
          end,
          actions: actions
        }
      end

      # Get counts
      direct_count = direct_permissions.size
      group_count = group_permissions.size
      inherited_count = inherited_permissions.size

      render json: {
        actor: "#{actor_type}:#{actor_id}",
        total_permissions: all_permissions.size,
        direct_count: direct_count,
        group_count: group_count,
        inherited_count: inherited_count,
        group_memberships: group_memberships.map { |gid| "group:#{gid}" },
        resources: resources.sort_by { |r| [r[:resource_type], r[:resource_id]] }
      }
    end

    # GET /api/actors/:actor_type/:actor_id/groups
    # Returns all groups this actor is a member of
    def groups
      tenant_id = request.headers["X-Tenant"] || "default"
      actor_type = params[:actor_type]
      actor_id = params[:actor_id]

      memberships = RelTuple.where(tenant_id: tenant_id, actor: actor_type, actor_id: actor_id)
                           .where(subject: 'group')
                           .select(:id, :relation)
                           .map do |tuple|
        {
          group: "group:#{tuple['id']}",
          group_id: tuple['id'],
          role: tuple.relation
        }
      end

      render json: {
        actor: "#{actor_type}:#{actor_id}",
        memberships: memberships
      }
    end

    private

    # Compute inherited permissions (through parent relationships, cascading permissions, etc.)
    # OPTIMIZED: Expands from actor outward instead of checking all entities
    def compute_inherited_permissions(engine, tenant_id, actor_type, actor_id, existing_resources)
      inherited = []

      # Strategy: Find entities related to actor through graph traversal
      # Instead of checking all entities, expand from actor's relationships

      # Step 1: Get resources actor directly owns/manages
      direct_resources = RelTuple.where(tenant_id: tenant_id, actor: actor_type, actor_id: actor_id)
                                 .select(:subject, :id, :relation)
                                 .limit(Rebar::Config.max_direct_resources)
                                 .to_a

      # Step 2: Find child entities through parent relationships
      # For each resource the actor has access to, find entities that reference it as parent
      child_entities = []

      direct_resources.each do |tuple|
        # Find entities that have this resource as their parent
        children = RelTuple.where(tenant_id: tenant_id, relation: 'parent',
                                  actor: tuple.subject, actor_id: tuple['id'])
                          .select(:subject, :id)
                          .limit(Rebar::Config.max_children_per_parent)
                          .to_a

        child_entities.concat(children)
      end

      # Step 3: Get group memberships and expand from groups
      group_memberships = RelTuple.where(tenant_id: tenant_id, actor: actor_type, actor_id: actor_id)
                                  .where(subject: 'group')
                                  .pluck(:id)
                                  .uniq

      group_resources = []
      group_memberships.each do |group_id|
        # Get resources the group has access to
        group_tuples = RelTuple.where(tenant_id: tenant_id, actor: 'group', actor_id: group_id)
                              .select(:subject, :id, :relation)
                              .limit(Rebar::Config.max_resources_per_group)
                              .to_a

        group_resources.concat(group_tuples)

        # Also get children of group resources
        group_tuples.each do |tuple|
          children = RelTuple.where(tenant_id: tenant_id, relation: 'parent',
                                   actor: tuple.subject, actor_id: tuple['id'])
                            .select(:subject, :id)
                            .limit(Rebar::Config.max_children_per_group_resource)
                            .to_a
          child_entities.concat(children)
        end
      end

      # Step 4: Check cascading permissions on discovered entities
      candidate_entities = (child_entities + group_resources).uniq { |e| "#{e.subject}:#{e['id']}" }

      candidate_entities.each do |entity|
        resource_type = entity.subject
        resource_id = entity['id']
        resource_key = "#{resource_type}:#{resource_id}"

        # Skip if already have this permission
        next if existing_resources.include?(resource_key)

        # Determine relations to check based on entity type
        # OPTIMIZED: Only check the most permissive relation to reduce BFS traversals
        relations_to_check = case resource_type
        when 'doc', 'document', 'folder', 'issue', 'pull_request'
          [:viewer]  # Most permissive relation
        when 'project'
          [:viewer]  # Most permissive relation
        when 'workspace'
          [:viewer]  # Most permissive relation
        else
          [:viewer]  # Default to most permissive
        end

        # Check each relation
        relations_to_check.each do |relation|
          begin
            if engine.check(actor_type, actor_id, relation, resource_type, resource_id)
              # Get explanation path
              path = engine.explain(actor_type, actor_id, relation, resource_type, resource_id)

              inherited << {
                type: 'inherited',
                resource: resource_key,
                resource_type: resource_type,
                resource_id: resource_id,
                permission: relation.to_s,
                via: path ? describe_path(path) : 'computed'
              }

              # Only add first matching relation
              break
            end
          rescue => e
            Rails.logger.error("Error checking inherited #{relation} for #{actor_type}:#{actor_id} on #{resource_type}:#{resource_id}: #{e.message}")
          end
        end
      end

      inherited
    end

    # Describe the permission path in a human-readable way
    def describe_path(path)
      return 'direct' if path.length == 1 && path[0].is_a?(Hash) && path[0][:kind] == :direct

      # For more complex paths, create a description
      steps = path.map do |step|
        if step.is_a?(Array)
          case step[0]
          when :union
            "via #{step[2]}"
          when :parent
            "via parent"
          when :subject_role
            "via #{step[3]}:#{step[4]}##{step[2]}"
          else
            step[0].to_s
          end
        elsif step.is_a?(Hash)
          step[:kind].to_s
        else
          step.to_s
        end
      end

      steps.join(' → ')
    end

    # Compute what actions an actor can perform on a resource
    def compute_actions(engine, actor_type, actor_id, resource_type, resource_id)
      # Define the actions to check based on resource type
      actions_to_check = case resource_type
      when 'doc'
        [:can_view, :can_edit, :can_delete, :can_archive]
      when 'folder'
        [:can_delete, :can_move, :can_share]
      when 'group'
        [] # Groups don't have computed permissions in our schema
      else
        []
      end

      # Check each action and return the ones that are allowed
      allowed_actions = actions_to_check.select do |action|
        begin
          engine.check(actor_type, actor_id, action, resource_type, resource_id)
        rescue => e
          Rails.logger.error("Error checking #{action} for #{actor_type}:#{actor_id} on #{resource_type}:#{resource_id}: #{e.message}")
          false
        end
      end

      allowed_actions.map(&:to_s)
    end
  end
end
