module Api
  class SchemaController < ::ApplicationController
    include ServiceAuth

    # GET /api/schema?schema_name=default
    # Returns the authorization schema with statistics
    def index
      tenant_id = request.headers["X-Tenant"] || "default"
      schema_name = params[:schema_name] || 'default'

      # Load all schemas
      schema_index = Rails.root.join("schemas/index.rb")
      load schema_index

      # Get the requested schema
      schema = AuthSchema.get_schema(schema_name)
      unless schema
        return render json: { error: "Schema '#{schema_name}' not found" }, status: :not_found
      end

      schema_hash = schema.to_legacy_yaml

      # Get statistics for each type
      stats = {}
      schema_hash["types"].each do |type_name, type_def|
        # Count tuples where this type is the subject
        as_subject = RelTuple.where(tenant_id: tenant_id, subject: type_name).count

        # Count tuples where this type is the actor
        as_actor = RelTuple.where(tenant_id: tenant_id, actor: type_name).count

        stats[type_name] = {
          as_subject: as_subject,
          as_actor: as_actor,
          total: as_subject + as_actor,
          relations: type_def["relations"]&.keys || []
        }
      end

      # Include available schemas and current schema info
      available_schemas = AuthSchema.list_schemas.map do |name|
        info = AuthSchema.schema_info(name)
        {
          name: info[:name],
          purpose: info[:purpose],
          type_count: info[:type_count]
        }
      end

      render json: {
        current_schema: {
          name: schema_name,
          purpose: schema.purpose
        },
        available_schemas: available_schemas,
        types: schema_hash["types"],
        stats: stats
      }
    end

    # GET /api/schema/graph
    # Returns a graph structure suitable for visualization
    def graph
      tenant_id = request.headers["X-Tenant"] || "default"
      
      # Get all tuples for this tenant
      tuples = RelTuple.where(tenant_id: tenant_id).limit(1000).to_a
      
      # Build nodes and edges
      nodes = {}
      edges = []
      
      tuples.each do |tuple|
        # Add subject node
        subject_key = "#{tuple.subject}:#{tuple.subject_id}"
        nodes[subject_key] ||= {
          id: subject_key,
          type: tuple.subject,
          object_id: tuple.subject_id,
          label: "#{tuple.subject}:#{tuple.subject_id}",
          relations: []
        }

        # Add actor node
        actor_key = "#{tuple.actor}:#{tuple.actor_id}"
        nodes[actor_key] ||= {
          id: actor_key,
          type: tuple.actor,
          object_id: tuple.actor_id,
          label: "#{tuple.actor}:#{tuple.actor_id}",
          relations: []
        }

        # Add edge
        edge = {
          source: actor_key,
          target: subject_key,
          relation: tuple.relation,
          actor_rel: tuple.actor_rel
        }
        edges << edge

        # Track relations for the node
        nodes[subject_key][:relations] << tuple.relation unless nodes[subject_key][:relations].include?(tuple.relation)
      end
      
      render json: {
        nodes: nodes.values,
        edges: edges,
        node_count: nodes.size,
        edge_count: edges.size
      }
    end

    # GET /api/schema/entities
    # Returns list of all entities for selection
    def entities
      tenant_id = request.headers["X-Tenant"] || "default"

      tuples = RelTuple.where(tenant_id: tenant_id).limit(1000).to_a
      entities = {}

      tuples.each do |tuple|
        # Collect unique entities
        subject_key = "#{tuple.subject}:#{tuple.subject_id}"
        actor_key = "#{tuple.actor}:#{tuple.actor_id}"

        entities[subject_key] = {
          id: subject_key,
          type: tuple.subject,
          object_id: tuple.subject_id
        }

        entities[actor_key] = {
          id: actor_key,
          type: tuple.actor,
          object_id: tuple.actor_id
        }
      end

      # Group by type
      grouped = entities.values.group_by { |e| e[:type] }

      render json: { entities: grouped }
    end

    # GET /api/schema/relationships/:entity_id
    # Returns relationships for a specific entity
    def relationships
      tenant_id = request.headers["X-Tenant"] || "default"
      entity_param = params[:entity_id] # Format: "type:id"

      # Parse entity_id
      parts = entity_param.split(":", 2)
      entity_type = parts[0]
      entity_id = parts[1].to_s # Ensure ID is a string

      # Build graph from connected entities (BFS approach)
      visited = Set.new
      nodes = {}
      edges = []
      queue = [[entity_type, entity_id, 0]] # [type, id, depth]
      max_depth = 2 # Limit depth to prevent huge graphs

      while !queue.empty?
        current_type, current_id, depth = queue.shift
        current_key = "#{current_type}:#{current_id}"

        next if visited.include?(current_key)
        visited.add(current_key)

        # Add current node
        nodes[current_key] = {
          id: current_key,
          type: current_type,
          object_id: current_id,
          label: current_key,
          depth: depth
        }

        # Find tuples involving this entity
        related_tuples = RelTuple.where(tenant_id: tenant_id)
                                 .where("(subject = ? AND subject_id = ?) OR (actor = ? AND actor_id = ?)",
                                        current_type, current_id.to_s, current_type, current_id.to_s)
                                 .limit(50)
                                 .to_a

        related_tuples.each do |tuple|
          subject_key = "#{tuple.subject}:#{tuple.subject_id}"
          actor_key = "#{tuple.actor}:#{tuple.actor_id}"

          # Add subject node if not visited
          unless visited.include?(subject_key)
            nodes[subject_key] ||= {
              id: subject_key,
              type: tuple.subject,
              object_id: tuple.subject_id,
              label: subject_key,
              depth: depth + 1
            }
            queue << [tuple.subject, tuple.subject_id.to_s, depth + 1] if depth < max_depth
          end

          # Add actor node if not visited
          unless visited.include?(actor_key)
            nodes[actor_key] ||= {
              id: actor_key,
              type: tuple.actor,
              object_id: tuple.actor_id,
              label: actor_key,
              depth: depth + 1
            }
            queue << [tuple.actor, tuple.actor_id.to_s, depth + 1] if depth < max_depth
          end

          # Add edge
          edge = {
            source: actor_key,
            target: subject_key,
            relation: tuple.relation,
            actor_rel: tuple.actor_rel,
            label: tuple.actor_rel ? "#{tuple.relation}##{tuple.actor_rel}" : tuple.relation
          }
          edges << edge
        end
      end

      render json: {
        nodes: nodes.values,
        edges: edges,
        center_entity: "#{entity_type}:#{entity_id}",
        node_count: nodes.size,
        edge_count: edges.size
      }
    end
  end
end
