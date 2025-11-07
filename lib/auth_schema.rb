# Authorization Schema DSL
# Provides a Ruby DSL for defining authorization schemas with both
# relationship-based and attribute-based access control

class AuthSchema
  class << self
    attr_reader :types

    def define(&block)
      @types = {}
      instance_eval(&block)
      self
    end

    def type(name, &block)
      @types[name.to_s] = TypeDefinition.new(name.to_s)
      @types[name.to_s].instance_eval(&block) if block_given?
    end

    def get_type(name)
      @types[name.to_s]
    end

    def to_legacy_yaml
      # Convert to old YAML format for backward compatibility
      {
        "types" => (@types || {}).transform_values do |type_def|
          {
            "relations" => type_def.relations.transform_values { |rel| rel.allowed_types }
          }.compact
        end
      }
    end
  end

  class TypeDefinition
    attr_reader :name, :relations, :permissions

    def initialize(name)
      @name = name
      @relations = {}
      @permissions = {}
    end

    # Define a relation
    # relation :owner, allow: [:user, :group]
    # relation :editor, allow: [:owner, "group#member"]
    def relation(name, allow: [])
      @relations[name.to_s] = RelationDefinition.new(name.to_s, allow)
    end

    # Define a computed permission with custom logic
    # permission :can_delete do |context|
    #   # Custom logic here
    # end
    def permission(name, &block)
      @permissions[name.to_s] = PermissionDefinition.new(name.to_s, block)
    end

    def get_relation(name)
      @relations[name.to_s]
    end

    def get_permission(name)
      @permissions[name.to_s]
    end

    def has_permission?(name)
      @permissions.key?(name.to_s)
    end
  end

  class RelationDefinition
    attr_reader :name, :allowed_types

    def initialize(name, allowed_types)
      @name = name
      @allowed_types = Array(allowed_types).map(&:to_s)
    end
  end

  class PermissionDefinition
    attr_reader :name, :evaluator

    def initialize(name, evaluator)
      @name = name
      @evaluator = evaluator
    end

    def evaluate(context)
      # Call the block with context as parameter instead of instance_eval
      # This allows 'return' statements to work correctly
      @evaluator.call(context)
    end
  end

  # Context object passed to permission blocks
  class PermissionContext
    attr_reader :actor, :actor_id, :subject, :subject_id, :repo, :engine

    def initialize(actor:, actor_id:, subject:, subject_id:, repo:, engine:)
      @actor = actor
      @actor_id = actor_id
      @subject = subject
      @subject_id = subject_id
      @repo = repo
      @engine = engine
    end

    # Allow permission blocks to call check()
    def check(actor, actor_id, permission, subject, subject_id)
      @engine.check(actor, actor_id, permission, subject, subject_id)
    end

    # Helper to get parents
    def parents
      @repo.parents_of(subject: @subject, id: @subject_id)
    end

    # Helper to check if actor has relation to subject
    def has_relation?(relation)
      @engine.check(@actor, @actor_id, relation, @subject, @subject_id)
    end
  end
end
